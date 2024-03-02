
`include "sys_defs.svh"

module testbench;

    `define DEBUG_OUT 1
    
    logic clock, reset, failed;
    wor failed_wor;
    
    RS_IS_PACKET rs_is_packet;
    CDB_PACKET [`N-1:0]   cdb_packet;

    string fmt;
    
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
    logic    [`RS_CNT_WIDTH-1:0]  counter_out, correct_counter;

    // testing parameters
    logic [`N-1:0] inst_idx;
    logic [`N-1:0] cdb_packet_idx;
    logic [31:0]          cdb_packet_valid_cycle;

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
        correct_counter = 0;

        for (int i = 0; i < `N; ++i) begin
            rs_is_packet.entries[i] = '{
                `NOP,                  // inst
                `FALSE,                // valid
                32'h0,                 // PC
                FU_ALU,                // fu_type
                ALU_ADD,               // fu_func
                `FALSE,                // op1_ready
                `FALSE,                // op2_ready
                32'h0,                 // op1
                32'h0,                 // op2
                {`PRN_WIDTH{1'h0}},    // dest_prn
                {`ROB_CNT_WIDTH{1'h0}} // dest_rob
            };
            
            cdb_packet[i] = '{
                `FALSE,
                {`PRN_WIDTH{1'h0}}, // dest_prn
                32'h0               // value
            };
        end

        fu_alu_avail   = {`NUM_FU_ALU   {`FALSE}};
        fu_mult_avail  = {`NUM_FU_MULT  {`FALSE}};
        fu_load_avail  = {`NUM_FU_LOAD  {`FALSE}};
        fu_store_avail = {`NUM_FU_STORE {`FALSE}};

        @(negedge clock);
        reset = 0;

    endtask // end init

    task check_fu_output_invalid;
        for (int i = 0; i < `NUM_FU_ALU; ++i) begin
            failed = failed | fu_alu_packet[i].valid;
        end

        for (int i = 0; i < `NUM_FU_MULT; ++i) begin
            failed = failed | fu_mult_packet[i].valid;
        end
        
        for (int i = 0; i < `NUM_FU_LOAD; ++i) begin
            failed = failed | fu_load_packet[i].valid;
        end

        for (int i = 0; i < `NUM_FU_STORE; ++i) begin
            failed = failed | fu_store_packet[i].valid;
        end
        $display("@@@ Passed: check_fu_output_invalid");
    endtask

    task test_almost_full_counter;
        parameter ITER = `RS_SZ / `N;
        init;
        @(negedge clock);

        for (int i = 0; i < `N; ++i) begin
            rs_is_packet.entries[i].valid = `TRUE;
        end

        for (int i = 1; i < ITER; ++i) begin
            $display("time: %4.0f, iteration:%d clock:%b counter:%b, almost_full:%b, valid:%b\n", $time, i, clock, counter_out, almost_full, entries_out[i*`N-`N].valid);
            
            failed = almost_full | (correct_counter != counter_out);
            correct_counter = correct_counter + `N;

            @(negedge clock);
        end
        
        $display("time: %4.0f, iteration:%d clock:%b counter:%b, almost_full:%b, valid:%b\n", $time, ITER, clock, counter_out, almost_full,entries_out[3].valid);

        @(negedge clock);
        failed = ~almost_full | (`RS_SZ != counter_out);

        @(negedge clock);

        $display("Check entries valid bits");
        for (int i = 0; i < `RS_SZ; ++i) begin
            failed = failed || !entries_out[i].valid;
            $display("time: %4.0f, iteration: %h, valid: %b", $time, i, entries_out[i].valid);
        end

        @(negedge clock);
        @(negedge clock);
        $display("@@@ Passed: test_almost_full_counter");
        check_fu_output_invalid;
    endtask

    task test_concurrent_enter_cdb;
        begin
            init;
            for (int i = 0; i < `N; ++i) begin
                rs_is_packet.entries[i] = '{
                    `NOP,  // unused
                    `TRUE, // valid
                    32'h0, // PC
                    FU_ALU,
                    ALU_ADD,
                    `FALSE, // op1_ready
                    `FALSE, // op2_ready
                    32'h1,  // op1
                    32'h2,  // op2
                    32'h3,  // dest_prn
                    {`ROB_CNT_WIDTH{1'h0}} // robn
                };
            end
            // fu_alu_avail = {`NUM_FU_ALU   {`TRUE}};
            
            cdb_packet[0] = '{
                `TRUE,
                32'h1,
                32'h5
            };

            @(negedge clock);

            for (int i = 0; i < `N; ++i) begin
                $display("input_valid:%b, cdb_valid:%b\n", rs_is_packet.entries[i].valid, cdb_packet[i].valid);
            end
            
            for (int i = 0; i < `N; ++i) begin
                $display("time: %4.0f, inst:%d valid: %b op1_ready: %b, op1_value: %h\n", $time, i, entries_out[i].valid, entries_out[i].op1_ready, entries_out[i].op1);
                failed = failed || !entries_out[i].op1_ready || entries_out[i].op1 != 32'h5;
            end

            check_fu_output_invalid;

            @(negedge clock);
            @(negedge clock);

            $display("@@@ Passed: test_concurrent_enter_cdb");
        end
    endtask

    task test_random_cdb;
        begin
            init;

            inst_idx = ($urandom) % `N;
            cdb_packet_idx = ($urandom) % `N;
            cdb_packet_valid_cycle = ($urandom) % 10 + 1;

            $display("inst_idx:%d, cdb_packet_idx:%d, cdb_packet_valid_cycle:%d", inst_idx, cdb_packet_idx, cdb_packet_valid_cycle);

            // for (int i = 0; i <= inst_idx; ++i) begin
            //     rs_is_packet.entries[i].valid = `TRUE;
            // end

            // @(negedge clock);

            for (int i = 0; i <= inst_idx; ++i) begin
                rs_is_packet.entries[i] = '{
                    `NOP,  // unused
                    `TRUE, // valid
                    32'h0, // PC
                    FU_ALU,
                    ALU_ADD,
                    `FALSE, // op1_ready
                    `FALSE, // op2_ready
                    32'h1,  // op1
                    32'h2,  // op2
                    32'h3,  // dest_prn
                    {`ROB_CNT_WIDTH{1'h0}} // robn
                };
            end

            @(negedge clock);

            for (int i = 0; i <= inst_idx; ++i) begin
                rs_is_packet.entries[i].valid = `FALSE;
            end
            
            // fu_alu_avail = {`NUM_FU_ALU   {`TRUE}};
            for (int i = 0; i < cdb_packet_valid_cycle; ++i) begin
                @(negedge clock);
            end

            cdb_packet[cdb_packet_idx] = '{
                `TRUE,
                32'h1,
                32'h5
            };

            @(negedge clock);
            
            for (int i = 0; i < `N; ++i) begin
                $display("time: %4.0f, inst:%d valid: %b op1_ready: %b, op1_value: %h\n", $time, i, entries_out[i].valid, entries_out[i].op1_ready, entries_out[i].op1);
            end

            for (int i = 0; i <= inst_idx; ++i) begin
                failed = failed || !entries_out[i].valid || !entries_out[i].op1_ready || entries_out[i].op1 != 32'h5;
            end

            // for (int i = inst_idx + 1; i <= 2 * inst_idx; ++i) begin
            //     failed = failed || !entries_out[i].valid || !entries_out[i].op1_ready || entries_out[i].op1 != 32'h5;
            // end

            @(negedge clock);
            @(negedge clock);

            $display("@@@ Passed: test_random_cdb");
            check_fu_output_invalid;
        end
    endtask
    
    task test_execute;
        begin
            init;
            rs_is_packet.entries[0] = '{
                    `NOP,  // unused
                    `TRUE, // valid
                    32'h0, // PC
                    FU_ALU,
                    ALU_ADD,
                    `TRUE, // op1_ready
                    `TRUE, // op2_ready
                    32'h1,  // op1
                    32'h2,  // op2
                    32'h3,  // dest_prn
                    {`ROB_CNT_WIDTH{1'h0}} // robn
                };

            check_fu_output_invalid;
            fu_alu_avail[0] = `TRUE;  
            @(negedge clock);
            rs_is_packet.entries[0].valid = `FALSE;

            $display("time: %4.0f, fu_alu_packet[0].valid:%b", $time, fu_alu_packet[0].valid);
            failed = (counter_out != 1) || (fu_alu_packet[0].valid == `FALSE);

            @(negedge clock)
            failed = (counter_out != 0);
            @(negedge clock)

            $display("@@@ Passed: test_execute");
        end
    endtask

    

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("Time:%4.0f clock:%b counter:%b, almost_full:%b\n", $time, clock, counter_out, almost_full);
            // $display(fmt, $time, clock, counter_out, almost_full, entries_out, rs_is_packet, 
            //          fu_alu_packet, fu_mult_packet, fu_load_packet, fu_store_packet, cdb_packet);
            $display("@@@ Failed ENDING TESTBENCH : ERROR !");
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (failed) begin
            exit_on_error();
        end
    end


    initial begin
        clock  = 0;


        fmt = "@@@ Time:%4.0f clock:%b counter:%b, almost_full:%b\n entries_out:%b\n, rs_is_packet:%b\n, \
                fu_alu_packet:%b\n, fu_mult_packet:%b\n, fu_load_packet:%b\n, \
                fu_store_packet:%b\n, cdb_packet:%b\n";
        
        // test_almost_full_counter;
        // test_concurrent_enter_cdb;
        // for (int i = 0; i < 10; ++i) begin
        //     test_random_cdb;
        // end
        test_execute;
        
        $finish;
    end
endmodule
