`include "sys_defs.svh"

module testbench;

    logic clock, reset, correct;

    // intput
    ROB_IS_PACKET rob_is_packet;
    FU_ROB_PACKET [`CDB_SZ-1:0] fu_rob_packet;

    // output
    logic         almost_full;
    ROB_CT_PACKET rob_ct_packet;
    ROBN [`N-1:0] tail_entries;
    logic         squash, correct_squash;

    // debug output
    ROB_ENTRY [`ROB_SZ-1:0]        entries_out;
    logic     [`ROB_CNT_WIDTH-1:0] counter_out, correct_counter;
    logic     [`ROB_CNT_WIDTH-1:0] head_out, tail_out, correct_tail, correct_head;

    // testing parameters
    string fmt;


    rob dut(
        .clock(clock),
        .reset(reset),
        .rob_is_packet(rob_is_packet),
        .fu_rob_packet(fu_rob_packet),
        .almost_full(almost_full),
        .rob_ct_packet(rob_ct_packet),
        .tail_entries(tail_entries),
        .entries_out(entries_out),
        .counter_out(counter_out),
        .head_out(head_out),
        .tail_out(tail_out),
        .squash(squash)
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Failed ENDING TESTBENCH : ERROR !");
            $display("Time:%4.0f clock:%b counter:%b, almost_full:%b\n", $time, clock, counter_out, almost_full);
            print_entries_out();
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (~correct) begin
            exit_on_error();
        end
    end

    task print_entries_out;
        $display("time: %4.0f, counter: %d, almost_full: %b, head: %d, tail: %d, squash: %d\n", $time, counter_out, almost_full, head_out, tail_out, squash);
        for (int i = 0; i < `ROB_SZ; ++i) begin
            $display("idx %d: PC %d, executed %d\n", i, entries_out[i].PC, entries_out[i].executed);
        end
    endtask

    task init;
        reset           = 1;
        correct         = 1;
        correct_counter = 0;
        correct_head    = 0;
        correct_tail    = 0;
        correct_squash  = 0;

        for (int i = 0; i < `N; ++i) begin
            rob_is_packet.entries[i] <= '{
                0, // executed;
                0, // success;
                0, // is_store;
                0, // cond_branch;
                0, // uncond_branch;
                0, // resolve_taken;
                0, // predict_taken;
                0, // predict_target;
                0, // resolve_target;
                0, // dest_prn;
                0, // dest_arn;
                0, // PC;
                0, // NPC;
                0, // halt;
                0, // illegal;
                0 // csr_op; 
            };
            rob_is_packet.valid[i] = `FALSE;
        end

        for (int i = 0; i < `CDB_SZ; ++i) begin
            fu_rob_packet[i] = '{
                0,   // robn
                0,   // executed
                0,   // branch_taken
                0    // target_addr
            };
        end

        @(negedge clock);
        reset = 0;
    endtask
    
    task test_almost_full_counter;
        parameter ITER = `ROB_SZ / `N;
        init();
        @(negedge clock);
        correct = almost_full == `FALSE;

        for (int i = 0; i < `N; ++i) begin
            rob_is_packet.entries[i] <= '{
                0,           // executed;
                0,           // success;
                $random % 2, // is_store;
                $random % 2, // cond_branch;
                $random % 2, // uncond_branch;
                $random % 2, // resolve_taken;
                $random % 2, // predict_taken;
                $random,     // predict_target;
                $random,     // resolve_target;
                $random,     // dest_prn;
                $random,     // dest_arn;
                i * 4,       // PC;
                i * 4 + 4,   // NPC;
                $random % 2, // halt;
                $random % 2, // illegal;
                0            // csr_op; 
            };
            rob_is_packet.valid[i] = `TRUE;
        end

        for (int i = 0; i < ITER - 1; ++i) begin
            @(negedge clock);
            correct_counter += `N;
            correct_tail    += `N;
            correct = correct && counter_out == correct_counter && !almost_full && head_out == correct_head && tail_out == correct_tail && squash == correct_squash;
            $display("time: %4.0f, iteration: %d\n", $time, i);
            print_entries_out();
        end

        @(negedge clock);
        correct_counter += `N;
        correct_tail    = (correct_tail + `N) % `ROB_SZ;
        correct = correct && counter_out == correct_counter 
               && almost_full && head_out == correct_head 
               && tail_out == correct_tail && squash == correct_squash;
                    
        for (int i = 0; i < ITER; ++i) begin
            @(negedge clock);
            correct = correct && counter_out == correct_counter 
               && almost_full && head_out == correct_head 
               && tail_out == correct_tail && squash == correct_squash;
        end

        print_entries_out();
        $display("@@@ Passed: test_almost_full_counter");
    endtask

    task test_dummy_commit;
        parameter ITER = `ROB_SZ / `N;
        init();

        for (int i = 0; i < `N; ++i) begin
            rob_is_packet.entries[i] <= '{
                1,           // executed;
                1,           // success;
                $random % 2, // is_store;
                $random % 2, // cond_branch;
                $random % 2, // uncond_branch;
                $random % 2, // resolve_taken;
                $random % 2, // predict_taken;
                $random,     // predict_target;
                $random,     // resolve_target;
                $random,     // dest_prn;
                $random,     // dest_arn;
                i * 4,       // PC;
                i * 4 + 4,   // NPC;
                $random % 2, // halt;
                $random % 2, // illegal;
                0            // csr_op; 
            };
            rob_is_packet.valid[i] = `TRUE;
        end

        @(negedge clock);
        correct_counter = `N;
        correct_tail    += `N;
        correct_head    = 0;
        correct = correct && counter_out == correct_counter && head_out == correct_head && tail_out == correct_tail && squash == correct_squash;
        $display("time: %4.0f\n", $time);
        print_entries_out();


        for (int i = 0; i < ITER - 1; ++i) begin
            @(negedge clock);
            correct_counter = `N;
            correct_tail = (correct_tail + `N) % `ROB_SZ;
            correct_head = (correct_head + `N) % `ROB_SZ;
            correct = correct && counter_out == correct_counter && head_out == correct_head && tail_out == correct_tail && squash == correct_squash;
            $display("time: %4.0f, iteration: %d\n", $time, i);
            print_entries_out();
        end

        rob_is_packet.entries[0].executed = 0;

        @(negedge clock);
        correct_counter = `N;
        correct_tail = (correct_tail + `N) % `ROB_SZ;
        correct_head = (correct_head + `N) % `ROB_SZ;
        correct = correct && counter_out == correct_counter && head_out == correct_head && tail_out == correct_tail && squash == correct_squash;
        $display("time: %4.0f\n", $time);
        print_entries_out();

        for (int i = 0; i < ITER - 1; ++i) begin
            @(negedge clock);
            correct_counter += `N;
            correct_tail = (correct_tail + `N) % `ROB_SZ;
            correct_head = correct_head;
            correct = correct && counter_out == correct_counter && head_out == correct_head && tail_out == correct_tail && squash == correct_squash;
            $display("time: %4.0f, iteration: %d\n", $time, i);
            print_entries_out();
        end

        correct = correct && almost_full;

        @(negedge clock);
        $display("@@@ Passed: test_dummy_commit");
    endtask
    
    initial begin
        clock = 0;

        test_almost_full_counter();
        // test_dummy_commit();
        $display("@@@ Passed");
        $finish;
    end
    
endmodule