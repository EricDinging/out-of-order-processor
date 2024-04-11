`include "sys_defs.svh"

/*
typedef struct packed {
    logic valid;
    MEM_FUNC byte_info;
} ID_SQ_PACKET;

typedef struct packed {
    logic valid;
    DATA  base;
    logic [11:0] imm;
    DATA  data;
    logic [`SQ_IDX_BITS-1:0] sq_idx;
} RS_SQ_PACKET;

typedef struct packed {
    logic    valid;
    ADDR     addr;
    MEM_FUNC sign_size;
    DATA     data;
} SQ_DCACHE_PACKET;

typedef struct packed {
    logic    valid;
    MEM_SIZE byte_info;
    ADDR     addr;
    DATA     data;
    logic    ready;
} SQ_ENTRY;
*/

module store_queue (
    input logic clock, reset,
    // ID
    input ID_SQ_PACKET [`N-1:0] id_sq_packet,
    output logic almost_full,   // also to rs
    // RS
    input  RS_SQ_PACKET [`NUM_FU_STORE-1:0] rs_sq_packet,
    // ROB
    input  SQ_IDX num_commit_insns,
    output SQ_IDX num_sent_insns,
    // dcache
    output SQ_DCACHE_PACKET [`NUM_SQ_DCACHE-1:0] sq_dcache_packet,
    input  logic            [`NUM_SQ_DCACHE-1:0] dcache_accept,
    // RS for load
    output SQ_IDX head,
    output SQ_IDX tail,

    // --- combinational below
    output SQ_IDX tail_ready,
    // LQ
    input  ADDR     [`NUM_FU_LOAD-1:0] addr,           // TODO connect
    input  SQ_IDX   [`NUM_FU_LOAD-1:0] tail_store,     // TODO connect
    input  MEM_FUNC [`NUM_FU_LOAD-1:0] load_byte_info, // TODO connect
    output DATA     [`NUM_FU_LOAD-1:0] value,          // TODO connect
    output logic    [`NUM_FU_LOAD-1:0] fwd_valid       // TODO connect
`ifdef CPU_DEBUG_OUT
    , output SQ_ENTRY[(`SQ_LEN+1)-1:0] entries_out
`endif
);

    function DATA re_align;
        input  DATA     data;
        input  ADDR     addr;
        input  MEM_FUNC func;
        begin
            re_align = 0;
            case (func[1:0])
                BYTE: begin
                    case (addr[1:0])
                        3: re_align[31:24] = data[7:0];
                        2: re_align[23:16] = data[7:0];
                        1: re_align[15:8] = data[7:0];
                        0: re_align[7:0] = data[7:0];
                    endcase
                end

                HALF: begin
                    case (addr[0])
                        1: re_align[31:16] = data[15:0];
                        2: re_align[15:0] = data[15:0];
                    endcase
                end
                default: begin
                    re_align = data;
                end
            endcase
        end
    endfunction

    SQ_ENTRY[(`SQ_LEN+1)-1:0] entries, next_entries;

`ifdef CPU_DEBUG_OUT
    assign entries_out = entries;
`endif

    SQ_IDX size, next_size, next_head, next_tail;
    SQ_REG[`NUM_FU_STORE-1:0] sq_reg, next_sq_reg;

    assign almost_full = size > `SQ_LEN - `N;

    always_comb begin
        next_sq_reg = sq_reg;
        foreach (next_sq_reg[i]) begin
            next_sq_reg[i].valid  = rs_sq_packet[i].valid;
            next_sq_reg[i].addr   = rs_sq_packet[i].base + {20'h0, rs_sq_packet[i].offset};
            next_sq_reg[i].data   = rs_sq_packet[i].data;
            next_sq_reg[i].sq_idx = rs_sq_packet[i].sq_idx;
        end
    end

    // entry
    SQ_IDX idx;
    logic break_flag;
    always_comb begin
        next_entries = entries;

        next_head = head;
        next_tail = tail;
        next_size = size;

        // ID
        if (!almost_full) begin
            for (int i = 0; i < `N; i++) begin
                if (id_sq_packet[i].valid) begin
                    next_entries[next_tail] = '{
                        `TRUE,
                        id_sq_packet[i].byte_info,
                        32'b0, 32'b0, `FALSE, `FALSE
                    };
                    next_tail = (next_tail + 1) % (`SQ_LEN + 1);
                    next_size += 1;
                end
            end
        end

        // RS
        foreach (sq_reg[i]) if (sq_reg[i].valid) begin
            next_entries[sq_reg[i].sq_idx].ready = `TRUE;
            next_entries[sq_reg[i].sq_idx].addr  = sq_reg[i].addr;
            next_entries[sq_reg[i].sq_idx].data  = sq_reg[i].data;
        end
        
        // ROB
        sq_dcache_packet = 0;
        idx = 0;
        
        for (int i = 0; i < `NUM_SQ_DCACHE; i++) begin
            if (num_commit_insns > num_sent_insns) begin
                idx = (head + i) % (`SQ_LEN + 1);
                if (entries[idx].valid && entries[idx].ready && !entries[idx].accepted) begin
                    sq_dcache_packet[i] = '{
                        `TRUE,
                        entries[idx].addr,
                        entries[idx].byte_info,
                        entries[idx].data
                    };
                end
            end
        end

        
        num_sent_insns = 0;
        break_flag = `FALSE;
        for (int i = 0; i < `NUM_SQ_DCACHE; i++) begin
            idx = (head + i) % (`SQ_LEN + 1);
            if (dcache_accept[i] || (entries[idx].valid && entries[idx].accepted)) begin
                next_entries[idx].accepted = `True;
                if (!break_flag) begin
                    num_sent_insns += 1;
                    next_entries[idx] = 0;
                    next_head = (head + 1) % (`SQ_LEN + 1);
                end
            end else begin
                break_flag = `TRUE;
            end
        end
    end

    // tail_ready
    SQ_IDX idx_tail;
    logic flag_ready;
    always_comb begin
        tail_ready = head;
        flag_ready = `TRUE;
        for (int i = 0; i < `SQ_LEN; i++) begin
            idx_tail = (head + i) % (`SQ_LEN + 1);
            if (flag_ready && entries[idx_tail].valid) begin
                flag_ready &= entries[idx_tail].ready;
                if (entries[idx_tail].ready) begin
                    tail_ready = (tail_ready + 1) % (`SQ_LEN + 1);
                end
            end
        end
    end

    // LQ fwd
    SQ_IDX idx_fwd;
    logic flag_break;
    logic match, match_byte, match_half, match_word, match_dble, compatible;
    always_comb begin
        flag_break = `FALSE;
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            value[i] = 32'h0;
            fwd_valid[i] = `FALSE;
            for (int j = 0; j < `SQ_LEN; j++) begin
                idx_fwd = (head + j) % (`SQ_LEN + 1);

                match_byte = entries[idx_fwd].addr[31:0] == addr[i][31:0];
                match_half = entries[idx_fwd].addr[31:1] == addr[i][31:1];
                match_word = entries[idx_fwd].addr[31:2] == addr[i][31:2];
                match_dble = entries[idx_fwd].addr[31:3] == addr[i][31:3];
                // compatible = entries[idx_fwd].byte_info >= load_byte_info[i];

                case (entries[idx_fwd].byte_info)
                    MEM_BYTE:  match = match_byte && load_byte_info[i][1:0] == BYTE;
                    MEM_BYTEU: match = match_byte && load_byte_info[i][1:0] == BYTE;
                    MEM_HALF:  match = match_half && load_byte_info[i][1:0] != WORD;
                    MEM_HALFU: match = match_half && load_byte_info[i][1:0] != WORD;
                    MEM_WORD:  match = match_word;
                endcase

                flag_break |= idx_fwd == tail_store[i];
                if (~flag_break && match) begin
                    value[i] = re_align(entries[idx_fwd].data, entries[idx_fwd].addr, entries[idx_fwd].byte_info);
                    fwd_valid[i] = entries[idx_fwd].valid && entries[idx_fwd].ready;
                end
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            entries <= 0;

            size <= 0;
            head <= 0;
            tail <= 0;

            sq_reg <= 0;
        end else begin
            entries <= next_entries;

            size <= next_size;
            head <= next_head;
            tail <= next_tail;

            sq_reg <= next_sq_reg;
        end
    end

endmodule
