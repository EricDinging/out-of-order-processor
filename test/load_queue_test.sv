`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module testbench;
    logic clock, reset, correct;

    RS_LQ_PACKET          [`NUM_FU_LOAD-1:0] rs_lq_packet;
    logic                 [`NUM_FU_LOAD-1:0] load_rs_avail;
    logic                 [`NUM_FU_LOAD-1:0] load_selected;
    logic                 [`NUM_FU_LOAD-1:0] load_prepared;
    FU_STATE_BASIC_PACKET [`NUM_FU_LOAD-1:0] load_packet;
    ADDR                  [`NUM_FU_LOAD-1:0] sq_add;
    logic                 [`NUM_FU_LOAD-1:0][`SQ_IDX_BITS-1:0] store_range;
    MEM_FUNC              [`NUM_FU_LOAD-1:0] load_byte_inf;
    DATA                  [`NUM_FU_LOAD-1:0] value;
    logic                 [`NUM_FU_LOAD-1:0] fwd_valid;
    logic                 [`NUM_FU_LOAD-1:0][3:0] forwarded;
    
    DCACHE_LQ_PACKET [`N-1:0]             dcache_lq_packet;
    logic            [`NUM_LU_DCACHE-1:0] load_req_accept;
    DATA             [`NUM_LU_DCACHE-1:0] load_req_data;
    logic            [`NUM_LU_DCACHE-1:0] load_req_data_valid;
    LQ_DCACHE_PACKET [`NUM_LU_DCACHE-1:0] lq_dcache_packet;    
    LD_ENTRY   [`NUM_FU_LOAD-1:0]      entries_out; 

    load_queue dut(
        .clock(clock),
        .reset(reset),
        .rs_lq_packet(rs_lq_packet),
        .load_rs_avail(load_rs_avail),
        .load_avail(load_selected),
        .load_prepared(load_prepared),
        .load_packet(load_packet),
        .sq_addr(sq_add),
        .store_range(store_range),
        .load_byte_info(load_byte_inf),
        .value(value),
        .fwd_valid(fwd_valid),
        .forwarded(forwarded),
        .dcache_lq_packet(dcache_lq_packet),
        .load_req_accept(load_req_accept),
        .load_req_data(load_req_data),
        .load_req_data_valid(load_req_data_valid),
        .lq_dcache_packet(lq_dcache_packet),
        .entries_out(entries_out)
    );
    
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task init;
        reset = 1;
        correct = 1;

        rs_lq_packet = 0;
        load_selected = 0;
        value = 0;
        fwd_valid = 0;
        dcache_lq_packet = 0;
        load_req_accept = 0;
        load_req_data = 0;
        load_req_data_valid = 0;
        
        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        @(negedge clock);
        
    endtask

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f, clock %b\n", $time, clock);
            $display("@@@ Failed load queue test!");
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (!correct) begin
            exit_on_error();
        end
    end

    task entering;
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            rs_lq_packet[i] = '{
                `TRUE,
                MEM_WORD,
                32'hdeadf000,
                12'hace,
                i,
                i,
                2
            };  
        end
        @(negedge clock);
        rs_lq_packet = 0;
        #(`CLOCK_PERIOD/5.0);
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            $display(
                "query_addr: %h, store_range:%d",
                sq_add[i],
                store_range[i]
            );
        end
        @(negedge clock);
        @(negedge clock);
        print;
        correct = load_rs_avail == 0;
        correct &= load_prepared == 0;
        for (int i = 0; i < `NUM_LU_DCACHE; i++) begin
            $display(
                "lq_dcache_packet[%2d].valid = %b, lq_idx = %d, addr = %h",
                i, lq_dcache_packet[i].valid, lq_dcache_packet[i].lq_idx, lq_dcache_packet[i].addr
            );
        end
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        
        print; // not accept, should stay no_forward
        // for (int i = 0; i < `NUM_FU_LOAD; i++) begin
        //     fwd_valid[i] = 1;
        //     value[i] = 32'hdeadbeef;
        // end
        for (int i = 0; i < `NUM_LU_DCACHE; i++) begin
            $display(
                "lq_dcache_packet[%2d].valid = %b, lq_idx = %d, addr = %h",
                i, lq_dcache_packet[i].valid, lq_dcache_packet[i].lq_idx, lq_dcache_packet[i].addr
            );
        end
    endtask

    task forward;
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            rs_lq_packet[i] = '{
                `TRUE,
                MEM_WORD,
                32'hdeadf000,
                12'hace,
                i,
                i,
                2
            };  
        end
        @(negedge clock);
        rs_lq_packet = 0;
        value[0] = 32'hfaceface;
        fwd_valid[0] = 0;
        forwarded = 4'b0100;
        @(negedge clock);
        @(negedge clock);
        print; // load_state[0] should be known
        dcache_lq_packet[0].valid = `TRUE;
        dcache_lq_packet[0].lq_idx = 0;
        dcache_lq_packet[0].data = 32'hdeadbeef;
        @(negedge clock);
        @(negedge clock);
        print;
    endtask

    task get_dcache;
        foreach (load_req_accept[i]) begin
            load_req_accept[i]     = `TRUE;
            load_req_data[i]       = 32'hB0BACAFE;
            load_req_data_valid[i] = i == 0;
        end
        dcache_lq_packet = 0;
        @(negedge clock);
        print;
        load_req_accept     = 0;
        load_req_data       = 0;
        load_req_data_valid = 0;
        @(negedge clock);
        print;
        dcache_lq_packet[0].valid  = `TRUE;
        dcache_lq_packet[0].lq_idx = 0;
        dcache_lq_packet[0].data   = 32'hCAFEB0BA;
        @(negedge clock);
        print;
    endtask

    task to_cdb;
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            rs_lq_packet[i] = '{
                `TRUE,
                MEM_WORD,
                32'hdeadf000,
                12'hace,
                i,
                i,
                2
            };  
        end
        @(negedge clock);
        rs_lq_packet = 0;
        

        // for (int i = 0; i < `NUM_FU_LOAD; i++) begin
        //     fwd_valid[i] = 1;
        //     value[i] = 32'hdeadbeef;
        // end
        fwd_valid[0] = 0;
        value[0] = 32'hdeadbeef;
        
        fwd_valid[1] = 1;
        value[1] = 32'hdeadbeef;
        
        @(negedge clock);
        @(negedge clock);
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            fwd_valid[i] = 0;
            value[i] = 32'hdeadbeef;
        end

        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            load_selected[i] = 1;
        end
        
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            $display("load_prepared[%2d] = %d, robn = %d, dest = %d",
                        i, load_prepared[i], load_packet[i].robn, load_packet[i].dest_prn);
        end
    endtask

    task print;
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            $display(
                "ld[%2d].valid = %b, addr = %h, data = %h, tail_store = %d, load_state = %d, forwarded = %b",
                i, entries_out[i].valid, entries_out[i].addr, entries_out[i].data,
                entries_out[i].tail_store, entries_out[i].load_state, entries_out[i].forwarded
            );
        end
    endtask

    initial begin
        clock = 0;
        // init; 
        // entering;
        // get_dcache;

        // init;
        // to_cdb;

        init;
        forward;
        $finish;
    end
endmodule
