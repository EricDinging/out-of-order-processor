`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module testbench;
    logic clock, reset, correct;


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