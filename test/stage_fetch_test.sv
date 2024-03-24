
`include "sys_defs.svh"
`include "ISA.svh"

module testbench;

    logic correct;
    logic clock, reset, stall;

    MEM_TAG   transaction_tag;
    MEM_BLOCK data;
    MEM_TAG   data_tag;

    ROB_IF_PACKET rob_if_packet;

    MEM_COMMAND  command;
    ADDR         addr;

    IF_ID_PACKET [`N-1:0] if_id_packet;

    stage_fetch dut(
        .clock(clock), .reset(reset), .stall(stall),

        .mem2proc_transaction_tag (transaction_tag),
        .mem2proc_data            (data),
        .mem2proc_data_tag        (data_tag),

        .rob_if_packet(rob_if_packet),

        .proc2Imem_command (command),
        .proc2Imem_addr    (addr),

        .if_id_packet(if_id_packet)
    );

    mem memory(
        .clock(clock),

        .proc2mem_addr    (addr),
        .proc2mem_data    (64'h0),
`ifndef CACHE_MODE
        .proc2mem_size    (DOUBLE),
`endif
        .proc2mem_command (command),

        .mem2proc_transaction_tag (transaction_tag),
        .mem2proc_data            (data),
        .mem2proc_data_tag        (data_tag)
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task init;
        correct = 1;
        reset = 1;
        stall = 0;
        rob_if_packet = 0;
        @(negedge clock);
        reset = 0;
        @(negedge clock);
    endtask

    initial begin
        init;
        $finish;
    end

endmodule
