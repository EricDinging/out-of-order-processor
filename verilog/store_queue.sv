`include "sys_defs.svh"

/*
typedef struct packed {
    logic valid;
    MEM_SIZE byte_info;
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
    MEM_SIZE size;
    DATA     data;
} SQ_DCACHE_PACKET;

typedef struct packed {
    logic    valid;
    MEM_SIZE byte_info;
    ADDR     target;
    DATA     value;
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
    input  logic [`SQ_IDX_BITS-1:0] num_commit_insns,
    output logic [`SQ_IDX_BITS-1:0] num_sent_insns,
    // dcache
    output SQ_DCACHE_PACKET [`NUM_SQ_DCACHE-1:0] sq_dcache_packet,
    input  logic            [`NUM_SQ_DCACHE-1:0] dcache_accept,
    // RS for load
    output logic [`SQ_IDX_BITS-1:0] head,
    output logic [`SQ_IDX_BITS-1:0] tail,

    // --- combinational below
    output logic [`SQ_IDX_BITS-1:0] tail_ready,
    // LQ
    input  ADDR  [`NUM_FU_LOAD-1:0] addr,
    input  logic [`NUM_FU_LOAD-1:0][`SQ_IDX_BITS-1:0] store_range,
    output DATA  [`NUM_FU_LOAD-1:0] value,
    output logic [`NUM_FU_LOAD-1:0] fwd_valid
`ifdef CPU_DEBUG_OUT
`endif
);

    // typedef struct packed {
    //     logic    valid;
    //     MEM_SIZE byte_info;
    //     ADDR     addr;
    //     DATA     data;
    //     logic    ready;
    // } SQ_ENTRY;

    SQ_ENTRY[(`SQ_LEN+1)-1:0] entries, next_entries;

    logic[`SQ_IDX_BITS-1:0] size, next_size, next_head, next_tail, next_tail_ready;
    SQ_REG[`NUM_FU_STORE-1:0] sq_reg, next_sq_reg;

    assign almost_full = size > SQ_LEN - `NUM_FU_LOAD;

    always_comb begin
        foreach (next_sq_reg[i]) begin
            next_sq_reg[i].valid  = rs_sq_packet[i].valid;
            next_sq_reg[i].addr   = rs_sq_packet[i].addr + {20'h0, rs_sq_packet[i].offset};
            next_sq_reg[i].data   = rs_sq_packet[i].data;
            next_sq_reg[i].sq_idx = rs_sq_packet[i].sq_idx;
        end
    end

    always_comb begin
        next_entries = entries;

        next_head = head;
        next_tail = tail;
        next_size = size;
        // next_tail_ready = tail_ready;

        // ID
        if (!almost_full) begin
            for (int i = 0; i < `N; i++) begin
                if (id_sq_packet[i].valid) begin
                    entries[tail] = '{
                        `TRUE,
                        id_sq_packet[i].byte_info,
                        0,
                        0,
                        `FALSE
                    };
                    next_tail = (next_tail + 1) % (`SQ_LEN + 1);
                    next_size += 1;
                end
            end
        end

        // RS
        foreach (sq_reg[i]) if (sq_reg[i].valid) begin
            next_entries[sq_reg[i].sq_idx].addr = sq_reg[i].addr;
            next_entries[sq_reg[i].sq_idx].data = sq_reg[i].data;
        end
        
        // ROB
        sq_dcache_packet = 0;
        num_sent_insns = 0;
        for (int i = 0; i < `NUM_SQ_DCACHE; i++) begin
            if (num_commit_insns - num_sent_insns > 0) begin
                if (entries[head+i].valid && entries[head+i].ready) begin
                    sq_dcache_packet = '{
                        `TRUE,
                        entries[head+i].addr,
                        entries[head+i].byte_info,
                        entries[head+i].data
                    };
                    if (dcache_accept[i]) begin
                        num_sent_insns += 1;
                        entries[head+i] = 0;
                    end
                end
            end
        end
        next_head = (head + num_sent_insns) % (`SQ_LEN + 1);

    end

    always_ff @(posedge clock) begin
        if (reset) begin
            // foreach (entries[i]) begin
            //     entries[i] <= '{`FALSE, BYTE, 32'h0, 32'h0, `FALSE};
            // end
            entries <= $bits(entries)'h0;

            size <= next_size;
            head <= next_head;
            tail <= next_tail;
            // tail_ready <= next_tail_ready;

            sq_reg <= $bits(sq_reg)'h0;
        end else begin
            entries <= next_entries;

            size <= `SQ_IDX_BITS'h0;
            head <= `SQ_IDX_BITS'h0;
            tail <= `SQ_IDX_BITS'h0;
            // tail_ready <= `SQ_IDX_BITS'h0;

            sq_reg <= next_sq_reg;
        end
    end

endmodule
