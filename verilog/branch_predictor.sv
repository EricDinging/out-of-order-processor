`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module not_taken_predictor (
    input clock, reset,
    input ADDR pc_start,
    input ROB_IF_PACKET rob_if_packet,
    // output
    output PC_ENTRY [`N-1:0] target_pc
);
    // always predict not taken

    always_comb begin
        for (int i = 0; i < `N; ++i) begin
            target_pc[i].taken = `FALSE;
            target_pc[i].valid = `TRUE;
            target_pc[i].PC    = pc_start + (i + 1) * 4;
        end
    end

endmodule


module BTB (
    input clock, reset,
    input ADDR [`N-1:0] pcs,
    input ROB_IF_PACKET rob_if_packet,

    output logic [`N-1:0] hits,
    output ADDR  [`N-1:0] btb_pcs
    `ifdef CPU_DEBUG_OUT
    , output BTB_ENTRY [`BTB_SIZE-1:0] btb_entries_debug
    `endif
);

    BTB_ENTRY [`BTB_SIZE-1:0] btb_entries, next_btb_entries;

`ifdef CPU_DEBUG_OUT
    assign btb_entries_debug = btb_entries;
`endif

    wire [`N-1:0][`BTB_INDEX_BITS-1:0] bp_btb_index;
    wire [`N-1:0][`BTB_TAG_BITS-1:0]   bp_tag;
    wire [`N-1:0][`BTB_INDEX_BITS-1:0] rob_btb_index;
    wire [`N-1:0][`BTB_TAG_BITS-1:0]   rob_tag;

    genvar i;
    generate
        for (i = 0; i < `N; ++i) begin
            assign bp_btb_index[i]  = pcs[i][`BTB_INDEX_BITS+2-1:2];
            assign rob_btb_index[i] = rob_if_packet.entries[i].PC[`BTB_INDEX_BITS+2-1:2];
            assign bp_tag[i]        = pcs[i][31:`BTB_INDEX_BITS+2];
            assign rob_tag[i]       = rob_if_packet.entries[i].PC[31:`BTB_INDEX_BITS+2];
        end
    endgenerate

    always_comb begin
        next_btb_entries = btb_entries;

        for (int i = 0; i < `N; ++i) begin
            hits[i]    = btb_entries[bp_btb_index[i]].valid && (btb_entries[bp_btb_index[i]].tag == bp_tag[i]);
            btb_pcs[i] = btb_entries[bp_btb_index[i]].PC;
        end

        for (int i = 0; i < `N; ++i) begin
            if (rob_if_packet.entries[i].valid && rob_if_packet.entries[i].resolve_taken) begin
                next_btb_entries[rob_btb_index[i]].valid = `TRUE;
                next_btb_entries[rob_btb_index[i]].PC    = rob_if_packet.entries[i].resolve_target;
                next_btb_entries[rob_btb_index[i]].tag   = rob_tag[i];
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            btb_entries <= 0;
        end else begin
            btb_entries <= next_btb_entries;
        end
    end

endmodule

module local_predictor (
    input clock, reset,
    input ADDR pc_start,
    input ROB_IF_PACKET rob_if_packet,
    // output
    output PC_ENTRY [`N-1:0] target_pc
`ifdef CPU_DEBUG_OUT
    , output BTB_ENTRY [`BTB_SIZE-1:0] btb_entries_debug
    , output logic [`BHT_SIZE-1:0][`BHT_WIDTH-1:0] branch_history_table_debug
    , output PHT_ENTRY_STATE [`PHT_SIZE-1:0] pattern_history_table_debug
`endif
);
    ADDR [`N-1:0] pcs;

    // fanout
    genvar i;
    generate;
        for (i = 0; i < `N; ++i) begin
            assign pcs[i] = pc_start + i * 4;
        end
    endgenerate

    // branch history table
    logic [`BHT_SIZE-1:0][`BHT_WIDTH-1:0] branch_history_table, next_branch_history_table;

    // pattern history table
    PHT_ENTRY_STATE [`PHT_SIZE-1:0] pattern_history_table, next_pattern_history_table;

`ifdef CPU_DEBUG_OUT
    assign branch_history_table_debug = branch_history_table;
    assign pattern_history_table_debug = pattern_history_table;
`endif

    logic predict_taken_flag;

    logic [`N-1:0] hits;
    ADDR  [`N-1:0] btb_pcs;

    wire [`N-1:0][`BHT_IDX_WIDTH-1:0] pc_bht_index;
    wire [`N-1:0][`BHT_IDX_WIDTH-1:0] rob_bht_index;

    generate
        for (i = 0; i < `N; ++i) begin
            assign pc_bht_index[i]  = pcs[i][`BHT_IDX_WIDTH+2-1:2];
            assign rob_bht_index[i] = rob_if_packet.entries[i].PC[`BHT_IDX_WIDTH+2-1:2];
        end
    endgenerate

    BTB btb (
        .clock(clock),
        .reset(reset),
        .pcs(pcs),
        .rob_if_packet(rob_if_packet),
        .hits(hits),
        .btb_pcs(btb_pcs)
    `ifdef CPU_DEBUG_OUT
        , .btb_entries_debug(btb_entries_debug)
    `endif
    );

    always_comb begin
        next_branch_history_table  = branch_history_table;
        next_pattern_history_table = pattern_history_table;
        target_pc = 0;
        predict_taken_flag = `FALSE;

        // prediction taken + target
        for (int i = 0; i < `N; ++i) begin
            case (pattern_history_table[branch_history_table[pc_bht_index[i]]])
                NOT_TAKEN:
                    begin
                        target_pc[i].taken = `FALSE;
                        target_pc[i].valid = ~predict_taken_flag;
                        target_pc[i].PC    = pcs[i] + 4;
                    end
                TAKEN:
                    begin
                        target_pc[i].taken = btb.hits[i];
                        target_pc[i].valid = ~predict_taken_flag;
                        if (btb.hits[i]) begin
                            target_pc[i].PC    = btb.btb_pcs[i];
                            predict_taken_flag = `TRUE;
                        end else begin
                            target_pc[i].PC = pcs[i] + 4;
                        end
                    end
            endcase
        end

        for (int i = 0; i < `N; ++i) begin
            if (rob_if_packet.entries[i].valid) begin
                // modify bht
                next_branch_history_table[rob_bht_index[i]] = 
                    {
                        next_branch_history_table[rob_bht_index[i]][`BHT_WIDTH-2:0],
                        rob_if_packet.entries[i].resolve_taken
                    };
                // modify pht
                next_pattern_history_table[branch_history_table[rob_bht_index[i]]] 
                            = (rob_if_packet.entries[i].resolve_taken) ? TAKEN : NOT_TAKEN;
                // case (pattern_history_table[branch_history_table[rob_bht_index[i]]])
                //     TAKEN:
                //         next_pattern_history_table[branch_history_table[rob_bht_index[i]]] 
                //             = (~rob_if_packet.entries[i].resolve_taken) ? NOT_TAKEN : TAKEN;
                //     NOT_TAKEN:
                //         next_pattern_history_table[branch_history_table[rob_bht_index[i]]] 
                //             = (rob_if_packet.entries[i].resolve_taken) ? TAKEN : NOT_TAKEN;
                // endcase
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            branch_history_table  <= 0;
            pattern_history_table <= 0;
        end else begin
            branch_history_table  <= next_branch_history_table;
            pattern_history_table <= next_pattern_history_table;
        end
    end

endmodule