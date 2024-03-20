`include "sys_defs.svh"
`define DEBUG_OUT

module testbench;
    parameter SIZE = `ARCH_REG_SZ;

    logic clock, reset, correct;

    // input
    RAT_IS_INPUT rat_is_input;
    RRAT_CT_OUTPUT rrat_ct_output;
    
    // output
    RAT_IS_OUTPUT rat_is_output;
    PRN head, tail;
    logic [`FREE_LIST_CTR_WIDTH-1:0] counter;
    PRN   [`PHYS_REG_SZ_R10K-1:0] free_list;
    PRN   [SIZE-1:0] rat_table_out;

    // debug
    logic [`FREE_LIST_PTR_WIDTH-1:0] correct_head;
    logic [`FREE_LIST_PTR_WIDTH-1:0] correct_tail;
    logic [`FREE_LIST_CTR_WIDTH-1:0] correct_counter;

    rat dut(
        .clock(clock),
        .reset(reset),
        .rat_is_input(rat_is_input),
        .rrat_ct_output(rrat_ct_output),
        .rat_is_output(rat_is_output),
        .head(head),
        .tail(tail),
        .counter(counter),
        .free_list(free_list),
        .rat_table_out(rat_table_out)
    );


    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task print_table;
        $display("Time:%4.0f, RAT Table:", $time);
        for (int i = 0; i < `ARCH_REG_SZ; ++i) begin
            $display("rat_table_out[%d]: %d", i, rat_table_out[i]);
        end
    endtask

    task print_is_input;
        $display("Time:%4.0f, RAT IS Input:", $time);
        for (int i = 0; i < `N; ++i) begin
            $display("rat_is_input[%d]: dest_arn:%d, op1_arn:%d, op2_arn:%d", i, rat_is_input.entries[i].dest_arn, rat_is_input.entries[i].op1_arn, rat_is_input.entries[i].op2_arn);
        end
    endtask

    task print_free_list;
        $display("Time:%4.0f, RRAT Free List counter:%d, head:%d, tail:%d,", $time, counter, head, tail);
        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            $display("free_list[%d]: %d", i, free_list[i]);
        end
    endtask

    task print_is_output;
        $display("Time:%4.0f, RAT IS Output:", $time);
        for (int i = 0; i < `N; ++i) begin
            $display("rat_is_output[%d]: dest_prn:%d, op1_prn:%d, op2_prn:%d", i, rat_is_output.entries[i].dest_prn, rat_is_output.entries[i].op1_prn, rat_is_output.entries[i].op2_prn);
        end
    endtask

    task exit_on_error;
        $display("@@@ Incorrect at time %4.0f", $time);
        $display("@@@ Failed ENDING TESTBENCH : ERROR !");
        $display("correct_counter:%d, correct_head:%d, correct_tail:%d", correct_counter, correct_head, correct_tail);
        // print_table();
        // print_free_list();
        // print_is_input();
        // print_is_output();
        $finish;
    endtask
    
    always_ff @(negedge clock) begin
        if (~correct) begin
            exit_on_error();
        end
    end

    task init;
        reset = 1;
        correct = 1;
        correct_head = `ARCH_REG_SZ;
        correct_tail = 0;
        correct_counter = `PHYS_REG_SZ_R10K - `ARCH_REG_SZ;

        for (int i = 0; i < `N; ++i) begin
            rat_is_input.entries[i].dest_arn = 0;
            rat_is_input.entries[i].op1_arn  = 0;
            rat_is_input.entries[i].op2_arn  = 0;
            rrat_ct_output.free_packet[i].valid = `FALSE;
            rrat_ct_output.free_packet[i].prn   = 0;
        end
        
        rrat_ct_output.squash = `FALSE;
        rrat_ct_output.head   = `ARCH_REG_SZ;
        rrat_ct_output.tail   = 0;
        rrat_ct_output.free_list_counter = `PHYS_REG_SZ_R10K - `ARCH_REG_SZ;
        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            rrat_ct_output.free_list[i] = 0;
        end

        @(negedge clock);
        reset = 0;
    endtask

    task test_no_target_arn;
        parameter ITER = `PHYS_REG_SZ_R10K / `N;
        init();
        
        for (int i = 0; i < ITER; ++i) begin
            @(negedge clock);
            correct = correct && counter == correct_counter && head == correct_head && tail == correct_tail;
        end

        $display("@@@ Passed test_no_target_arn");
    endtask

    task test_target_arn;
        parameter ITER = (`PHYS_REG_SZ_R10K - `ARCH_REG_SZ) / `N;
        init();

        for (int i = 0; i < ITER; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                rat_is_input.entries[j].dest_arn = i * `N + j + 1;
                rat_is_input.entries[j].op1_arn  = i * `N + j + 1;
                rat_is_input.entries[j].op2_arn  = 0;
            end
            #1;

            for (int j = 0; j < `N; ++j) begin
                correct = correct && rat_is_output.entries[j].dest_prn == `ARCH_REG_SZ + i * `N + j;
                correct = correct && rat_is_output.entries[j].op1_prn == i * `N + j + 1;
                correct = correct && rat_is_output.entries[j].op2_prn == 0;
            end
            
            @(negedge clock);

            correct_counter = correct_counter - `N;
            correct_head = (correct_head + `N) % `PHYS_REG_SZ_R10K;
            correct_tail = correct_tail;
            correct = correct && counter == correct_counter && head == correct_head && tail == correct_tail;
        end

        // test new input, there should not be any change in rat
        for (int j = 0; j < `N; ++j) begin
            rat_is_input.entries[j].dest_arn = 1;
            rat_is_input.entries[j].op1_arn  = 0;
            rat_is_input.entries[j].op2_arn  = 0;
        end
        #1;

        for (int j = 0; j < `N; ++j) begin
            correct = correct && rat_is_output.entries[j].dest_prn == 0;
            correct = correct && rat_is_output.entries[j].op1_prn == 0;
            correct = correct && rat_is_output.entries[j].op2_prn == 0;
        end
        
        @(negedge clock);
        correct = correct && counter == correct_counter && head == correct_head && tail == correct_tail;
        $display("@@@ Passed test_target_arn");
    endtask
    
    task test_rrat_push;
        parameter ITER = `ARCH_REG_SZ / `N;
        init();

        for (int i = 0; i < ITER; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                rrat_ct_output.free_packet[j].valid = `TRUE;
                rrat_ct_output.free_packet[j].prn   = i * `N + j + 1;
            end
            
            @(negedge clock);

            correct_counter = correct_counter + `N;
            correct_tail = (correct_tail + `N) % `PHYS_REG_SZ_R10K;
            correct = correct && counter == correct_counter && head == correct_head && tail == correct_tail;
        end
        
        $display("@@@ Passed test_rrat_push");
    endtask


    task test_rrat_squash;
        init();

        rrat_ct_output.squash = `TRUE;
        rrat_ct_output.head   = 0;
        rrat_ct_output.tail   = `PHYS_REG_SZ_R10K - `ARCH_REG_SZ;
        rrat_ct_output.free_list_counter = `PHYS_REG_SZ_R10K - `ARCH_REG_SZ;
        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            rrat_ct_output.free_list[i] = `PHYS_REG_SZ_R10K - i - 1;
        end

        rat_is_input.entries[0].dest_arn = 1;
        rat_is_input.entries[0].op1_arn  = 0;
        rat_is_input.entries[0].op2_arn  = 0;

        @(negedge clock);
        rrat_ct_output.squash = `FALSE;
        correct_counter = `PHYS_REG_SZ_R10K - `ARCH_REG_SZ;
        correct_head = 0;
        correct_tail = `PHYS_REG_SZ_R10K - `ARCH_REG_SZ;
        correct = correct && counter == correct_counter && head == correct_head && tail == correct_tail;
        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            correct = correct && free_list[i] == `PHYS_REG_SZ_R10K - i - 1;
        end

        $display("@@@ Passed test_rrat_squash");
    endtask

    task test_concurrent_push;
        parameter ITER = 100;
        init();

        for (int i = 0; i < ITER; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                rrat_ct_output.free_packet[j].valid = `TRUE;
                rrat_ct_output.free_packet[j].prn   = (i * `N + j) % (`PHYS_REG_SZ_R10K - 1) + 1;
            end

            for (int j = 0; j < `N; ++j) begin
                rat_is_input.entries[j].dest_arn = (i * `N + j) % (`ARCH_REG_SZ - 1) + 1;
                rat_is_input.entries[j].op1_arn  = (i * `N + j - 1 + `ARCH_REG_SZ - 1) % (`ARCH_REG_SZ - 1) + 1;
                rat_is_input.entries[j].op2_arn  = (i * `N + j) % (`ARCH_REG_SZ - 1) + 1;
            end

            #1;

            for (int j = 0; j < `N; ++j) begin
                correct = correct && rat_is_output.entries[j].dest_prn == (`ARCH_REG_SZ + i * `N + j - 1) % (`PHYS_REG_SZ_R10K - 1) + 1;
                
                if (j >= 1) begin
                    correct = correct && rat_is_output.entries[j].op1_prn == (`ARCH_REG_SZ + i * `N + j - 2) % (`PHYS_REG_SZ_R10K - 1) + 1;
                end
            end
            @(negedge clock);

            correct_counter = correct_counter;
            correct_head = (correct_head + `N) % `PHYS_REG_SZ_R10K;
            correct_tail = (correct_tail + `N) % `PHYS_REG_SZ_R10K;
            correct = correct && counter == correct_counter && head == correct_head && tail == correct_tail;
        end
        
        $display("@@@ Passed test_concurrent_push");
    endtask



    initial begin
        clock = 0;

        test_no_target_arn();

        test_target_arn();

        test_rrat_push();
        
        test_rrat_squash();

        test_concurrent_push();
        
        $display("@@@ Passed");
        $finish;
    end

endmodule