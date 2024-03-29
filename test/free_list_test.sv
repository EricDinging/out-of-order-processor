`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module testbench;

    parameter SIZE = `PHYS_REG_SZ_R10K;

    logic clock, reset, correct;

    // input
    FREE_LIST_PACKET       [`N-1:0]     push_packet;
    logic                  [`N-1:0]     pop_en;
    PRN                   [SIZE-1:0]    input_free_list;
    logic                               rat_squash;
    logic [`FREE_LIST_PTR_WIDTH-1:0]    head_in;
    logic [`FREE_LIST_PTR_WIDTH-1:0]    tail_in;
    logic [`FREE_LIST_CTR_WIDTH-1:0]    counter_in;

    // output
    FREE_LIST_PACKET [`N-1:0]           pop_packet;
    PRN              [SIZE-1:0]         output_free_list;
    
    // debug output
    logic [`FREE_LIST_PTR_WIDTH-1:0] head_out, correct_head;
    logic [`FREE_LIST_PTR_WIDTH-1:0] tail_out, correct_tail;
    logic [`FREE_LIST_CTR_WIDTH-1:0] counter_out, correct_counter;
    logic [`FREE_LIST_CTR_WIDTH-1:0] total_pop_cnt, total_push_cnt;

    free_list dut(
        .clock(clock),
        .reset(reset),
        .push_packet(push_packet),
        .pop_en(pop_en),
        .input_free_list(input_free_list),
        .rat_squash(rat_squash),
        .head_in(head_in),
        .tail_in(tail_in),
        .counter_in(counter_in),
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
            $display("pop_packet: idx %d: pop_en: %b, valid %b prn: %d\n", i, pop_en[i], pop_packet[i].valid, pop_packet[i].prn);
        end
    endtask

    task print_push_packet;
        $display("time: %4.0f\n", $time);
        for (int i = 0; i < `N; ++i) begin
            $display("push_packet: idx %d: valid %b prn: %d\n", i, push_packet[i].valid, push_packet[i].prn);
        end
    endtask

    task init;
        reset = 1;
        correct = 1;
        rat_squash = 0;
        
        correct_head = 0;
        correct_tail = 0;
        correct_counter = `PHYS_REG_SZ_R10K;

        for (int i = 0; i < `N; ++i) begin
            push_packet[i].valid = `FALSE;
            push_packet[i].prn   = 0;
            pop_en[i]            = `FALSE;
        end

        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            input_free_list[i] = i;
        end
        head_in = 0;
        tail_in = 0;
        counter_in = `PHYS_REG_SZ_R10K;

        @(negedge clock);
        reset = 0;
        correct = correct && head_out == `ARCH_REG_SZ && tail_out == 0 && counter_out == `PHYS_REG_SZ_R10K - `ARCH_REG_SZ;
        rat_squash = 1;
        @(negedge clock);
        rat_squash = 0;
    endtask
    
    task test_counter;
        parameter ITER = `PHYS_REG_SZ_R10K / `N;
        init();

        @(negedge clock);

        correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;
        @(negedge clock);
        @(negedge clock);

        pop_en = {`N{`TRUE}};

        for (int i = 0; i < ITER; ++i) begin
            #1;
            // print_pop_packet();
            for (int j = 0; j < `N; ++j) begin
                correct = correct && pop_packet[j].valid && pop_packet[j].prn == i * `N + j;
            end 
            @(negedge clock);
            correct_counter -= `N;
            correct_head = (correct_head + `N) % `PHYS_REG_SZ_R10K;
            correct_tail = correct_tail;
            correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;

            // print_entries_out();
            // print_pop_packet();
        end

        $display("time: %4.0f, first pop done\n", $time);
        
        @(negedge clock);
        correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;
        @(negedge clock);
        pop_en = {`N{`FALSE}};
        #1;

        for (int j = 0; j < `N; ++j) begin
            correct = correct && ~pop_packet[j].valid;
        end 

        for (int i = 0; i < ITER; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                push_packet[j].valid = `TRUE;
                push_packet[j].prn   = `PHYS_REG_SZ_R10K - 1 - (i * `N + j);
            end

            @(negedge clock);
            correct_counter += `N;
            correct_head = correct_head;
            correct_tail = (correct_tail + `N) % `PHYS_REG_SZ_R10K;
            correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;
            // print_entries_out();
            // print_pop_packet();
        end

        @(negedge clock);

        pop_en = {`N{`TRUE}};
        #1;
        for (int j = 0; j < `N; ++j) begin
            push_packet[j].valid = `FALSE;
        end

        for (int i = 0; i < ITER; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                correct = correct && pop_packet[j].valid && pop_packet[j].prn == `PHYS_REG_SZ_R10K - 1 - (i * `N + j);
            end
            @(negedge clock);
            correct_counter -= `N;
            correct_head = (correct_head + `N) % `PHYS_REG_SZ_R10K;
            correct_tail = correct_tail;
            correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;

            // print_entries_out();
            // print_pop_packet();
        end

        $display("@@@ Passed test_counter");
    endtask

    task test_random_push_pop;
        parameter ITER = `PHYS_REG_SZ_R10K / `N;
        init();
        total_pop_cnt = 0;
        total_push_cnt = 0;
        
        for (int i = 0; i < ITER; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                if ($random % 2) begin
                    pop_en[j] = `TRUE;
                    total_pop_cnt += 1;
                end else begin
                    pop_en[j] = `FALSE;
                end
            end
            
            @(negedge clock);
            correct_counter = `PHYS_REG_SZ_R10K - total_pop_cnt;
            correct_head = total_pop_cnt;
            correct_tail = correct_tail;
            correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;

            // print_entries_out();
            // print_pop_packet();
        end

        pop_en = {`N{`FALSE}};
        @(negedge clock); 
        $display("time: %4.0f, pass pop\n", $time); // 260
        // print_entries_out();
        // print_pop_packet();
    
        

        for (int i = 0; i < ITER; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                if ($random % 2 && total_push_cnt < total_pop_cnt) begin
                    push_packet[j].valid = `TRUE;
                    push_packet[j].prn   = total_push_cnt;
                    total_push_cnt += 1;
                end else begin
                    push_packet[j].valid = `FALSE;
                end
            end

            // print_push_packet();
            @(negedge clock);
            correct_counter = `PHYS_REG_SZ_R10K - total_pop_cnt + total_push_cnt;
            correct_head = correct_head;
            correct_tail = total_push_cnt;
            correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;
            $display("time: %4.0f, i: %d, correct: %b\n", $time, i, correct);
            // print_entries_out();
            // print_pop_packet();
        end
        
        $display("@@@ Passed test_random_push_pop");
    endtask

    task test_concurrent_random_push_pop;
        parameter ITER = 2 * `PHYS_REG_SZ_R10K / `N;
        init();
        total_pop_cnt = 0;
        total_push_cnt = 0;
        
        @(negedge clock);
        correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;

        for (int i = 0; i < ITER; ++i) begin
            for (int j = 0; j < `N; ++j) begin
                if ($random % 2) begin
                    pop_en[j] = `TRUE;
                    total_pop_cnt += 1;
                end else begin
                    pop_en[j] = `FALSE;
                end
            end

            #1;

            for (int j = 0; j < `N; ++j) begin
                if (pop_packet[j].valid) begin
                    push_packet[j].valid = `TRUE;
                    push_packet[j].prn   = pop_packet[j].prn;
                    total_push_cnt += 1;
                end else begin
                    push_packet[j].valid = `FALSE;
                end
            end  

            @(negedge clock);
            correct_counter = `PHYS_REG_SZ_R10K - total_pop_cnt + total_push_cnt;
            correct_head = total_pop_cnt % `PHYS_REG_SZ_R10K;
            correct_tail = total_push_cnt % `PHYS_REG_SZ_R10K;
            correct = correct && correct_counter == counter_out && head_out == correct_head && tail_out == correct_tail;

            // print_entries_out();
            // print_pop_packet();
        end
        
        $display("@@@ Passed test_concurrent_random_push_pop");
    endtask

    task test_squash;
        init();

        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            input_free_list[i] = `PHYS_REG_SZ_R10K - i - 1;
        end
        rat_squash = 1;
        
        head_in = $random % `PHYS_REG_SZ_R10K;
        counter_in = $random % `PHYS_REG_SZ_R10K;
        tail_in = (head_in + counter_in) % `PHYS_REG_SZ_R10K;

        @(negedge clock);
        rat_squash = 0;
        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            correct = correct && output_free_list[i] == input_free_list[i];
        end
        correct = correct && counter_out == counter_in;
        correct = correct && head_out == head_in;
        correct = correct && tail_out == tail_in;

        @(negedge clock);
        $display("@@@ Passed test_squash");
    endtask

    task test_init;
        reset = 1;
        correct = 1;
        rat_squash = 0;
        
        correct_head = 0;
        correct_tail = 0;
        correct_counter = `PHYS_REG_SZ_R10K;

        for (int i = 0; i < `N; ++i) begin
            push_packet[i].valid = `FALSE;
            push_packet[i].prn   = 0;
            pop_en[i]            = `FALSE;
        end

        for (int i = 0; i < `PHYS_REG_SZ_R10K; ++i) begin
            input_free_list[i] = i;
        end
        head_in = 0;
        tail_in = 0;
        counter_in = `PHYS_REG_SZ_R10K;

        @(negedge clock);
        reset = 0;

        for (int i = 0; i < `N; ++i) begin
            pop_en[i]            = `TRUE;
        end

        #1;

        print_entries_out();
        print_pop_packet();

    endtask



    initial begin
        clock = 0;

        test_init();

        test_counter();

        for (int i = 0; i < 10; ++i) begin
            test_random_push_pop();
        end
        
        for (int i = 0; i < 10; ++i) begin
            test_concurrent_random_push_pop();
        end
        
        for (int i = 0; i < 10; ++i) begin
            test_squash();
        end

        $display("@@@ Passed");
        $finish;
    end

endmodule
