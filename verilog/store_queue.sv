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
    output logic    [`NUM_FU_LOAD-1:0] fwd_valid,       // TODO connect
    output logic    [`NUM_FU_LOAD-1:0][3:0] forwarded
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

    SQ_ENTRY [(`SQ_LEN+1)-1:0] entries, next_entries;

`ifdef CPU_DEBUG_OUT
    assign entries_out = entries;
`endif

    SQ_IDX size, next_size, next_head, next_tail;
    SQ_REG [`NUM_FU_STORE-1:0] sq_reg, next_sq_reg;

    DATA [`SQ_LEN-1:0] realigned_data;

    assign almost_full = size > `SQ_LEN - `N;

    SQ_IDX try_to_sent_insns;

    always_comb begin
        next_sq_reg = sq_reg;
        foreach (next_sq_reg[i]) begin
            next_sq_reg[i].valid  = rs_sq_packet[i].valid;
            next_sq_reg[i].addr   = rs_sq_packet[i].base + 32'(signed'(rs_sq_packet[i].offset));
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
        foreach (sq_reg[i]) begin 
            if (sq_reg[i].valid) begin
                next_entries[sq_reg[i].sq_idx].ready = `TRUE;
                next_entries[sq_reg[i].sq_idx].addr  = sq_reg[i].addr;
                next_entries[sq_reg[i].sq_idx].data  = sq_reg[i].data;
            end
        end
        
        // ROB
        sq_dcache_packet = 0;
        idx = 0;

        try_to_sent_insns = 0;
        for (int i = 0; i < `NUM_SQ_DCACHE; i++) begin
            if (num_commit_insns > try_to_sent_insns) begin
                idx = (head + i) % (`SQ_LEN + 1);
                if (entries[idx].valid && entries[idx].ready && !entries[idx].accepted) begin
                    sq_dcache_packet[i] = '{
                        `TRUE,
                        entries[idx].addr,
                        entries[idx].byte_info,
                        entries[idx].data
                    };
                    try_to_sent_insns += 1;
                end else if (entries[idx].valid && ~entries[idx].ready) begin
                    break;
                end
            end
        end

        num_sent_insns = 0;
        break_flag = `FALSE;
        for (int i = 0; i < `NUM_SQ_DCACHE; i++) begin
            idx = (head + i) % (`SQ_LEN + 1);
            if (dcache_accept[i] || (entries[idx].valid && entries[idx].accepted)) begin
                next_entries[idx].accepted = `TRUE;
                if (!break_flag) begin
                    num_sent_insns += 1;
                    next_entries[idx] = 0;
                    next_head = (next_head + 1) % (`SQ_LEN + 1);
                    next_size -= 1;
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
    logic match, match_byte, match_half, match_word;
    always_comb begin
        value = 0;
        fwd_valid = 0;
        idx_fwd = 0;
        forwarded = 0;
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            flag_break = `FALSE;
            for (int j = 0; j < `SQ_LEN; j++) begin
                idx_fwd = (head + j) % (`SQ_LEN + 1);
                realigned_data[j] = re_align(entries[idx_fwd].data, entries[idx_fwd].addr, entries[idx_fwd].byte_info);

                match_byte = entries[idx_fwd].addr[31:0] == addr[i][31:0];
                match_half = entries[idx_fwd].addr[31:1] == addr[i][31:1];
                match_word = entries[idx_fwd].addr[31:2] == addr[i][31:2];

                case (entries[idx_fwd].byte_info)
                    MEM_BYTE:  match = match_byte && load_byte_info[i][1:0] == BYTE;
                    MEM_BYTEU: match = match_byte && load_byte_info[i][1:0] == BYTE;
                    MEM_HALF:  match = match_half && load_byte_info[i][1:0] != WORD;
                    MEM_HALFU: match = match_half && load_byte_info[i][1:0] != WORD;
                    default:  match = match_word; // MEM_WORD
                endcase

                flag_break |= idx_fwd == tail_store[i];
                if (!flag_break && match_word && entries[idx_fwd].valid && entries[idx_fwd].ready) begin
                    case (entries[idx_fwd].byte_info[1:0])
                        BYTE: begin
                            if (entries[idx_fwd].addr[1:0] == 3) begin
                                forwarded[i][3] = `TRUE;
                                value[i][31:24] = realigned_data[j][31:24];
                            end else if (entries[idx_fwd].addr[1:0] == 2) begin
                                forwarded[i][2] = `TRUE;
                                value[i][23:16] = realigned_data[j][23:16];

                            end else if (entries[idx_fwd].addr[1:0] == 1) begin
                                forwarded[i][1] = `TRUE;
                                value[i][15:8] = realigned_data[j][15:8];
                            end else begin
                                forwarded[i][0] = `TRUE;
                                value[i][7:0] = realigned_data[j][7:0];
                            end
                        end
                        HALF: begin
                            if (entries[idx_fwd].addr[1]) begin
                                forwarded[i][3:2] = 2'b11;
                                value[i][31:16] = realigned_data[j][31:16];
                            end else begin
                                forwarded[i][1:0] = 2'b11;
                                value[i][15:0] = realigned_data[j][15:0];
                            end
                        end
                        default: begin // WORD
                            forwarded[i] = 4'b1111;
                            value[i] = realigned_data[j];
                        end
                    endcase
                end
                // if (!flag_break && match) begin
                //     // value[i] = re_align(entries[idx_fwd].data, entries[idx_fwd].addr, entries[idx_fwd].byte_info);
                //     fwd_valid[i] = entries[idx_fwd].valid && entries[idx_fwd].ready;
                // end
            end
            case (load_byte_info[i][1:0])
                BYTE: begin
                    case (entries[idx_fwd].addr[1:0])
                        3: fwd_valid[i] = forwarded[i][3];
                        2: fwd_valid[i] = forwarded[i][2];
                        1: fwd_valid[i] = forwarded[i][1];
                        0: fwd_valid[i] = forwarded[i][0];
                    endcase
                end
                HALF: begin
                    case (entries[idx_fwd].addr[1])
                        1: fwd_valid[i] = forwarded[i][3] && forwarded[i][2];
                        0: fwd_valid[i] = forwarded[i][1] && forwarded[i][0];
                    endcase
                end
                default: begin // WORD
                    fwd_valid[i] = &forwarded[i];
                end
            endcase
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
