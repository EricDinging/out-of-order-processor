`include "sys_defs.svh"

module testbench;

    logic clock;
    logic reset;
    ADDR pc_start;
    ROB_IF_PACKET rob_if_packet;
    // output
    PC_ENTRY [`N-1:0] target_pc;

    tournament_predictor bp (
        .clock(clock),
        .reset(reset),
        .pc_start(pc_start),
        .rob_if_packet(rob_if_packet),
        .target_pc(target_pc)
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task init;
        clock = 0;
        reset = 1;
        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);
    endtask

    initial begin
        clock = 0;
        init();
        $display("@@@ Passed");
        $finish;
    end

endmodule
 