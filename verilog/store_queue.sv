`include "sys_defs.svh"

module store_queue (
    input logic clock, reset,
    // ID
    input ID_SQ_PACKET [`N-1:0] id_sq_packet,
    output logic almost_full,
    // RS
    input  RS_SQ_PACKET [`NUM_FU_STORE-1:0] rs_sq_packet,
    output logic        [`NUM_FU_STORE-1:0] store_avail,
    // ROB
    input  logic [`SQ_IDX_BITS-1:0] num_commit_insns, 
    output logic [`SQ_IDX_BITS-1:0] num_stored_insns, 
    // dcache
    input  logic            [`NUM_SQ_DCACHE-1:0] dcache_accept,
    output SQ_DCACHE_PACKET [`NUM_SQ_DCACHE-1:0] sq_dcache_packet,
    // RS for load
    output logic [`SQ_IDX_BITS-1:0] head,
    output logic [`SQ_IDX_BITS-1:0] tail,
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
    //     ADDR     target;
    //     DATA     value;
    //     logic    ready;
    // } SQ_ENTRY;

    SQ_ENTRY[`SQ_LEN-1:0] entries, next_entries;

    logic[`SQ_IDX_BITS-1:0] next_head, next_tail, next_tail_ready;

    always_comb begin
        next_entries = entries;

        next_head       = head;
        next_tail       = tail;
        next_tail_ready = tail_ready;

        
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            foreach (entries[i]) begin
                entries[i] <= '{`FALSE, BYTE, 32'h0, 32'h0, `FALSE};
            end

            head       <= next_head;
            tail       <= next_tail;
            tail_ready <= next_tail_ready;
        end else begin
            entries <= next_entries;

            head       <= `SQ_IDX_BITS'h0;
            tail       <= `SQ_IDX_BITS'h0;
            tail_ready <= `SQ_IDX_BITS'h0;
        end
    end

endmodule
