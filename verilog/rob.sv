`include "sys_defs.svh"
`define DEBUG_OUT

module rob #(
    parameter SIZE = `ROB_SZ,
    parameter ALERT_DEPTH = `N
)(
    input clock, reset,
    
    input ROB_IS_PACKET rob_is_packet,

    input FU_ROB_PACKET [`CDB_SZ-1:0] fu_rob_packet,

    output logic         almost_full,
    output ROB_CT_PACKET rob_ct_packet, 
    output ROBN [`N-1:0] tail_entries,
    output logic         squash
    `ifdef DEBUG_OUT
    , output ROB_ENTRY [SIZE-1:0]           entries_out
    , output logic     [`RS_CNT_WIDTH-1:0]  counter_out
    , output logic     [`ROB_CNT_WIDTH-1:0] head_out
    , output logic     [`ROB_CNT_WIDTH-1:0] tail_out
    `endif
);

    logic [`ROB_CNT_WIDTH-1:0] counter, next_counter;
    logic [`ROB_CNT_WIDTH-1:0] head, next_head;
    logic [`ROB_CNT_WIDTH-1:0] tail, next_tail;

    ROB_ENTRY [SIZE-1:0] rob_entries, next_rob_entries;

    always_comb begin
        next_head = head;
        next_tail = tail;
        next_counter = counter;
        next_rob_entries = rob_entries;
        squash = 0;

        // Commit
        for (int i = 0; i < `N; ++i) begin
            if (next_counter > 0 && rob_entries[next_head].executed) begin
                if (rob_entries[next_head].success) begin
                    rob_ct_packet.entries[i] = rob_entries[next_head];
                    next_head = (next_head + 1) % SIZE;
                    next_counter = next_counter - 1;
                end else begin
                    squash = 1;
                    next_head = 0;
                    next_tail = 0;
                    next_counter = 0;
                    break;
                end
            end else begin
                rob_ct_packet.entries[i] = 0;
            end
        end

        // Issue
        if (~almost_full && ~squash) begin
            for (int i = 0; i < `N; ++i) begin
                if (rob_is_packet.valid[i]) begin
                    next_rob_entries[next_tail] = rob_is_packet.entries[i];
                    next_tail = (next_tail + 1) % SIZE;
                    next_counter = next_counter + 1;
                end
            end
        end
        
        // CDB update
        for (int i = 0; i < `CDB_SZ; ++i) begin
            if (fu_rob_packet[i].executed) begin
                next_rob_entries[fu_rob_packet[i].robn].executed = 1;
                next_rob_entries[fu_rob_packet[i].robn].resolve_taken = fu_rob_packet[i].branch_taken;
                next_rob_entries[fu_rob_packet[i].robn].success = next_rob_entries[fu_rob_packet[i].robn].resolve_taken == next_rob_entries[fu_rob_packet[i].robn].predict_taken;
                next_rob_entries[fu_rob_packet[i].robn].NPC = fu_rob_packet[i].target_addr;
            end
        end

        // Tail entries
        for (int i = 0; i < `N; ++i) begin
            tail_entries[i] = (next_tail + i) % SIZE;
        end
    end

    assign almost_full = (counter > SIZE - ALERT_DEPTH);
    
    assign entries_out = rob_entries;
    assign counter_out = counter;
    assign head_out = head;
    assign tail_out = tail;


    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= 0;
            head    <= 0;
            tail    <= 0;
            for (int i = 0; i < SIZE; ++i) begin
                rob_entries[i] <= '{
                    0, // executed;
                    0, // success;
                    0, // is_store;
                    0, // cond_branch;
                    0, // uncond_branch;
                    0, // resolve_taken;
                    0, // predict_taken;
                    0, // predict_target;
                    0, // resolve_target;
                    0, // dest_prn;
                    0, // dest_arn;
                    0, // PC;
                    0, // NPC;
                    0, // halt;
                    0, // illegal;
                    0  // csr_op; 
                };
            end
        end else begin
            counter     <= next_counter;
            head        <= next_head;
            tail        <= next_tail;
            rob_entries <= next_rob_entries;
        end
    end
endmodule
