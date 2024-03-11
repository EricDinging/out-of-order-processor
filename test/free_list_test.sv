`include "sys_defs.svh"
`define DEBUG_OUT

module testbench;

    parameter SIZE = `PHYS_REG_SZ_R10K;

    logic clock, reset, correct;

    // input
    FREE_LIST_PACKET [`N-1:0]           push_packet;
    logic            [`N-1:0]           pop_en;
    PRN              [SIZE-1:0]         input_free_list;
    logic                               rat_squash;

    // output
    FREE_LIST_PACKET [`N-1:0]           pop_packet;
    PRN              [SIZE-1:0]         output_free_list;
    
    // debug output
    logic [`FREE_LIST_PTR_WIDTH-1:0] head_out, correct_head;
    logic [`FREE_LIST_PTR_WIDTH-1:0] tail_out, correct_tail;
    logic [`FREE_LIST_CTR_WIDTH-1:0] counter_out, correct_counter;

    free_list dut(
        .clock(clock),
        .reset(reset),
        .push_packet(push_packet),
        .pop_en(pop_en),
        .input_free_list(input_free_list),
        .rat_squash(rat_squash),
        // output
        .pop_packet(pop_packet),
        .output_free_list(output_free_list),
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
            $display("@@@ Failed ENDING TESTBENCH : ERROR !");
            $display("Time:%4.0f clock:%b counter:%d head:%d, tail:%d\n", $time, clock, counter_out, head_out, tail_out);
            $display("correct_counter:%d correct_head:%d, correct_tail:%d\n", correct_counter, correct_head, correct_tail);
            print_entries_out();
            print_pop_packet();
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (~correct) begin
            exit_on_error();
        end
    end

    task print_entries_out;
        $display("time: %4.0f, counter: %d, head: %d, tail: %d, rat_squash: %d\n", $time, counter_out, head_out, tail_out, rat_squash);
        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            $display("idx %d: prn: %d\n", i, output_free_list[i]);
        end
    endtask

    task print_pop_packet;
        for (int i = 0; i < `N; ++i) begin
            $display("pop_packet: idx %d: valid %b prn: %d\n", i, pop_packet[i].valid, pop_packet[i].prn);
        end
    endtask

    task init;
        reset = 1;
        correct = 1;

        correct_head = 0;
        correct_tail = 0;
        correct_counter = `PHYS_REG_SZ_R10K;

        for (int i = 0; i < `N; ++i) begin
            push_packet[i].valid = `FALSE;
            push_packet[i].prn   = 0;
            pop_en[i]            =`FALSE;
            input_free_list[i]   = 0;
        end

        rat_squash = 0;

        @(negedge clock);
        reset = 0;
    endtask
    
    task test_counter;
        parameter ITER = `PHYS_REG_SZ_R10K / `N;
        init();

        @(negedge clock);

        correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;

        pop_en = {`N{`TRUE}};

        for (int i = 0; i < ITER; ++i) begin
            @(negedge clock);
            correct_counter -= `N;
            correct_head += `N;
            correct_tail = correct_tail;
            correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;

            for (int j = 0; j < `N; ++j) begin
                correct = correct && pop_packet[j].valid && pop_packet[j].prn == i * `N + j;
            end
            print_entries_out();
            print_pop_packet();
        end

        $display("@@@ Passed test_counter");
    endtask

    initial begin
        clock = 0;

        test_counter();
        
        $display("@@@ Passed");
        $finish;
    end

endmodule