`include "sys_defs.svh"

module stage_fetch (
    input clock, reset,
    input logic stall,
    input logic squash,
    input logic dcache_request,
    // From memory
    input MEM_TAG   mem2proc_transaction_tag, // Memory tag for current transaction
    input MEM_BLOCK mem2proc_data,            // Data coming back from memory
    input MEM_TAG   mem2proc_data_tag,        // Tag for which transaction data is for

    // From ROB
    input  ROB_IF_PACKET rob_if_packet,

    output MEM_COMMAND  proc2Imem_command,
    output ADDR         proc2Imem_addr,
    output IF_ID_PACKET [`N-1:0] if_id_packet
`ifdef CPU_DEBUG_OUT
    , output IMSHR_ENTRY [`N-1:0] imshr_entries_debug
    // From predictor
    , output BTB_ENTRY [`BTB_SIZE-1:0] btb_entries_debug
    , output logic [`BHT_SIZE-1:0][`BHT_WIDTH-1:0] branch_history_table_debug
    , output PHT_ENTRY_STATE [`PHT_SIZE-1:0] pattern_history_table_debug
`endif
);

    // state
    ADDR pc_start, next_pc_start;
    
    
    // PC_ENTRY [`N:0]   pc; // pc[`N] equals to pc[0] in the next cycle
    PC_ENTRY [`N-1:0] target_pc;
    logic    [`N-1:0] predict_taken;

    // icache input
    ADDR  [`N-1:0] proc2Icache_addr;
    logic [`N-1:0] proc2Icache_valid;

    // icache output
    MEM_BLOCK [`N-1:0] Icache_data_out;
    logic     [`N-1:0] Icache_valid_out;

    logic has_invalid_icache_out;

    // prefetch
    logic pref_hit_valid_line;
    logic pref2Icache_valid;
    ADDR pref2Icache_addr;

    tournament_predictor bp (
        .clock(clock),
        .reset(reset),
        .pc_start(pc_start),
        .rob_if_packet(rob_if_packet),
        // output
        .target_pc(target_pc)
    `ifdef CPU_DEBUG_OUT
    `endif
    );

    icache ic (
        .clock(clock),
        .reset(reset),
        .squash(squash),
        .Imem2proc_transaction_tag(mem2proc_transaction_tag),
        .Imem2proc_data(mem2proc_data),
        .Imem2proc_data_tag(mem2proc_data_tag),
        .proc2Icache_addr(proc2Icache_addr),
        .valid(proc2Icache_valid),
        .dcache_request(dcache_request),
        .pref2Icache_addr(pref2Icache_addr),
        .pref2Icache_valid(pref2Icache_valid),
        .proc2Imem_command(proc2Imem_command),
        .proc2Imem_addr(proc2Imem_addr),
        .Icache_data_out(Icache_data_out),
        .Icache_valid_out(Icache_valid_out),
        .pref_hit_valid_line(pref_hit_valid_line)
    `ifdef CPU_DEBUG_OUT
        , .imshr_entries_debug(imshr_entries_debug)
    `endif
    );

    prefetcher pref (
        .clock(clock),
        .reset(reset || squash),
        .next_pc_start(next_pc_start),
        .hit_valid_line(pref_hit_valid_line),
        //output
        .pref2Icache_addr(pref2Icache_addr),
        .pref2Icache_valid(pref2Icache_valid)
    );

    always_comb begin
        next_pc_start = pc_start;
        has_invalid_icache_out = 0;
        if_id_packet = 0;
        for (int i = 0; i < `N; ++i) begin
            proc2Icache_valid[i] = target_pc[i].valid;
        end

        for (int i = 0; i < `N; ++i) begin
            if (Icache_valid_out[i]) begin
                next_pc_start = target_pc[i].PC;
            end else begin
                break;
            end
        end

        for (int i = 0; i < `N; ++i) begin
            if (!rob_if_packet.entries[i].success) begin
                next_pc_start     = rob_if_packet.entries[i].resolve_target;
                proc2Icache_valid = {`N{`FALSE}};
            end
        end

        proc2Icache_addr[0] = pc_start;
        if_id_packet[0].PC  = pc_start;

        for (int i = 1; i < `N; ++i) begin
            proc2Icache_addr[i] = target_pc[i-1].PC;
            if_id_packet[i].PC  = target_pc[i-1].PC;
        end

        for (int i = 0; i < `N; ++i) begin
            if (~has_invalid_icache_out) begin
                if_id_packet[i].valid = target_pc[i].valid && Icache_valid_out[i] && proc2Icache_valid[i];
                if_id_packet[i].inst  =
                    !if_id_packet[i].valid ? `NOP :
                    if_id_packet[i].PC[2]  ? Icache_data_out[i][63:32] : Icache_data_out[i][31:0];

                if_id_packet[i].NPC            = if_id_packet[i].PC + 4;
                if_id_packet[i].predict_taken  = target_pc[i].taken;
                if_id_packet[i].predict_target = target_pc[i].PC;
                has_invalid_icache_out = ~if_id_packet[i].valid;
            end
        end

        if (stall) begin
            next_pc_start = pc_start;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            pc_start <= 32'b0;
        end else begin
            pc_start <= next_pc_start;
        end
    end

endmodule
