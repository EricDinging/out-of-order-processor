
`include "sys_defs.svh"

module testbench;

    `define DEBUG_OUT 1
    
    logic clock, reset, failed;
    
    RS_IS_PACKET rs_is_packet;
    CDB_PACKET   cdb_packet;
    
    logic [`NUM_FU_ALU-1:0]   fu_alu_avail;
    logic [`NUM_FU_MULT-1:0]  fu_mult_avail;
    logic [`NUM_FU_LOAD-1:0]  fu_load_avail;
    logic [`NUM_FU_STORE-1:0] fu_store_avail;

    FU_PACKET [`NUM_FU_ALU-1:0]   fu_alu_packet;
    FU_PACKET [`NUM_FU_MULT-1:0]  fu_mult_packet;
    FU_PACKET [`NUM_FU_LOAD-1:0]  fu_load_packet;
    FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet;

    logic almost_full;
    
    RS_ENTRY [`RS_SZ-1:0]         entries_out;
    logic    [`RS_CNT_WIDTH-1:0] counter_out;

    rs dut(
        // input
        .clock           (clock),
        .reset           (reset),
        .rs_is_packet    (rs_is_packet),
        .cdb_packet      (cdb_packet),
        .fu_alu_avail    (fu_alu_avail),
        .fu_mult_avail   (fu_mult_avail),
        .fu_load_avail   (fu_load_avail),
        .fu_store_avail  (fu_store_avail),
        //output
        .fu_alu_packet   (fu_alu_packet),
        .fu_mult_packet  (fu_mult_packet),
        .fu_load_packet  (fu_load_packet),
        .fu_store_packet (fu_store_packet),
        .almost_full     (almost_full),
        .entries_out     (entries_out),
        .counter_out     (counter_out)
    );
    
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task init;
        reset  = 1;
        failed = 0;

        for (int i = 0; i < `N; ++i) begin
            rs_is_packet.entries[i] = '{
                .inst      : `NOP,
                .valid     : `FALSE,
                .PC        : 0,
                .fu        : FU_ALU,
                .func.alu  : ALU_ADD,
                .op1_ready : `FALSE,
                .op2_ready : `FALSE,
                .op1.prn   : 0,
                .op2.prn   : 0,
                .dest_prn  : 0,
                .robn      : 0
            };
        end

        fu_alu_avail   = {`NUM_FU_ALU   {`FALSE}};
        fu_mult_avail  = {`NUM_FU_MULT  {`FALSE}};
        fu_load_avail  = {`NUM_FU_LOAD  {`FALSE}};
        fu_store_avail = {`NUM_FU_STORE {`FALSE}};
    endtask // end init

    task test_almost_full;
        parameter ITER = `RS_SZ / `N;

        @(negedge clock) init;
        @(negedge clock);

        for (int i = 0; i < `N; ++i) begin
            rs_is_packet.entries[i].valid = `TRUE;
        end

        for (int i = 1; i < ITER; ++i) begin
            failed = almost_full;
            @(negedge clock);
        end

        failed = ~almost_full;
    endtask
    
    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display(fmt, $time, clock, counter_out, almost_full, entries_out, rs_is_packet, 
                     fu_alu_packet, fu_mult_packet, fu_load_packet, fu_store_packet, cdb_packet);
            $display("@@@ Failed ENDING TESTBENCH : ERROR !");
            $finish;
        end
    endtask

    // task concurrent_enter_cdb;
    //     begin
    //         rs_is_packet = {
    //             .entries : {`N{
    //                 .inst      : `NOP,
    //                 .valid     : `TRUE,
    //                 .PC        : 0,
    //                 .fu        : FU_ALU,
    //                 .func.alu  : ALU_ADD,
    //                 .op1_ready : `FALSE,
    //                 .op2_ready : `FALSE,
    //                 .op1.prn   : 1,
    //                 .op2.prn   : 2,
    //                 .dest_prn  : 3,
    //                 .robn      : 0
    //             }}
    //         };
    //         fu_alu_packet = {`NUM_FU_ALU   {`TRUE}};
    //         cdb_packet = {2{
    //             {
    //                 .valid    : `TRUE,
    //                 .dest_prn : 1,
    //                 .value    : 5
    //             }},
    //             {
    //                 .valid    : `TRUE,
    //                 .dest_prn : 2,
    //                 .value    : 3
    //             }
    //         };
    //     end
    // endtask

    always_ff @(negedge clock) begin
        if( failed ) begin
            exit_on_error();
        end
    end


    initial begin
        clock  = 0;

        init;

        fmt = "@@@ Time:%4.0f clock:%b counter:%b, almost_full:%b\n entries_out:%b\n, rs_is_packet:%b\n, 
                fu_alu_packet:%b\n, fu_mult_packet:%b\n, fu_load_packet:%b\n, 
                fu_store_packet:%b\n, cdb_packet:%b\n";
        
        test_almost_full;
        
        @(negedge clock);
        @(negedge clock);
        reset  = 0;
        @(negedge clock);
    end
endmodule
