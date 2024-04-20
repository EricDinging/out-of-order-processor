`include "sys_defs.svh"
// `define CPU_DEBUG_OUT

module rob #(
    parameter SIZE = `ROB_SZ,
    parameter ALERT_DEPTH = `N
)(
    input clock, reset,
    
    input ROB_IS_PACKET rob_is_packet,

    input FU_ROB_PACKET [`FU_ROB_PACKET_SZ-1:0] fu_rob_packet,

    input SQ_IDX sq_sent_insns_num,

    output SQ_IDX        rob_commit_insns_num,
    output logic         almost_full,
    output ROB_CT_PACKET rob_ct_packet, 
    output ROBN [`N-1:0] tail_entries,
    output logic         squash
`ifdef CPU_DEBUG_OUT
    , output ROB_ENTRY [SIZE-1:0]           entries_out
    , output logic     [`RS_CNT_WIDTH-1:0]  counter_out
    , output logic     [`ROB_PTR_WIDTH-1:0] head_out
    , output logic     [`ROB_PTR_WIDTH-1:0] tail_out
`endif
);

    logic [`ROB_CNT_WIDTH-1:0] counter, next_counter;
    logic [`ROB_PTR_WIDTH-1:0] head, next_head;
    logic [`ROB_PTR_WIDTH-1:0] tail, next_tail;

    ROB_ENTRY [SIZE-1:0] rob_entries, next_rob_entries;

    SQ_IDX internal_num_sent_insns;

    always_comb begin
        next_head = head;
        next_tail = tail;
        next_counter = counter;
        next_rob_entries = rob_entries;
        squash = 0;

        rob_commit_insns_num = 0;
        internal_num_sent_insns = sq_sent_insns_num;

        for (int i = 0; i < `N; ++i) begin
            rob_ct_packet.entries[i] = '{
                    1'b0, // executed;
                    1'b1, // success;
                    1'b0, // is_store;
                    1'b0, // cond_branch;
                    1'b0, // uncond_branch;
                    1'b0, // resolve_taken;
                    1'b0, // predict_taken;
                    32'b0, // predict_target;
                    32'b0, // resolve_target;
                    {`PRN_WIDTH{1'b0}}, // dest_prn;
                    5'b0, // dest_arn;
                    32'b0, // PC;
                    32'b0, // NPC;
                    1'b0, // halt;
                    1'b0, // illegal;
                    1'b0  // csr_op;
                };
        end

        // to SQ
        for (int i = 0; i < `N; ++i) begin
            if (counter <= i) begin
                break;
            end
            if (~rob_entries[(next_head + i) % SIZE].executed) begin
                if (rob_entries[(next_head + i) % SIZE].is_store) begin
                    rob_commit_insns_num += 1;
                end else begin
                    break;
                end
            end else if (~rob_entries[(next_head + i) % SIZE].success) begin
                break;
            end
        end

        // from SQ
        for (int i = 0; i < `N; ++i) begin
            if (rob_entries[(next_head + i) % SIZE].is_store && ~rob_entries[(next_head + i) % SIZE].executed && internal_num_sent_insns > 0) begin
                internal_num_sent_insns -= 1;
                next_rob_entries[(next_head + i) % SIZE].executed = `TRUE;
            end
        end

        // Commit
        for (int i = 0; i < `N; ++i) begin
            if (next_counter > 0 && next_rob_entries[next_head].executed) begin
                rob_ct_packet.entries[i] = next_rob_entries[next_head]; // TODO verify this op does not break if not success
                if (next_rob_entries[next_head].success) begin
                    next_head = (next_head + 1) % SIZE;
                    next_counter = next_counter - 1;
                end else begin
                    squash = 1'b1;
                    next_head    = {`ROB_PTR_WIDTH{1'b0}};
                    next_tail    = {`ROB_PTR_WIDTH{1'b0}};
                    next_counter = {`ROB_PTR_WIDTH{1'b0}};
                end
            end else begin
                break;
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
        for (int i = 0; i < `FU_ROB_PACKET_SZ; ++i) begin
            if (fu_rob_packet[i].executed) begin
                next_rob_entries[fu_rob_packet[i].robn].executed       = `TRUE;
                next_rob_entries[fu_rob_packet[i].robn].resolve_taken  = fu_rob_packet[i].branch_taken;
                next_rob_entries[fu_rob_packet[i].robn].resolve_target = fu_rob_packet[i].branch_taken ? fu_rob_packet[i].target_addr : next_rob_entries[fu_rob_packet[i].robn].NPC;
                if (rob_entries[fu_rob_packet[i].robn].cond_branch || rob_entries[fu_rob_packet[i].robn].uncond_branch) begin
                    next_rob_entries[fu_rob_packet[i].robn].success = (next_rob_entries[fu_rob_packet[i].robn].resolve_taken  == next_rob_entries[fu_rob_packet[i].robn].predict_taken)
                                                                   && (next_rob_entries[fu_rob_packet[i].robn].resolve_target == next_rob_entries[fu_rob_packet[i].robn].predict_target);
                end
            end
        end
    end

    assign almost_full = (counter > SIZE - ALERT_DEPTH);
    
    `ifdef CPU_DEBUG_OUT
    assign entries_out = rob_entries;
    assign counter_out = counter;
    assign head_out = head;
    assign tail_out = tail;
    `endif

    genvar i;
    generate
        for (i = 0; i < `N; ++i) begin
            assign tail_entries[i] = (tail + i) % SIZE;
        end
    endgenerate


    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= {`ROB_PTR_WIDTH{1'b0}};
            head    <= {`ROB_PTR_WIDTH{1'b0}};
            tail    <= {`ROB_PTR_WIDTH{1'b0}};
            for (int i = 0; i < SIZE; ++i) begin
                rob_entries[i] <= '{
                    1'b0, // executed;
                    1'b1, // success;
                    1'b0, // is_store;
                    1'b0, // cond_branch;
                    1'b0, // uncond_branch;
                    1'b0, // resolve_taken;
                    1'b0, // predict_taken;
                    32'b0, // predict_target;
                    32'b0, // resolve_target;
                    {`PRN_WIDTH{1'b0}}, // dest_prn;
                    5'b0, // dest_arn;
                    32'b0, // PC;
                    32'b0, // NPC;
                    1'b0, // halt;
                    1'b0, // illegal;
                    1'b0  // csr_op; 
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
