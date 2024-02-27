`include "sys_defs.svh"

module rs #(
    parameter SIZE = `RS_SZ,
    parameter ALERT_DEPTH = `N
)(
    input clock, reset,
    
    input RS_IS_PACKET rs_is_packet,

    input [`N-1:0] CDB_PACKET cdb_packet,
    
    input [`NUM_FU_ALU-1:0]   logic fu_alu_avail,
    input [`NUM_FU_MULT-1:0]  logic fu_mult_avail,
    input [`NUM_FU_LOAD-1:0]  logic fu_load_avail,
    input [`NUM_FU_STORE-1:0] logic fu_store_avail,
    
    output [`NUM_FU_ALU-1:0]   FU_PACKET fu_alu_packet,
    output [`NUM_FU_MULT-1:0]  FU_PACKET fu_mult_packet,
    output [`NUM_FU_LOAD-1:0]  FU_PACKET fu_load_packet,
    output [`NUM_FU_STORE-1:0] FU_PACKET fu_store_packet,

    output logic almost_full
);

    parameter CNT_WIDTH = $clog2(SIZE);

    // State
    logic [CNT_WIDTH-1:0] counter;
    RS_ENTRY [SIZE-1:0]   entries;

    // Next state
    logic [CNT_WIDTH-1:0] next_counter;
    RS_ENTRY [SIZE-1:0]   next_entries;

    logic [SIZE-1:0] wake_ups;
    logic [SIZE-1:0] alu_wake_ups;
    logic [SIZE-1:0] mult_wake_ups;
    logic [SIZE-1:0] load_wake_ups;
    logic [SIZE-1:0] store_wake_ups;

    psel_gen #(
        .WIDTH = SIZE,
        .REQS = `NUM_FU_ALU
    ) alu_sel (
        .req(alu_wake_ups),
        .gnt(),
        .gnt_bus(),
        .empty()
    );

    psel_gen #(
        .WIDTH = SIZE,
        .REQS = `NUM_FU_MULT
    ) mult_sel (
        .req(mult_wake_ups),
        .gnt(),
        .gnt_bus(),
        .empty()
    );

    psel_gen #(
        .WIDTH = SIZE,
        .REQS = `NUM_FU_LOAD
    ) load_sel (
        .req(load_wake_ups),
        .gnt(),
        .gnt_bus(),
        .empty()
    );

    psel_gen #(
        .WIDTH = SIZE,
        .REQS = `NUM_FU_STORE
    ) store_sel (
        .req(store_wake_ups),
        .gnt(),
        .gnt_bus(),
        .empty()
    );

    // Combinational
    always_comb begin
        next_counter = counter;
        next_entries = entries;

        int inst_cnt = 0;
        for (int i = 0; i < SIZE; ++i) begin
            // Input new value
            if (~entries[i].valid && inst_cnt < `N) begin
                next_entries[i] = rs_is_packet.entries[inst_cnt];
                ++inst_cnt;
                ++next_counter;
            end

            // Check CDB value
            for (int cdb_idx = 0; cdb_idx < `N; ++cdb_idx) begin
                if (cdb_packet[cdb_idx].valid) begin
                    PRN  dest_prn = cdb_packet[cdb_idx].dest_prn;
                    DATA value    = cdb_packet[cdb_idx].value;
                    if (~next_entries[i].op1_ready && dest_prn == next_entries[i].op1) begin
                        next_entries[i].op1 = value;
                    end
                    if (~next_entries[i].op2_ready && dest_prn == next_entries[i].op2) begin
                        next_entries[i].op2 = value;
                    end
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
            assign load_wake_ups[i]  = wake_ups[i] && (entries[i].fu == FU_LOAD);
            assign store_wake_ups[i] = wake_ups[i] && (entries[i].fu == FU_STORE);
        end
    endgenerate

    assign almost_full = (counter > SIZE - ALERT_DEPTH);


    // Sequential
    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= 0;
            for (int i = 0; i < SIZE; ++i) begin
                entries[i] <= {
                    .inst      = `NOP,
                    .valid     = `FALSE,
                    .PC        = 0,
                    .fu        = FU_ALU,
                    .func.alu  = ALU_ADD,
                    .op1_ready = `FALSE,
                    .op2_ready = `FALSE,
                    .op1.prn   = 0,
                    .op2.prn   = 0,
                    .dest_prn  = 0,
                    .robn      = 0
                };
            end
        end else begin
            counter <= next_counter;
            entries <= next_entries;
        end
    end

endmodule

