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
        .tail_out(tail_out)
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("Time:%4.0f clock:%b counter:%b, almost_full:%b\n", $time, clock, counter_out, almost_full);
            $display("@@@ Failed ENDING TESTBENCH : ERROR !");
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (~correct) begin
            exit_on_error();
        end
    end

    task print_entries_out;
        $display("time: %4.0f, counter: %d, almost_full: %b, head: %d, tail: %d\n", $time, counter_out, almost_full, head_out, tail_out);
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

        for (int i = 0; i < `N; ++i) begin
            rob_is_packet.entries[i] = '{
                0,   // executed;
                0,   // success;
                0,   // is_store;
                0,   // is_branch;
                0,   // dest_prn;
                0,   // dest_arn;
                0,   // PC;
                0,   // NPC;
                0,   // halt;
                0,   // illegal;
                0   // csr_op; 
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
            rob_is_packet.entries[i] = '{
                0,             // executed;
                $random % 2,   // success;
                $random % 2,   // is_store;
                $random % 2,   // is_branch;
                $random,       // dest_prn;
                $random,       // dest_arn;
                i * 4,         // PC;
                i * 4 + 4,     // NPC;
                $random % 2,   // halt;
                $random % 2,   // illegal;
                0              // csr_op; 
            };
            rob_is_packet.valid[i] = `TRUE;
        end

        for (int i = 0; i < ITER - 1; ++i) begin
            @(negedge clock);
            correct_counter += `N;
            correct_tail    += `N;
            correct = correct && counter_out == correct_counter && !almost_full && head_out == correct_head && tail_out == correct_tail;
            $display("time: %4.0f, iteration: %d\n", $time, i);
            print_entries_out();
        end
        @(negedge clock);
        correct_counter += `N;
        correct_tail    += `N;
        correct = correct && counter_out == correct_counter && almost_full && head_out == correct_head && tail_out == correct_tail;
        $display("@@@ Passed: test_almost_full_counter");
        print_entries_out();
    endtask

    
    initial begin
        clock = 0;

        test_almost_full_counter();
        $display("@@@ PASSED");
        $finish;
    end
    
endmodule