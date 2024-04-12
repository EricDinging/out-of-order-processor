`include "sys_defs.svh"
`define CPU_DEBUG_OUT

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

    input SQ_IDX head,
    input SQ_IDX tail,
    input SQ_IDX tail_ready,

    output FU_PACKET [`NUM_FU_ALU-1:0]   fu_alu_packet,
    output FU_PACKET [`NUM_FU_MULT-1:0]  fu_mult_packet,
    output FU_PACKET [`NUM_FU_LOAD-1:0]  fu_load_packet,
    output FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet,
    output logic almost_full
    `ifdef CPU_DEBUG_OUT // DEBUG_OUT
    , output RS_ENTRY [SIZE-1:0]       entries_out
    , output logic [`RS_CNT_WIDTH-1:0] counter_out
    `endif
);
    // State
    logic [`RS_CNT_WIDTH-1:0] counter;
    RS_ENTRY [SIZE-1:0]       entries;

    assign entries_out = entries;
    assign counter_out = counter;
    
    RS_IS_PACKET rs_is_packet_temp;

    // Next state
    logic [`RS_CNT_WIDTH-1:0] next_counter;
    RS_ENTRY [SIZE-1:0]       next_entries;

    wire [SIZE-1:0] wake_ups;
    wire [SIZE-1:0] alu_wake_ups;
    wire [SIZE-1:0] mult_wake_ups;
    wire [SIZE-1:0] load_wake_ups;
    wire [SIZE-1:0] store_wake_ups;

    wire [`NUM_FU_ALU-1:0][SIZE-1:0]   alu_gnt_bus;
    wire [`NUM_FU_MULT-1:0][SIZE-1:0]  mult_gnt_bus;
    wire [`NUM_FU_LOAD-1:0][SIZE-1:0]  load_gnt_bus;
    wire [`NUM_FU_STORE-1:0][SIZE-1:0] store_gnt_bus;

    FU_PACKET [`NUM_FU_ALU-1:0]   next_fu_alu_packet;
    FU_PACKET [`NUM_FU_MULT-1:0]  next_fu_mult_packet;
    FU_PACKET [`NUM_FU_LOAD-1:0]  next_fu_load_packet;
    FU_PACKET [`NUM_FU_STORE-1:0] next_fu_store_packet;

    logic [SIZE-1:0][`NUM_FU_ALU-1:0]   alu_sel;
    logic [SIZE-1:0][`NUM_FU_MULT-1:0]  mult_sel;
    logic [SIZE-1:0][`NUM_FU_LOAD-1:0]  load_sel;
    logic [SIZE-1:0][`NUM_FU_STORE-1:0] store_sel;

    SQ_IDX input_tail;

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

    function FU_PACKET rs_entry_to_packet;
        input RS_ENTRY entry;
        begin
            rs_entry_to_packet = '{
                entry.valid,    // .valid
                entry.inst,     // .inst
                entry.PC,       // .PC
                entry.func,     // .func
                entry.op1,      // .op1
                entry.op2,      // .op2
                entry.dest_prn, // .dest_prn
                entry.robn,     // .robn
                entry.opa_select,
                entry.opb_select,
                entry.cond_branch,
                entry.uncond_branch,
                entry.sq_idx,
                entry.mem_func
            };
        end
    endfunction

    // Combinational
    always_comb begin
        next_counter = counter;
        next_entries = entries;
        next_fu_alu_packet   = fu_alu_packet;
        next_fu_mult_packet  = fu_mult_packet;
        next_fu_load_packet  = fu_load_packet;
        next_fu_store_packet = fu_store_packet;

        for (int j = 0; j < `NUM_FU_ALU; j++) begin
            next_fu_alu_packet[j].valid = 1'b0;
        end

        for (int j = 0; j < `NUM_FU_MULT; j++) begin
            next_fu_mult_packet[j].valid = 1'b0;
        end

        for (int j = 0; j < `NUM_FU_LOAD; j++) begin
            next_fu_load_packet[j].valid = 1'b0;
        end

        for (int j = 0; j < `NUM_FU_STORE; j++) begin
            next_fu_store_packet[j].valid = 1'b0;
        end

        input_tail = tail;
        rs_is_packet_temp = rs_is_packet;
        for (int i = 0; i < `N; i++) begin
            rs_is_packet_temp.entries[i].sq_idx = input_tail;
            if (rs_is_packet_temp.entries[i].fu == FU_STORE) begin
                input_tail = (input_tail + 1) % (`SQ_LEN + 1);
            end
        end

        for (int i = 0, inst_cnt = 0; i < SIZE; ++i) begin
            // Input new value
            if (~entries[i].valid & 
                inst_cnt < `N &
                ~almost_full & 
                rs_is_packet_temp.entries[inst_cnt].valid) begin
                next_entries[i] = rs_is_packet_temp.entries[inst_cnt];
                ++inst_cnt;
                ++next_counter;
            end

            // Check CDB value
            for (int cdb_idx = 0; cdb_idx < `N; ++cdb_idx) begin
                if (cdb_packet[cdb_idx].dest_prn != 0) begin
                    if (~next_entries[i].op1_ready && cdb_packet[cdb_idx].dest_prn == next_entries[i].op1) begin
                        next_entries[i].op1_ready = `TRUE;
                        next_entries[i].op1       = cdb_packet[cdb_idx].value;
                    end
                    if (~next_entries[i].op2_ready && cdb_packet[cdb_idx].dest_prn == next_entries[i].op2) begin
                        next_entries[i].op2_ready = `TRUE;
                        next_entries[i].op2       = cdb_packet[cdb_idx].value;
                    end
                end
            end


            // Output
            for (int j = 0; j < `NUM_FU_ALU; j++) begin
                if (alu_sel[i][j]) begin
                    next_fu_alu_packet[j] = rs_entry_to_packet(entries[i]);
                    next_entries[i].valid = `FALSE;
                    next_counter--;
                end  
            end

            for (int j = 0; j < `NUM_FU_MULT; j++) begin
                if (mult_sel[i][j]) begin
                    next_fu_mult_packet[j] = rs_entry_to_packet(entries[i]);
                    next_entries[i].valid = `FALSE;
                    next_counter--;
                end 
            end

            for (int j = 0; j < `NUM_FU_LOAD; j++) begin
                if (load_sel[i][j]) begin
                    next_fu_load_packet[j] = rs_entry_to_packet(entries[i]);
                    next_entries[i].valid = `FALSE;
                    next_counter--;
                end 
            end

            for (int j = 0; j < `NUM_FU_STORE; j++) begin
                if (store_sel[i][j]) begin
                    next_fu_store_packet[j] = rs_entry_to_packet(entries[i]);
                    next_entries[i].valid = `FALSE;
                    next_counter--;
                end 
            end
        end
    end

    // wake_ups
    genvar i;
    generate
        for (i = 0; i < SIZE; ++i) begin
            assign wake_ups[i]       = entries[i].valid && entries[i].op1_ready && entries[i].op2_ready;
            assign alu_wake_ups[i]   = wake_ups[i] && (entries[i].fu == FU_ALU);
            assign mult_wake_ups[i]  = wake_ups[i] && (entries[i].fu == FU_MULT);
            assign load_wake_ups[i]  = wake_ups[i] && (entries[i].fu == FU_LOAD)
                    &&  
                        ( head < tail_ready ?
                            entries[i].sq_idx >= head && entries[i].sq_idx <= tail_ready :
                            entries[i].sq_idx >= head || entries[i].sq_idx <= tail_ready
                        )
                    ;
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

    assign almost_full = (counter > SIZE - ALERT_DEPTH);

    // Sequential
    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= 0;
            for (int i = 0; i < SIZE; ++i) begin
                entries[i] <= 0;
            end
            for (int j = 0; j < `NUM_FU_ALU; j++) begin
                fu_alu_packet[j] <= 0;
            end
            for (int j = 0; j < `NUM_FU_MULT; j++) begin
                fu_mult_packet[j] <= 0;
            end
            for (int j = 0; j < `NUM_FU_LOAD; j++) begin
                fu_load_packet[j] <= 0;
            end
            for (int j = 0; j < `NUM_FU_STORE; j++) begin
                fu_store_packet[j] <= 0;
            end
        end else begin
            counter <= next_counter;
            entries <= next_entries;
            fu_alu_packet   <= next_fu_alu_packet;
            fu_mult_packet  <= next_fu_mult_packet;
            fu_load_packet  <= next_fu_load_packet;
            fu_store_packet <= next_fu_store_packet;
        end
    end
endmodule
