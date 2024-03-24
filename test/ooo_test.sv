`include "sys_defs.svh"

module testbench;
    logic clock, reset, correct;

    ID_OOO_PACKET id_ooo_packet;
    logic         structural_hazard;
    logic         squash;
    ROB_IF_PACKET rob_if_packet;
    OOO_CT_PACKET ooo_ct_packet;

    ooo dut(
        .clock(clock),
        .reset(reset),
        .id_ooo_packet(id_ooo_packet),
        .structural_hazard(structural_hazard),
        .squash(squash),
        .rob_if_packet(rob_if_packet),
        .ooo_ct_packet(ooo_ct_packet)
    );
    
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task init;
        reset = 1;
        correct = 1;
        id_ooo_packet = 0;
        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        @(negedge clock);
        
    endtask

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f, clock %b\n", $time, clock);
            $display("@@@ Failed PRF test!");
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (!correct) begin
            exit_on_error();
        end
    end

    initial begin
        $display("PRF size %d\n", `PHYS_REG_SZ_R10K);
        clock = 0;
        init; 

        $finish;
    end
endmodule