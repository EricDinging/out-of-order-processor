`include "sys_defs.svh"
/*
typedef struct packed {
    INST  inst;
    ADDR  PC;
    ADDR  NPC; // PC + 4
    logic valid;
    logic predict_taken;
    ADDR  predict_target;
} IF_ID_PACKET;
*/
module testbench;
    logic clock, reset, correct;
    IF_ID_PACKET [`N-1:0] if_id_packet;
    ID_OOO_PACKET id_ooo_packet;

    stage_decode dut(
        .if_id_packet(if_id_packet),
        .id_ooo_packet(id_ooo_packet)
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task init;
        reset = 1;
        correct = 1;
        for (int i = 0; i < `N; i++) begin
            if_id_packet[i] = 0;
        end
        @(negedge clock);
        reset = 0;
    endtask

    task one_inst;
        begin
            //if_id_packet[0].inst = {{7{1'b0}},{5{1'b0}},{5{1'b0}},3'b000,{5{1'b0}},`RV32_BRANCH};
            if_id_packet[0].valid = 1;
            if_id_packet[0].inst = 32'h00000013; // addi x0, x0, 0
            if_id_packet[0].PC = 32'h00000000;
            if_id_packet[0].NPC = 32'h00000004;
            if_id_packet[0].predict_taken = 0;
            if_id_packet[0].predict_target = 32'h00000004;
            #(`CLOCK_PERIOD/5.0);

            @(negedge clock);
            if_id_packet[0] = 0;
        end
    endtask
    

    task exit_on_error;
        begin
            $display("Error: stage_decode_test");
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (!correct) begin
            exit_on_error();
        end
    end

    initial begin
        clock = 0;
        init;
        $finish;
    end


endmodule
