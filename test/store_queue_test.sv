`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module testbench;
    logic clock, reset, correct;

    // ID
    ID_SQ_PACKET [`N-1:0] id_sq_packet;
    logic almost_full;   // also to rs
    // RS
    RS_SQ_PACKET [`NUM_FU_STORE-1:0] rs_sq_packet;
    // ROB
    logic [`SQ_IDX_BITS-1:0] num_commit_insns;
    logic [`SQ_IDX_BITS-1:0] num_sent_insns;
    // dcache
    SQ_DCACHE_PACKET [`NUM_SQ_DCACHE-1:0] sq_dcache_packet;
    logic            [`NUM_SQ_DCACHE-1:0] dcache_accept;
    // RS for load
    logic [`SQ_IDX_BITS-1:0] head;
    logic [`SQ_IDX_BITS-1:0] tail;

    // --- combinational below
    logic [`SQ_IDX_BITS-1:0] tail_ready;
    // LQ
    ADDR     [`NUM_FU_LOAD-1:0] addr;
    SQ_IDX   [`NUM_FU_LOAD-1:0] tail_store;
    MEM_FUNC [`NUM_FU_LOAD-1:0] load_byte_info;
    DATA     [`NUM_FU_LOAD-1:0] value;
    logic    [`NUM_FU_LOAD-1:0] fwd_valid;


    store_queue dut(
        .clock(clock),
        .reset(reset),
        .id_sq_packet(),
        .almost_full(),
        .rs_sq_packet(),
        .num_commit_insns(),
        .num_sent_insns(),
        .sq_dcache_packet(),
        .dcache_accept(),
        .head(),
        .tail(),
        .tail_ready(),
        .addr(),
        .tail_store(),
        .load_byte_info(),
        .value(),
        .fwd_valid()
    );
    
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task init;
        reset = 1;
        correct = 1;
        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        @(negedge clock);
        
    endtask

    task exit_on_error;
        begin
            // $display("@@@ Incorrect at time %4.0f, clock %b\n", $time, clock);
            // $display("@@@ Failed PRF test!");
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (!correct) begin
            exit_on_error();
        end
    end

    initial begin
        $display("store queue compiled\n");
        clock = 0;
        init; 

        $finish;
    end
endmodule