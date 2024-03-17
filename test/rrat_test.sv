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

    REG_IDX arn;
    
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

    task print_free_packet;
        $display("Time:%4.0f, RRAT Free Packet", $time);
        for (int i = 0; i < `N; ++i) begin
            $display("free_packet[%d]: prn:%d, valid:%b", i, rrat_ct_output.free_packet[i].prn, rrat_ct_output.free_packet[i].valid);
        end
    endtask

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Failed ENDING TESTBENCH : ERROR !");
            $display("correct_counter:%d, correct_head:%d, correct_tail:%d", correct_counter, correct_head, correct_tail);
            print_table();
            print_free_packet();
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

    task test_target_arn;
        parameter ITER = (`PHYS_REG_SZ_R10K - `ARCH_REG_SZ) / `N;
        init();


        $monitor("Time:%4.0f, free_packet[0]: prn:%d, valid:%b", $time, rrat_ct_output.free_packet[0].prn, rrat_ct_output.free_packet[0].valid);
        
        for (int i = 0; i < ITER; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                rrat_ct_input.success[j] = `TRUE;
                rrat_ct_input.arns[j]    = i * `N + j + 1;
            end

            #1;

            for (int j = 0; j < `N; ++j) begin
                correct = correct && rrat_ct_output.free_packet[j].prn == i * `N + j + 1 && rrat_ct_output.free_packet[j].valid == `TRUE;
            end

            @(negedge clock);
            correct_counter = correct_counter;
            correct_head = (correct_head + `N) % `PHYS_REG_SZ_R10K;
            correct_tail = (correct_tail + `N) % `PHYS_REG_SZ_R10K;
            correct = correct && rrat_ct_output.free_list_counter == correct_counter && rrat_ct_output.head == correct_head && rrat_ct_output.tail == correct_tail;
            correct = correct && ~rrat_ct_output.squash;

            for (int j = 0; j < `N; ++j) begin
                correct = correct && rrat_ct_output.entries[i * `N + j + 1] == (`ARCH_REG_SZ + i * `N + j) % `PHYS_REG_SZ_R10K;
            end
        end

        for (int i = 0; i < ITER; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                rrat_ct_input.success[j] = `TRUE;
                rrat_ct_input.arns[j]    = i * `N + j + 1;
            end
            #1;
            
            for (int j = 0; j < `N; ++j) begin
                correct = correct && rrat_ct_output.free_packet[j].prn == (`ARCH_REG_SZ + i * `N + j) % `PHYS_REG_SZ_R10K && rrat_ct_output.free_packet[j].valid == `TRUE;
            end

            @(negedge clock);
            correct_counter = correct_counter;
            correct_head = (correct_head + `N) % `PHYS_REG_SZ_R10K;
            correct_tail = (correct_tail + `N) % `PHYS_REG_SZ_R10K;
            correct = correct && rrat_ct_output.free_list_counter == correct_counter && rrat_ct_output.head == correct_head && rrat_ct_output.tail == correct_tail;
            correct = correct && ~rrat_ct_output.squash;

            for (int j = 0; j < `N; ++j) begin
                correct = correct && rrat_ct_output.entries[i * `N + j + 1] == i * `N + j + 1;
            end
        end

        $display("@@@ Passed test_target_arn");
    endtask

    task test_unique_target;
        parameter ITER = (`PHYS_REG_SZ_R10K - `ARCH_REG_SZ) / `N;
        init();

        arn = $random % (`ARCH_REG_SZ - 1) + 1;
        
        for (int j = 0; j < `N; ++j) begin
            rrat_ct_input.success[j] = `TRUE;
            rrat_ct_input.arns[j]    = arn;
        end

        #1;

        correct = correct && rrat_ct_output.free_packet[0].prn == arn && rrat_ct_output.free_packet[0].valid == `TRUE;

        for (int j = 1; j < `N; ++j) begin
            correct = correct && rrat_ct_output.free_packet[j].prn == `ARCH_REG_SZ + j - 1 && rrat_ct_output.free_packet[j].valid == `TRUE;
        end

        @(negedge clock);
        correct_counter = correct_counter;
        correct_head = (correct_head + `N) % `PHYS_REG_SZ_R10K;
        correct_tail = (correct_tail + `N) % `PHYS_REG_SZ_R10K;
        correct = correct && rrat_ct_output.free_list_counter == correct_counter && rrat_ct_output.head == correct_head && rrat_ct_output.tail == correct_tail;
        correct = correct && ~rrat_ct_output.squash;

        correct = correct && rrat_ct_output.entries[arn] == `ARCH_REG_SZ + `N - 1;

        $display("@@@ Passed test_unique_target");
    endtask

    task test_squash;
        init();

        for (int i = 0; i < `N; ++i) begin

            for (int j = 0; j < `N; ++j) begin
                rrat_ct_input.success[j] = `TRUE;
                rrat_ct_input.arns[j]    = j + 1;
            end

            rrat_ct_input.success[i] = `FALSE;

            @(negedge clock);
            correct_tail = (correct_tail + i + 1) % `PHYS_REG_SZ_R10K;
            correct_head = (correct_head + i + 1) % `PHYS_REG_SZ_R10K;
            correct = correct && rrat_ct_output.squash;
            correct = correct && correct_counter == rrat_ct_output.free_list_counter && correct_head == rrat_ct_output.head && correct_tail == rrat_ct_output.tail;
        end
    
        $display("@@@ Passed test_squash");
    endtask

    initial begin
        clock = 0;

        test_no_target_arn();

        test_target_arn();

        test_unique_target();

        test_squash();
        
        $display("@@@ Passed");
        $finish;
    end



endmodule;