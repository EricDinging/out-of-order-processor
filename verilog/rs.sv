`include "sys_defs.svh"

module rs #(
    parameter SIZE = `RS_SZ,
    parameter ALERT_DEPTH = `N
)(
    input clock, reset,
    
    input RS_IS_PACKET rs_is_packet,

    input CDB_PACKET [`N-1:0] cdb_packet,
    
    input logic [`NUM_FU_ALU-1:0]   fu_alu_avail,
    input logic [`NUM_FU_MULT-1:0]  fu_mult_avail,
    input logic [`NUM_FU_LOAD-1:0]  fu_load_avail,
    input logic [`NUM_FU_STORE-1:0] fu_store_avail,
    
    output FU_PACKET fu_alu_packet [`NUM_FU_ALU-1:0],
    output FU_PACKET fu_mult_packet [`NUM_FU_MULT-1:0],
    output FU_PACKET fu_load_packet [`NUM_FU_LOAD-1:0],
    output FU_PACKET fu_store_packet [`NUM_FU_STORE-1:0],
    output logic almost_full
    `ifdef DEBUG_OUT
    , output RS_ENTRY [SIZE-1:0]      entries_out
    , output logic [`RS_CNT_WIDTH-1:0] counter_out
    `endif
);
    // State
    logic [`RS_CNT_WIDTH-1:0] counter;
    RS_ENTRY [SIZE-1:0]   entries;

    assign entries_out = entries;
    assign counter_out = counter;
    
    // Next state
    logic [`RS_CNT_WIDTH-1:0] next_counter;
    RS_ENTRY [SIZE-1:0]   next_entries;

    wire [SIZE-1:0] wake_ups;
    wire [SIZE-1:0] alu_wake_ups;
    wire [SIZE-1:0] mult_wake_ups;
    wire [SIZE-1:0] load_wake_ups;
    wire [SIZE-1:0] store_wake_ups;

    wire [`NUM_FU_ALU-1:0][SIZE-1:0]   alu_gnt_bus;
    wire [`NUM_FU_MULT-1:0][SIZE-1:0]  mult_gnt_bus;
    wire [`NUM_FU_LOAD-1:0][SIZE-1:0]  load_gnt_bus;
    wire [`NUM_FU_STORE-1:0][SIZE-1:0] store_gnt_bus;

    // wor  [SIZE-1:0] select;
    logic [SIZE-1:0][`NUM_FU_ALU-1:0]   alu_sel;
    logic [SIZE-1:0][`NUM_FU_MULT-1:0]  mult_sel;
    logic [SIZE-1:0][`NUM_FU_LOAD-1:0]  load_sel;
    logic [SIZE-1:0][`NUM_FU_STORE-1:0] store_sel;

    psel_gen #(
        .WIDTH(SIZE),
        .REQS(`NUM_FU_ALU)
    ) alu_selector (
        .req(alu_wake_ups),
        .gnt(),
        .gnt_bus(alu_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(SIZE),
        .REQS(`NUM_FU_MULT)
    ) mult_selector (
        .req(mult_wake_ups),
        .gnt(),
        .gnt_bus(mult_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(SIZE),
        .REQS(`NUM_FU_LOAD)
    ) load_selector (
        .req(load_wake_ups),
        .gnt(),
        .gnt_bus(load_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(SIZE),
        .REQS(`NUM_FU_STORE)
    ) store_selector (
        .req(store_wake_ups),
        .gnt(),
        .gnt_bus(store_gnt_bus),
        .empty()
    );

    // Combinational
    always_comb begin
        next_counter = counter;
        next_entries = entries;

        for (int i = 0, inst_cnt = 0; i < SIZE; ++i) begin
            // Input new value
            if (~entries[i].valid && inst_cnt < `N && ~almost_full) begin
                next_entries[i] = rs_is_packet.entries[inst_cnt];
                ++inst_cnt;
                ++next_counter;
            end

            // Check CDB value
            for (int cdb_idx = 0; cdb_idx < `N; ++cdb_idx) begin
                if (cdb_packet[cdb_idx].valid) begin
                    // PRN  dest_prn = cdb_packet[cdb_idx].dest_prn;
                    // DATA value    = cdb_packet[cdb_idx].value;
                    if (~next_entries[i].op1_ready && cdb_packet[cdb_idx].dest_prn == next_entries[i].op1) begin
                        next_entries[i].op1 = cdb_packet[cdb_idx].value;
                    end
                    if (~next_entries[i].op2_ready && cdb_packet[cdb_idx].dest_prn == next_entries[i].op2) begin
                        next_entries[i].op2 = cdb_packet[cdb_idx].value;
                    end
                end
            end

            // Output
            for (int j = 0; j < `NUM_FU_ALU; j++) begin
                if (alu_sel[i][j]) begin
                    fu_alu_packet[j] = {
                        entries[i].inst, // .inst
                        entries[i].func, // .func
                        entries[i].op1, // .op1 
                        entries[i].op2, // .op2 
                        entries[i].robn // .robn
                    };
                    next_entries[i].valid = `FALSE;
                    next_counter--;
                end 
            end

            for (int j = 0; j < `NUM_FU_MULT; j++) begin
                if (mult_sel[i][j]) begin
                    fu_mult_packet[j] = {
                        entries[i].inst, // .inst
                        entries[i].func, // .func
                        entries[i].op1, // .op1 
                        entries[i].op2, // .op2 
                        entries[i].robn // .robn
                    };
                    next_entries[i].valid = `FALSE;
                    next_counter--;
                end 
            end

            for (int j = 0; j < `NUM_FU_LOAD; j++) begin
                if (load_sel[i][j]) begin
                    fu_load_packet[j] = {
                        entries[i].inst, // inst
                        entries[i].func, // func
                        entries[i].op1,  // op1 
                        entries[i].op2,  // op2 
                        entries[i].robn // robn
                    };
                    next_entries[i].valid = `FALSE;
                    next_counter--;
                end 
            end

            for (int j = 0; j < `NUM_FU_STORE; j++) begin
                if (store_sel[i][j]) begin
                    fu_store_packet[j] = {
                        entries[i].inst, // inst
                        entries[i].func, // func
                        entries[i].op1,  // op1 
                        entries[i].op2,  // op2 
                        entries[i].robn // robn
                    };
                    next_entries[i].valid = `FALSE;
                    next_counter--;
                end 
            end

            // if (select[i]) begin
            //     next_entries[i].valid = `FALSE;
            // end
        end

        
    end

    // wake_ups
    genvar i;
    generate
        for (i = 0; i < SIZE; ++i) begin
            assign wake_ups[i]       = entries[i].valid && entries[i].op1_ready && entries[i].op2_ready;
            assign alu_wake_ups[i]   = wake_ups[i] && (entries[i].fu == FU_ALU);
            assign mult_wake_ups[i]  = wake_ups[i] && (entries[i].fu == FU_MULT);
            assign load_wake_ups[i]  = wake_ups[i] && (entries[i].fu == FU_LOAD);
            assign store_wake_ups[i] = wake_ups[i] && (entries[i].fu == FU_STORE);
        end
    endgenerate

    always_comb begin
        for (int i = 0; i < SIZE; ++i) begin
            for (int j = 0; j < `NUM_FU_ALU; ++j) begin
                alu_sel[i][j] = alu_gnt_bus[j][i] & fu_alu_avail[j];
            end

            for (int j = 0; j < `NUM_FU_MULT; ++j) begin
                mult_sel[i][j] = mult_gnt_bus[j][i] & fu_mult_avail[j];
            end

            for (int j = 0; j < `NUM_FU_LOAD; ++j) begin
                load_sel[i][j] = load_gnt_bus[j][i] & fu_load_avail[j];
            end

            for (int j = 0; j < `NUM_FU_STORE; ++j) begin
                store_sel[i][j] = store_gnt_bus[j][i] & fu_store_avail[j];
            end
        end
    end

    // genvar j;
    // generate
    //     for (j = 0; j < `NUM_FU_ALU; ++j) begin
    //         assign select = alu_gnt_bus[j] & {(SIZE){fu_alu_avail[j]}};
    //     end
    //     for (j = 0; j < `NUM_FU_MULT; ++j) begin
    //         assign select = mult_gnt_bus[j] & {(SIZE){fu_mult_avail[j]}};
    //     end
    //     for (j = 0; j < `NUM_FU_LOAD; ++j) begin
    //         assign select = load_gnt_bus[j] & {(SIZE){fu_load_avail[j]}};
    //     end
    //     for (j = 0; j < `NUM_FU_STORE; ++j) begin
    //         assign select = store_gnt_bus[j] & {(SIZE){fu_store_avail[j]}};
    //     end
    // endgenerate


    assign almost_full = (counter > SIZE - ALERT_DEPTH);

    // Sequential
    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= 0;
            for (int i = 0; i < SIZE; ++i) begin
                entries[i] <= {
                    `NOP,    // inst
                    `FALSE,  // valid
                    32'b0,   // PC
                    FU_ALU,  // fu
                    ALU_ADD, // func.alu
                    `FALSE,  // op1_ready
                    `FALSE,  // op2_ready
                    32'h0,   // op1
                    32'h0,   // op2
                    {`PRN_WIDTH{1'h0}},    // dest_prn
                    {`ROB_CNT_WIDTH{1'h0}} // dest_rob
                };
            end
        end else begin
            counter <= next_counter;
            entries <= next_entries;
        end
    end

endmodule

