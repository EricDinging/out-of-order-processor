`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module testbench;

    logic       clock;
    MEM_COMMAND proc2mem_command;
    ADDR        proc2mem_addr;
    MEM_BLOCK   proc2mem_data;
    MEM_TAG     mem2proc_transaction_tag;
    MEM_BLOCK   mem2proc_data;
    MEM_TAG     mem2proc_data_tag;
`ifndef CACHE_MODE
    MEM_SIZE    proc2mem_size;
`endif
`ifdef CPU_DEBUG_OUT
    logic [63:0] target_mem_block_debug;
`endif

    mem dut (
        // Inputs
        .clock            (clock),
        .proc2mem_command (proc2mem_command),
        .proc2mem_addr    (proc2mem_addr),
        .proc2mem_data    (proc2mem_data),
    `ifndef CACHE_MODE
        .proc2mem_size    (proc2mem_size),
    `endif

        // Outputs
        .mem2proc_transaction_tag (mem2proc_transaction_tag),
        .mem2proc_data            (mem2proc_data),
        .mem2proc_data_tag        (mem2proc_data_tag)
    `ifdef CPU_DEBUG_OUT
        , .target_mem_block_debug(target_mem_block_debug)
    `endif
    );

    always #(`CLOCK_PERIOD/2.0) clock = ~clock;

    initial begin
        clock = 0;

        proc2mem_command = MEM_NONE;
        proc2mem_addr    = 0;
        proc2mem_data    = 0;

        for (int i = 0; i < 16; ++i) begin
            @(negedge clock);
            proc2mem_command = MEM_STORE;
            proc2mem_addr    = i << 8;
            proc2mem_data    = i;
            @(negedge clock);
            proc2mem_command = MEM_LOAD;
            proc2mem_addr    = i << 8;
            proc2mem_data    = 0;
        end

        for (int i = 0; i < 16; ++i) begin
            @(negedge clock);
            proc2mem_command = MEM_LOAD;
            proc2mem_addr    = i << 8;
            proc2mem_data    = 0;
        end

        @(negedge clock);
        proc2mem_command = MEM_NONE;

        for (int i = 0; i < 20; ++i) @(negedge clock);
        $finish;
    end

endmodule
