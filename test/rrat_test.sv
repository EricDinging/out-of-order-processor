`include "sys_defs.svh"

module testbench;
    parameter SIZE = `ARCH_REG_SZ;

    logic clock, reset, correct;

    // input 
    RRAT_CT_INPUT rrat_ct_input;

    // output
    RRAT_CT_OUTPUT rrat_ct_output;

    logic [`FREE_LIST_PTR_WIDTH-1:0] correct_head;
    logic [`FREE_LIST_PTR_WIDTH-1:0] correct_tail;
    logic [`FREE_LIST_CTR_WIDTH-1:0] correct_counter;

    // DUT
    rrat dut(
        .clock(clock),
        .reset(reset),
        .rrat_ct_input(rrat_ct_input),
        .rrat_ct_output(rrat_ct_output)
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task print_table;
        $display("Time:%4.0f, RRAT Table", $time);
        for (int i = 0; i < `ARCH_REG_SZ; ++i) begin
            $display("arns:%d, prns: %d", i, rrat_ct_output.entries[i]);
        end
    endtask

    task print_free_list;
        $display("Time:%4.0f, RRAT Free List counter:%d, head:%d, tail:%d,", $time, rrat_ct_output.free_list_counter, rrat_ct_output.head, rrat_ct_output.tail);
        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            $display("free_list[%d]: %d", i, rrat_ct_output.free_list[i]);
        end
    endtask

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Failed ENDING TESTBENCH : ERROR !");
            // $display("correct_counter:%d correct_head:%d, correct_tail:%d\n", correct_counter, correct_head, correct_tail);
            print_table();
            print_free_list();
            $finish;
        end
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
            rrat_ct_input.success[i] = `TRUE;
            rrat_ct_input.arns[i]    = 0;
        end
        
        @(negedge clock);
        reset = 0;

    endtask

    task test_no_target_arn;
        parameter ITER = `PHYS_REG_SZ_R10K / `N;
        init();
        
        for (int i = 0; i < ITER; ++i) begin
            @(negedge clock);
            correct = correct && rrat_ct_output.free_list_counter == correct_counter && rrat_ct_output.head == correct_head && rrat_ct_output.tail == correct_tail;
            correct = correct && ~rrat_ct_output.squash;
        end

        $display("@@@ Passed test_no_target_arn");
    endtask

    initial begin
        clock = 0;

        test_no_target_arn();
        
        $display("@@@ Passed");
        $finish;
    end



endmodule;