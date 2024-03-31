`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module cdb #(
    parameter SIZE = `CDB_SZ
) (
    input clock, reset,
    input FU_STATE_PACKET fu_state_packet,

    // control signal back to fu
    // also tell rs whether it the next value will be accepted
    output logic [ `NUM_FU_ALU-1:0] alu_avail,
    output logic [`NUM_FU_MULT-1:0] mult_avail,
    output logic [`NUM_FU_LOAD-1:0] load_avail,

    // data path
    // output CDB_PREDICTOR_PACKET [`NUM_FU_ALU-1:0] cdb_predictor_packet, // for predictor, regardless of priority selection
    output FU_ROB_PACKET [SIZE-1:0] fu_rob_packet,
    output CDB_PACKET    [SIZE-1:0] cdb_output // for both cdb and prf
    `ifdef CPU_DEBUG_OUT
    , output logic [`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD-1:0] select_debug
    `endif
);

    FU_STATE_PACKET cdb_state;

    logic [`NUM_FU_ALU-1:0]  alu_selected;
    logic [`NUM_FU_MULT-1:0] mult_selected;
    logic [`NUM_FU_LOAD-1:0] load_selected;

    // for mux input
    FU_ROB_PACKET [`NUM_FU_ALU-1:0] alu_rob_packet;
    FU_ROB_PACKET [`NUM_FU_MULT+`NUM_FU_LOAD-1:0] other_rob_packet;
    CDB_PACKET [`NUM_FU_ALU-1:0] alu_cdb_packet;
    CDB_PACKET [`NUM_FU_MULT+`NUM_FU_LOAD-1:0] other_cdb_packet;

    logic [`N-1:0][`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD-1:0] mux_select;
    logic [`NUM_FU_ALU-1:0] cond_branches;

    assign alu_avail  = alu_selected | ~cdb_state.alu_prepared | cond_branches;
    assign mult_avail = mult_selected | ~cdb_state.mult_prepared;
    assign load_avail = load_selected | ~cdb_state.load_prepared;

    `ifdef CPU_DEBUG_OUT
    assign select_debug = 
            {alu_selected, mult_selected, load_selected};
    `endif
    psel_gen #(
        .WIDTH(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD),
        .REQS (`N)
    ) psel_fu_cdb (
        .req({
            cdb_state.alu_prepared & ~cond_branches,
            cdb_state.mult_prepared,
            cdb_state.load_prepared
        }),
        .gnt({alu_selected, mult_selected, load_selected}),
        .gnt_bus(mux_select),
        .empty()
    );

    /*
    typedef struct packed {
        PRN   dest_prn;
        DATA  value;
    } CDB_PACKET;
    */

    // compile cond_branch into an array
    genvar i;
    generate
    for (i = 0; i < `NUM_FU_ALU; i++) begin
        assign cond_branches[i] = cdb_state.alu_packet[i].cond_branch;
    end
    endgenerate

    // calculate mux input
    always_comb begin
    // alu
        for (int i = 0; i < `NUM_FU_ALU; i++) begin
            alu_rob_packet[i] = '{
                cdb_state.alu_packet[i].basic.robn,
                cdb_state.alu_prepared[i],
                cdb_state.alu_packet[i].take_branch,
                cdb_state.alu_packet[i].basic.result
            };
            alu_cdb_packet[i] = cdb_state.alu_prepared[i] ?
            '{cdb_state.alu_packet[i].basic.dest_prn, cdb_state.alu_packet[i].basic.result}
            : '{{`PRN_WIDTH{1'b0}}, 32'b0};
        end

        // load
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            other_rob_packet[i] = '{
                cdb_state.load_packet[i].robn,
                cdb_state.load_prepared[i],
                1'b0,  // not taken
                32'b0  // null address
            };
        end

        // mult
        for (int i = 0; i < `NUM_FU_MULT; i++) begin
            other_rob_packet[`NUM_FU_LOAD + i] = '{
                cdb_state.mult_packet[i].robn,
                cdb_state.mult_prepared[i],
                1'b0,  // not taken
                32'b0  // null address
            };
            other_cdb_packet[`NUM_FU_LOAD + i] = cdb_state.mult_prepared[i] ?
            '{cdb_state.mult_packet[i].dest_prn, cdb_state.mult_packet[i].result}
            : '{{`PRN_WIDTH{1'b0}}, 32'b0};
            // other_cdb_packet[i] = '{5'b1, 32'hdeadbeef};
            // other_cdb_packet[i].dest_prn = 5'b1;
            // other_cdb_packet[i].value = 32'hdeadbeef;
        end
    end

    // // predictor output
    // always_comb begin
    //     for (int i = 0; i < `NUM_FU_ALU; i++) begin
    //         cdb_predictor_packet[i] = '{
    //             cdb_state.alu_prepared[i] && cdb_state.alu_packet[i].take_branch,
    //             cdb_state.alu_packet[i].PC,
    //             cdb_state.alu_packet[i].basic.result
    //         };
    //     end
    // end

    /*
    typedef struct packed {
    ROBN  robn;
    logic executed;
    logic branch_taken;
    ADDR target_addr;
    } FU_ROB_PACKET;
    */

    select_insn mux_cdb_inst (
        .rob_packets({alu_rob_packet, other_rob_packet}),
        .cdb_packets({alu_cdb_packet, other_cdb_packet}),
        .mux_select(mux_select),
        .fu_rob_packet(fu_rob_packet),
        .cdb_packet(cdb_output)
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            cdb_state.alu_prepared <= {`NUM_FU_ALU{1'b0}};
            cdb_state.mult_prepared <= {`NUM_FU_MULT{1'b0}};
            cdb_state.load_prepared <= {`NUM_FU_LOAD{1'b0}};

            for (int i = 0; i < `NUM_FU_ALU; ++i) begin
                cdb_state.alu_packet[i] <= '{'{{`ROB_CNT_WIDTH{1'b0}}, {`PRN_WIDTH{1'b0}}, 32'b0}, 1'b0, 1'b0, 1'b0};
            end
            for (int i = 0; i < `NUM_FU_MULT; ++i) begin
                cdb_state.mult_packet[i] <= '{{`ROB_CNT_WIDTH{1'b0}}, {`PRN_WIDTH{1'b0}}, 32'b0};
            end
            for (int i = 0; i < `NUM_FU_LOAD; ++i) begin
                cdb_state.load_packet[i] <= '{{`ROB_CNT_WIDTH{1'b0}}, {`PRN_WIDTH{1'b0}}, 32'b0};
            end

        end else begin
            for (int i = 0; i < `NUM_FU_ALU; i++) begin
                if (alu_avail[i]) begin
                    cdb_state.alu_prepared[i] <= fu_state_packet.alu_prepared[i];
                    cdb_state.alu_packet[i] <= fu_state_packet.alu_packet[i];
                end
            end
            for (int i = 0; i < `NUM_FU_MULT; i++) begin
                if (mult_avail[i]) begin
                    cdb_state.mult_prepared[i] <= fu_state_packet.mult_prepared[i];
                    cdb_state.mult_packet[i] <= fu_state_packet.mult_packet[i];
                end
            end
            for (int i = 0; i < `NUM_FU_LOAD; i++) begin
                if (load_avail[i]) begin
                    cdb_state.load_prepared[i] <= fu_state_packet.load_prepared[i];
                    cdb_state.load_packet[i] <= fu_state_packet.load_packet[i];
                end
            end
        end
    end

endmodule


module select_insn (
    input FU_ROB_PACKET [`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LOAD-1:0] rob_packets,
    input CDB_PACKET [`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LOAD-1:0] cdb_packets,
    input logic [`N-1:0][`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LOAD-1:0] mux_select,

    output FU_ROB_PACKET [`N-1:0] fu_rob_packet,
    output CDB_PACKET [`N-1:0] cdb_packet
);
    // mux_cdb mux_cdb_inst[`N-1:0] (
    //     .rob_packets(rob_packets),
    //     .cdb_packets(cdb_packets),
    //     .select(mux_select),  // TODO: check field match
    //     .fu_rob_packet(fu_rob_packet),
    //     .cdb_packet(cdb_packet)
    // );

    genvar i;
    generate
        for (i = 0; i < `N; ++i) begin
            mux_cdb mux_cdb_inst (
                .rob_packets(rob_packets),
                .cdb_packets(cdb_packets),
                .select(mux_select[i]),
                .fu_rob_packet(fu_rob_packet[i]),
                .cdb_packet(cdb_packet[i])
            );
        end
    endgenerate
endmodule

module mux_cdb (
    input FU_ROB_PACKET [`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LOAD-1:0] rob_packets,
    input CDB_PACKET [`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LOAD-1:0] cdb_packets,
    input logic [`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD-1:0] select,

    output FU_ROB_PACKET fu_rob_packet,
    output CDB_PACKET cdb_packet
);
    // default is 0
    // always_comb begin
    //     fu_rob_packet = 0;
    //     cdb_packet = 0;
    //     for (int i = 0; i < `NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LOAD; i++) begin
    //         fu_rob_packet = fu_rob_packet | (rob_packets[i] & {(`ROB_CNT_WIDTH+2+32){select[i]}});
    //         cdb_packet = cdb_packet | (cdb_packets[i] & {32+`PRN_WIDTH{select[i]}});
    //     end
    // end

    onehot_mux #(
        .SIZE ($bits(FU_ROB_PACKET)),
        .WIDTH(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD)
    ) mux_rob (
        .in(rob_packets),
        .select(select),
        .out(fu_rob_packet)
    );

    onehot_mux #(
        .SIZE ($bits(CDB_PACKET)),
        .WIDTH(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD)
    ) mux_cdb (
        .in(cdb_packets),
        .select(select),
        .out(cdb_packet)
    );

endmodule
