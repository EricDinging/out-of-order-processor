`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module testbench;

    logic clock, reset, correct;
    logic [31:0] clock_cycle;
    logic squash;
    // From memory
    MEM_TAG   Imem2proc_transaction_tag;
    MEM_BLOCK Imem2proc_data;
    MEM_TAG   Imem2proc_data_tag;
    // From fetch stage
    ADDR [`N-1:0] proc2Icache_addr;
    logic [`N-1:0] valid;

    logic dcache_request;
    // To memory
    MEM_COMMAND proc2Imem_command, correct_proc2Imem_command;
    ADDR        proc2Imem_addr, correct_proc2Imem_addr;
    // To fetch stage
    MEM_BLOCK [`N-1:0] Icache_data_out, correct_Icache_data_out;
    logic     [`N-1:0] Icache_valid_out, correct_Icache_valid_out;
    IMSHR_ENTRY [`N-1:0] imshr_entries_debug, correct_imshr_entries_debug;

    ADDR moving_addr;

    icache dut(
        .clock(clock),
        .reset(reset),
        .squash(squash),
        .Imem2proc_transaction_tag(Imem2proc_transaction_tag),
        .Imem2proc_data(Imem2proc_data),
        .Imem2proc_data_tag(Imem2proc_data_tag),
        .proc2Icache_addr(proc2Icache_addr),
        .valid(valid),
        .dcache_request(dcache_request),
        // output
        .proc2Imem_command(proc2Imem_command),
        .proc2Imem_addr(proc2Imem_addr),
        .Icache_data_out(Icache_data_out),
        .Icache_valid_out(Icache_valid_out)
    `ifdef CPU_DEBUG_OUT
        , .imshr_entries_debug(imshr_entries_debug)
    `endif
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
        if (clock && ~reset) begin
            clock_cycle += 1;
        end
    end

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Failed ENDING TESTBENCH : ERROR !");
            print_icache_output();
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (~correct) begin
            exit_on_error();
        end
    end

    task check_Icache_out;
        correct = correct && (Icache_valid_out === correct_Icache_valid_out);
        for (int i = 0; i < `N; i = i + 1) begin
            if (Icache_valid_out[i]) begin
                correct = correct && (Icache_data_out[i] === correct_Icache_data_out[i]);
            end
        end
    endtask

    task print_correct_Icache_out;
        $display("========= Clock: %2d =========", clock_cycle);
        for (int i = 0; i < `N; i = i + 1) begin
            if (correct_Icache_valid_out[i]) begin
                $display("correct_Icache_data_out[%2d]: %2d", i, correct_Icache_data_out[i]);
            end else begin
                $display("correct_Icache_data_out[%2d]: invalid", i, correct_Icache_data_out[i]);
            end
        end
    endtask

    task print_imshr_entries_debug;
    `ifdef CPU_DEBUG_OUT
        $display("========= Clock: %2d =========", clock_cycle);
        for (int i = 0; i < `N; i = i + 1) begin
            case (imshr_entries_debug[i].state)
                IMSHR_INVALID: 
                    $display("imshr_entries_debug[%2d]: IMSHR_INVALID", i);
                IMSHR_PENDING: 
                    $display("imshr_entries_debug[%2d]: IMSHR_PENDING", i);
                IMSHR_WAIT_TAG: 
                    $display("imshr_entries_debug[%2d]: IMSHR_WAIT_TAG", i);
                IMSHR_WAIT_DATA: 
                    $display("imshr_entries_debug[%2d]: IMSHR_WAIT_DATA", i);
                default:
                    $display("Invalid state");
            endcase
            $display("tag: %2d; index: %2d", imshr_entries_debug[i].tag, imshr_entries_debug[i].index);
            $display("transaction_tag: %2d", imshr_entries_debug[i].transaction_tag);
        end
    `endif

    endtask

    task print_icache_output;
        $display("========= Clock: %2d =========", clock_cycle);
        if (proc2Imem_command == MEM_NONE) begin
            $display("proc2Imem_command: MEM_NONE");
        end else if (proc2Imem_command == MEM_LOAD) begin
            $display("proc2Imem_command: MEM_LOAD");
            $display("proc2Imem_addr: %2d", proc2Imem_addr);
        end
        for (int i = 0; i < `N; i = i + 1) begin
            if (Icache_valid_out[i]) begin
                $display("Icache_data_out[%2d]: %2d", i, Icache_data_out[i]);
            end else begin
                $display("Icache_data_out[%2d]: invalid", i, Icache_data_out[i]);
            end
        end
    endtask

    task init;
        reset   = 1;
        correct = 1;

        squash  = 0;
        Imem2proc_transaction_tag = 0;
        Imem2proc_data            = 0;
        Imem2proc_data_tag        = 0;

        proc2Icache_addr = 0;
        valid            = {`N{`FALSE}};
        dcache_request   = 0;
        correct_Icache_data_out = 0;
        correct_Icache_valid_out = {`N{`FALSE}};
        moving_addr = 0;

        @(negedge clock);
        reset = 0;
        @(negedge clock);
    endtask

    task test_cache_miss;
        init();
        proc2Icache_addr = 0;
        valid[0]         = `TRUE;
        
        #(`CLOCK_PERIOD/5);

        correct_proc2Imem_command = MEM_NONE;
        correct_Icache_valid_out  = {`N{`FALSE}};
        correct = correct && (proc2Imem_command == correct_proc2Imem_command) && (Icache_valid_out == correct_Icache_valid_out);
        print_icache_output();

        @(negedge clock);
        // print_icache_output();
        correct_proc2Imem_command = MEM_LOAD;
        correct_proc2Imem_addr    = 0;
        correct = correct && (proc2Imem_command == correct_proc2Imem_command)
              && (proc2Imem_addr == correct_proc2Imem_addr)
              && (Icache_valid_out == correct_Icache_valid_out);

        // @(negedge clock);
        print_icache_output();
        Imem2proc_transaction_tag = 1;
        correct_Icache_valid_out  = {`N{`FALSE}};
        correct = correct && (proc2Imem_command == correct_proc2Imem_command) && (Icache_valid_out == correct_Icache_valid_out);
        correct_proc2Imem_command = MEM_NONE;

        for (int i = 0; i < 10; ++i) begin
            @(negedge clock);
            print_icache_output();
            Imem2proc_transaction_tag = 0;
            correct = correct && (proc2Imem_command == correct_proc2Imem_command) && (Icache_valid_out == correct_Icache_valid_out);
        end
        Imem2proc_data_tag = 1;
        Imem2proc_data     = 114514;
        correct = correct && (proc2Imem_command == correct_proc2Imem_command) && (Icache_valid_out == correct_Icache_valid_out);

        @(negedge clock);
        correct_Icache_valid_out[0] = `TRUE;
        correct_Icache_data_out[0] = 114514;
        correct = correct && (Icache_data_out === correct_Icache_data_out) && (Icache_valid_out === correct_Icache_valid_out);
        print_icache_output();

        @(negedge clock);
        proc2Icache_addr[0] = 1;
        valid[0]           = `TRUE;
        #1;
        correct_Icache_valid_out[0] = `TRUE;
        correct_Icache_data_out[0] = 114514;
        correct_proc2Imem_command = MEM_NONE;
        correct = correct && (proc2Imem_command == correct_proc2Imem_command) && (Icache_valid_out == correct_Icache_valid_out) && (Icache_data_out === correct_Icache_data_out);
        print_icache_output();
        
        $display("@@@ Passed test_cache_miss");
    endtask
    
    task test_non_blocking;
        init();

        for (int i = 0; i < `N; ++i) begin
            proc2Icache_addr[i] = i * 8; // 8 is block size
            valid[i]            = `TRUE;
        end

        #(`CLOCK_PERIOD/5);
        correct_proc2Imem_command = MEM_NONE;
        correct_Icache_valid_out  = {`N{`FALSE}};
        correct = correct && (proc2Imem_command == correct_proc2Imem_command) && (Icache_valid_out == correct_Icache_valid_out);
        print_icache_output();

        for (int i = 0; i < `N; ++i) begin
            @(negedge clock);
            correct_proc2Imem_command = MEM_LOAD;
            correct = correct && (proc2Imem_command == correct_proc2Imem_command) && (Icache_valid_out == correct_Icache_valid_out);
            Imem2proc_transaction_tag = i + 1;
        
            print_imshr_entries_debug();
            print_icache_output();
        end
        
        // @(negedge clock);
        // Imem2proc_transaction_tag = `N;
        correct_proc2Imem_command = MEM_NONE;

        @(negedge clock);
        print_imshr_entries_debug();
        Imem2proc_transaction_tag = 0;
        
        Imem2proc_data_tag = 1;
        Imem2proc_data     = 0;
        for (int i = 0; i < `N; ++i) begin
            correct_Icache_data_out[i] = i * 100;
        end
        for (int i = 0; i < `N; ++i) begin
            @(negedge clock);
            Imem2proc_data     = (i + 1) * 100;
            Imem2proc_data_tag = i + 2;

            correct_Icache_valid_out[i] = `TRUE;
            // correct_Icache_data_out[i] = i * 100;
            print_imshr_entries_debug();
            // print_correct_Icache_out();
            print_icache_output();
            // check_Icache_out();
        end

        $display("@@@ Passed test_non_blocking");
    endtask

    task test_sequential_load;
        init();
        for (int i = 0; i < `N; ++i) begin
            proc2Icache_addr[i] = i * 4;
            valid[i]            = `TRUE;
        end

        #(`CLOCK_PERIOD/5);
        correct_proc2Imem_command = MEM_NONE;
        correct_Icache_valid_out  = {`N{`FALSE}};
        correct = correct && (proc2Imem_command == correct_proc2Imem_command) && (Icache_valid_out == correct_Icache_valid_out);
        print_icache_output();

        for (int i = 0; i < (`N+1)/2; ++i) begin
            @(negedge clock);
            correct_proc2Imem_command = MEM_LOAD;
            correct = correct && (proc2Imem_command == correct_proc2Imem_command) && (Icache_valid_out == correct_Icache_valid_out);
            Imem2proc_transaction_tag = i + 1;

            print_imshr_entries_debug();
            print_icache_output();
        end
        
        // @(negedge clock);
        // Imem2proc_transaction_tag = (`N+1)/2;
        correct_proc2Imem_command = MEM_NONE;

        @(negedge clock);
        print_imshr_entries_debug();
        Imem2proc_transaction_tag = 0;
        
        Imem2proc_data_tag = 1;
        Imem2proc_data     = 50;
        for (int i = 0; i < (`N+1)/2; ++i) begin
            @(negedge clock);
            Imem2proc_data     = (i + 2) * 50;
            Imem2proc_data_tag = i + 2;

            // correct_Icache_valid_out[i] = `TRUE;
            // correct_Icache_data_out[i] = i * 100;
            print_imshr_entries_debug();
            // print_correct_Icache_out();
            print_icache_output();
            // check_Icache_out();
        end
        @(negedge clock);

        for (int i = 0; i < `N; ++i) begin
            correct = correct && Icache_valid_out[i];
        end

        $display("@@@ Passed test_sequential_load");
    endtask

    task load_n_inst;
        for (int i = 0; i < `N; ++i) begin
            proc2Icache_addr[i] = moving_addr;
            moving_addr         += 4;
            valid[i]            = `TRUE;
        end

        for (int i = 0; i < (`N+1)/2; ++i) begin
            @(negedge clock);
            Imem2proc_transaction_tag = i + 1;

            // print_imshr_entries_debug();
            // print_icache_output();
        end
        
        // @(negedge clock);
        // Imem2proc_transaction_tag = (`N+1)/2;

        @(negedge clock);
        Imem2proc_transaction_tag = 0;
        
        Imem2proc_data_tag = 1;
        Imem2proc_data     += 4;
        for (int i = 0; i < (`N+1)/2; ++i) begin
            @(negedge clock);
            Imem2proc_data += 4;
            Imem2proc_data_tag = i + 2;
        end
        @(negedge clock); 
        Imem2proc_data_tag = 0;
    endtask;

    task test_evict;
        init();
        for (int i = 0; i < 64/`N; ++i) begin
            @(negedge clock);
            load_n_inst();
        end

        @(negedge clock);
        $display("=========CLOCK : %2d, finish filling ========", clock_cycle);
        correct_Icache_valid_out = {`N{`FALSE}};
        print_imshr_entries_debug();

        valid = {`N{`FALSE}};
        valid[0] = `TRUE;
        proc2Icache_addr[0] = moving_addr;

        @(negedge clock);
        correct_proc2Imem_command = MEM_LOAD;
        correct_proc2Imem_addr = moving_addr;
        $display("moving_addr: %d", moving_addr);
        correct = correct && correct_proc2Imem_command === proc2Imem_command && correct_proc2Imem_addr === proc2Imem_addr;
        print_imshr_entries_debug();

        // @(negedge clock);
        Imem2proc_transaction_tag = 1;
        correct_proc2Imem_command = MEM_NONE;

        for(int i = 0; i < 10; i++) begin
            @(negedge clock);
            Imem2proc_transaction_tag = 0;
        end
        print_imshr_entries_debug();
        
        
        Imem2proc_data_tag = 1;
        Imem2proc_data = 123456;
        
        @(negedge clock);
        Imem2proc_data_tag = 0;
        correct_Icache_data_out[0] = 123456;
        correct_Icache_valid_out[0] = `TRUE;
        print_imshr_entries_debug();
        check_Icache_out();
        
        @(negedge clock);
        valid[0] = `TRUE;
        proc2Icache_addr[0] = 0;
        #1;
        correct_Icache_valid_out[0] = `FALSE;
        check_Icache_out();

        $display("@@@ Passed test_evict");
    endtask

    initial begin
        clock = 0;
        clock_cycle = 0;

        test_cache_miss();
        test_non_blocking();
        test_sequential_load();
        test_evict();

        $display("@@@ Passed");
        $finish;
    end

endmodule
