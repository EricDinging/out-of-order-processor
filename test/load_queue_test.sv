`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module testbench;
    logic clock, reset, correct;

    RS_LQ_PACKET          [`NUM_FU_LOAD-1:0] rs_lq_packet;
    logic                 [`NUM_FU_LOAD-1:0] load_rs_avail;
    logic                 [`LU_LEN-1:0] load_avail;
    logic                 [`LU_LEN-1:0] load_prepared;
    FU_STATE_BASIC_PACKET [`LU_LEN-1:0] load_packet;
    ADDR                  [`NUM_FU_LOAD-1:0] sq_add;
    logic                 [`NUM_FU_LOAD-1:0][`SQ_IDX_BITS-1:0] store_range;
    MEM_FUNC              [`NUM_FU_LOAD-1:0] load_byte_inf;
    DATA                  [`NUM_FU_LOAD-1:0] value;
    logic                 [`NUM_FU_LOAD-1:0] fwd_valid;
    
    DCACHE_LQ_PACKET [`N-1:0]             dcache_lq_packet;
    logic            [`NUM_LU_DCACHE-1:0] load_req_accept;
    DATA             [`NUM_LU_DCACHE-1:0] load_req_data;
    logic            [`NUM_LU_DCACHE-1:0] load_req_data_valid;
    LQ_DCACHE_PACKET [`NUM_LU_DCACHE-1:0] lq_dcache_packet;     

    load_queue dut(
        .clock(clock),
        .reset(reset),
        .rs_lq_packet(rs_lq_packet),
        .load_rs_avail(load_rs_avail),
        .load_selected(load_avail),
        .load_prepared(load_prepared),
        .load_packet(load_packet),
        .sq_addr(sq_add),
        .store_range(store_range),
        .load_byte_info(load_byte_inf),
        .value(value),
        .fwd_valid(fwd_valid),
        .dcache_lq_packet(dcache_lq_packet),
        .load_req_accept(load_req_accept),
        .load_req_data(load_req_data),
        .load_req_data_valid(load_req_data_valid),
        .lq_dcache_packet(lq_dcache_packet)
    );
    
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task init;
        reset = 1;
        correct = 1;
        
        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        @(negedge clock);
        
    endtask

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f, clock %b\n", $time, clock);
            $display("@@@ Failed PRF test!");
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (!correct) begin
            exit_on_error();
        end
    end

    initial begin
        $display("PRF size %d\n", `PHYS_REG_SZ_R10K);
        clock = 0;
        init; 

        $finish;
    end
endmodule