`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module testbench;
    
    logic clock, reset, correct;
    logic [31:0] clock_cycle;
    logic squash;
    // From memory
    MEM_TAG   Dmem2proc_transaction_tag;
    MEM_BLOCK Dmem2proc_data;
    MEM_TAG   Dmem2proc_data_tag;
    // From LSQ
    LQ_DCACHE_PACKET [`N-1:0] lq_dcache_packet;
    SQ_DCACHE_PACKET [`N-1:0] sq_dcache_packet;
    // To memory
    MEM_COMMAND proc2Dmem_command, correct_proc2Dmem_command;
    ADDR        proc2Dmem_addr, correct_proc2Dmem_addr;
    MEM_BLOCK   proc2Dmem_data, correct_proc2Dmem_data;
    // To LSQ current result
    logic      [`N-1:0] store_req_accept, correct_store_req_accept;
    logic      [`N-1:0] load_req_accept, correct_load_req_accept;
    DATA       [`N-1:0] load_req_data, correct_load_req_data;
    logic      [`N-1:0] load_req_data_valid, correct_load_req_data_valid;
    // To LSQ future result
    DCACHE_LQ_PACKET [`N-1:0] dcache_lq_packet, correct_dcache_lq_packet;
    // To Icache
    logic dcache_request, correct_dcache_request;
    // debug
    DMSHR_ENTRY [7:0] dmshr_entries_debug;
    DCACHE_ENTRY [`DCACHE_LINES-1:0] dcache_data_debug;

    dcache dut(
        .clock(clock),
        .reset(reset),
        .squash(squash),
        // mem to dcache
        .Dmem2proc_transaction_tag(Dmem2proc_transaction_tag),
        .Dmem2proc_data(Dmem2proc_data),
        .Dmem2proc_data_tag(Dmem2proc_data_tag),
        // from lsq
        .lq_dcache_packet(lq_dcache_packet),
        .sq_dcache_packet(sq_dcache_packet),
        // output to memory
        .proc2Dmem_command(proc2Dmem_command),
        .proc2Dmem_addr(proc2Dmem_addr),
        .proc2Dmem_data(proc2Dmem_data),
        // output to lsq
        .store_req_accept(store_req_accept),
        .load_req_accept(load_req_accept),
        .load_req_data(load_req_data),
        .load_req_data_valid(load_req_data_valid),
        .dcache_lq_packet(dcache_lq_packet),
        // output to icache
        .dcache_request(dcache_request)
    `ifdef CPU_DEBUG_OUT
        ,.dmshr_entries_debug(dmshr_entries_debug)
        ,.dcache_data_debug(dcache_data_debug)
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
            print_ld_packet();
            print_mem_cmd();
            print_current_req_resp();
            // print_dmshr_entries_debug();
            // print_dcache_data_debug();
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (~correct) begin
            exit_on_error();
        end
    end

    task print_dcache_data_debug;
        begin
            $display("========================= clock_cycle = %0d ============================", clock_cycle);
            for (int i = 0; i < `DCACHE_LINES; i++) begin
                $display("dcache_data_debug[%0d].valid = %b", i, dcache_data_debug[i].valid);
                $display("dcache_data_debug[%0d].dirty = %b", i, dcache_data_debug[i].dirty);
                $display("dcache_data_debug[%0d].tag = %h", i, dcache_data_debug[i].tag);
                $display("dcache_data_debug[%0d].data = %h", i, dcache_data_debug[i].data);
            end
        end
    endtask

    task print_dmshr_entries_debug;
        begin
            $display("========================= clock_cycle = %0d ============================", clock_cycle);
            for (int i = 0; i < 8; i++) begin
                $display("dmshr_entries_debug[%0d].tag = %h", i, dmshr_entries_debug[i].tag);
                $display("dmshr_entries_debug[%0d].index = %h", i, dmshr_entries_debug[i].index);
                $display("dmshr_entries_debug[%0d].transaction_tag = %d", i, dmshr_entries_debug[i].transaction_tag);
                case (dmshr_entries_debug[i].state)
                    DMSHR_INVALID: 
                        $display("dmshr_entries_debug[%2d]: DMSHR_INVALID", i);
                    DMSHR_PENDING: 
                        $display("dmshr_entries_debug[%2d]: DMSHR_PENDING", i);
                    DMSHR_WAIT_TAG: 
                        $display("dmshr_entries_debug[%2d]: DMSHR_WAIT_TAG", i);
                    DMSHR_WAIT_DATA: 
                        $display("dmshr_entries_debug[%2d]: DMSHR_WAIT_DATA", i);
                    default:
                        $display("Invalid state");
                endcase
            end
        end
    endtask

    task print_current_req_resp;
        begin
            $display("========================= clock_cycle = %0d ============================", clock_cycle);
            for (int i = 0; i < `N; i++) begin
                $display("store_req_accept[%0d] = %b", i, store_req_accept[i]);
            end
            for (int i = 0; i < `N; i++) begin
                $display("load_req_accept[%0d] = %b", i, load_req_accept[i]);
                $display("load_req_data_valid[%0d] = %b", i, load_req_data_valid[i]);
                $display("load_req_data[%0d] = %h", i, load_req_data[i]);
            end
        end
    endtask

    task print_ld_packet;
        begin
            $display("========================= clock_cycle = %0d ============================", clock_cycle);
            for (int i = 0; i < `N; i++) begin
                $display("dcache_lq_packet[%0d].valid = %b", i, dcache_lq_packet[i].valid);
                $display("dcache_lq_packet[%0d].lq_idx = %d", i, dcache_lq_packet[i].lq_idx);
                $display("dcache_lq_packet[%0d].data = %h", i, dcache_lq_packet[i].data);
            end
        end
    endtask

    task print_mem_cmd;
        begin
            $display("========================= clock_cycle = %0d ============================", clock_cycle);
            $display("dcache_request = %b", dcache_request);
            case (proc2Dmem_command)
                MEM_NONE:  $display("proc2Dmem_command = MEM_NONE");
                MEM_LOAD:  $display("proc2Dmem_command = MEM_LOAD");
                MEM_STORE: $display("proc2Dmem_command = MEM_STORE");
            endcase
            $display("proc2Dmem_addr = %h", proc2Dmem_addr);
            $display("proc2Dmem_data = %h", proc2Dmem_data);
        end
    endtask

    task init;
        reset   = 1;
        correct = 1;
        squash  = 0;
        lq_dcache_packet = 0;
        sq_dcache_packet = 0;
        Dmem2proc_data   = 0;
        Dmem2proc_data_tag        = 0;
        Dmem2proc_transaction_tag = 0;
        correct_store_req_accept = 0;
        correct_load_req_accept  = 0;
        correct_load_req_data    = 0;
        correct_load_req_data_valid = 0;
        correct_dcache_lq_packet = 0;

        @(negedge clock);
        reset = 0;
        @(negedge clock);
    endtask

    task test_cache_miss;
        init();

        lq_dcache_packet[0] = '{
            `TRUE,
            {(`LOAD_Q_INDEX_WIDTH){4}}, // lq_idx
            {(32){8}},  // addr
            MEM_WORD    // mem_func
        };

        #(`CLOCK_PERIOD/5);
        correct_load_req_accept[0] = `TRUE;
        correct = correct && (load_req_accept == correct_load_req_accept);

        @(negedge clock);
        print_dmshr_entries_debug();
        lq_dcache_packet[0] = 0;
        correct_proc2Dmem_command = MEM_LOAD;
        correct_proc2Dmem_addr    = 8;
        correct_dcache_request    = `TRUE;
        correct = correct && (proc2Dmem_command == correct_proc2Dmem_command) && (proc2Dmem_addr == correct_proc2Dmem_addr) && (dcache_request == correct_dcache_request);

        Dmem2proc_transaction_tag = 1;

        for (int i = 0; i < 3; ++i) begin
            @(negedge clock);
            print_dmshr_entries_debug();
            Dmem2proc_transaction_tag = 0;
            correct_proc2Dmem_command = MEM_NONE;
            correct_dcache_request    = `FALSE;
            correct = correct && (proc2Dmem_command == correct_proc2Dmem_command) && (dcache_request == correct_dcache_request);
        end

        Dmem2proc_data_tag = 1;
        Dmem2proc_data = 1;
        
        #(`CLOCK_PERIOD/4);
        print_dmshr_entries_debug();
        Dmem2proc_data_tag = 0;
        correct_dcache_lq_packet[0] = '{
            `TRUE,
            {(`LOAD_Q_INDEX_WIDTH){4}},
            1
        };
        correct = correct && (dcache_lq_packet[0].data === 1);
        correct = correct && dcache_lq_packet[0].valid;
        print_ld_packet();
        print_dcache_data_debug();

        @(negedge clock);

        $display("@@@ Passed test_cache_miss");
    endtask

    task test_store_load;
        init();

        sq_dcache_packet[0] = '{
            `TRUE,
            {(32){8}},  // addr
            MEM_WORD,   // mem_func
            {(32){32'h12345678}}
        };

        #(`CLOCK_PERIOD/5);
        correct_store_req_accept[0] = `TRUE;
        correct = correct && (store_req_accept == correct_store_req_accept);

        @(negedge clock);
        $display("check store allocation");
        // print_dmshr_entries_debug();
        sq_dcache_packet[0] = 0;
        correct_proc2Dmem_command = MEM_LOAD;
        correct_proc2Dmem_addr    = 8;
        correct_dcache_request    = `TRUE;
        correct = correct && (proc2Dmem_command == correct_proc2Dmem_command) && (proc2Dmem_addr == correct_proc2Dmem_addr) && (dcache_request == correct_dcache_request);

        Dmem2proc_transaction_tag = 1;

        for (int i = 0; i < 3; ++i) begin
            @(negedge clock);
            // print_dmshr_entries_debug();
            Dmem2proc_transaction_tag = 0;
            correct_proc2Dmem_command = MEM_NONE;
            correct_dcache_request    = `FALSE;
            correct = correct && (proc2Dmem_command == correct_proc2Dmem_command) && (dcache_request == correct_dcache_request);
        end

        Dmem2proc_data_tag = 1;
        Dmem2proc_data = 1;
        
        #(`CLOCK_PERIOD/4);
        // print_dmshr_entries_debug();
        // print_dcache_data_debug();
        $display("check first load");
        lq_dcache_packet[0] = '{
            `TRUE,
            {(`LOAD_Q_INDEX_WIDTH){4}}, // lq_idx
            {(32){8}},  // addr
            MEM_WORD    // mem_func
        };

        #(`CLOCK_PERIOD/5);
        correct_load_req_accept[0] = `TRUE;
        correct_load_req_data_valid[0] = `TRUE;
        correct_load_req_data[0] = 32'h12345678;
        correct = correct && (load_req_accept == correct_load_req_accept) && (correct_load_req_data_valid == load_req_data) && (load_req_data == correct_load_req_data);

        @(negedge clock);
        Dmem2proc_data_tag = 0;

        lq_dcache_packet[0] = '{
            `TRUE,
            {(`LOAD_Q_INDEX_WIDTH){1}}, // lq_idx
            {(32){10}},  // addr
            MEM_HALF    // mem_func
        };

        #(`CLOCK_PERIOD/5);
        $display("check second load");
        correct_load_req_accept[0] = `TRUE;
        correct_load_req_data_valid[0] = `TRUE;
        correct_load_req_data[0] = 16'h1234;
        correct = correct && (load_req_accept == correct_load_req_accept) && (correct_load_req_data_valid == load_req_data) && (load_req_data == correct_load_req_data);
        
        $display("@@@ Passed test_store_load");
    endtask

    initial begin
        clock = 0;
        clock_cycle = 0;

        // test_cache_miss();
        test_store_load();

        $display("@@@ Passed");
        $finish;
    end

endmodule