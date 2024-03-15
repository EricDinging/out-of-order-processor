`include "sys_defs.svh"

module cdb #(
    parameter SIZE = `CDB_SZ
)(
    input clock, reset,
    input FU_STATE_PACKET fu_state_packet,

    // control signal back to fu
    // also tell rs whether it the next value will be accepted
    output logic [`NUM_FU_ALU-1:0]  alu_avail,
    output logic [`NUM_FU_MULT-1:0] mult_avail,
    output logic [`NUM_FU_LOAD-1:0] load_avail,

    // data path
    output CDB_PREDICTOR_PACKET [`NUM_FU_ALU-1:0] cdb_predictor_packet, // for predictor, regardless of priority selection

    output FU_ROB_PACKET [SIZE-1:0] fu_rob_packet,
    output CDB_PACKET    [SIZE-1:0] cdb_output // for both cdb and prf
);

    FU_STATE_PACKET cdb_state;

    logic [`NUM_FU_ALU-1:0]  alu_selected;
    logic [`NUM_FU_MULT-1:0] mult_selected;
    logic [`NUM_FU_LOAD-1:0] load_selected;

    // for mux input
    FU_ROB_PACKET [`NUM_FU_ALU-1:0] alu_rob_packet;
    FU_ROB_PACKET [`NUM_FU_MULt+`NUM_FU_LOAD-1:0] other_rob_packet;
    CDB_PACKET [`NUM_FU_ALU-1:0] alu_cdb_packet;
    CDB_PACKET [`NUM_FU_MULt+`NUM_FU_LOAD-1:0] other_cdb_packet;

    logic [`N-1:0][`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD-1:0] mux_select; // TODO: the mux need a default value
    
    assign alu_avail = alu_selected | ~cdb_state.alu_prepared | cdb_state.alu_packet.cond_branch;
    assign mult_avail = mult_selected | ~cdb_state.mult_prepared;
    assign load_avail = load_selected | ~cdb_state.load_prepared;

    psel_gen #(
        .WIDTH(`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD),
        .REQS(`N)
    ) psel_fu_cdb (
        .req({fu_state_packet.alu_prepared & ~fu_state_packet.alu_packet.cond_branch, fu_state_packet.mult_prepared, fu_state_packet.load_prepared}), // TODO: cond_branch
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

    always_comb begin
        // alu
        for (int i = 0; i < `NUM_FU_ALU; i++) begin
            alu_rob_packet[i] = '{
                fu_state_packet.alu_packet[i].basic.robn,
                fu_state_packet.alu_prepared[i],
                fu_state_packet.alu_packet[i].take_branch,
                fu_state_packet.alu_packet[i].basic.result
            }
            alu_cdb_packet[i] = if fu_state_packet.alu_prepared[i]
                                then '{
                                    fu_state_packet.alu_packet[i].basic.dest_prn,
                                    fu_state_packet.alu_packet[i].basic.result
                                }
                                else 0
        end

        // mult
        for (int i = 0; i < `NUM_FU_MULT; i++) begin
            other_rob_packet[i] = '{
                fu_state_packet.mult_packet[i].robn,
                fu_state_packet.mult_prepared[i],
                1'b0, // not taken
                32'b0 // null address
            }
            other_cdb_packet[i] = if fu_state_packet.mult_prepared[i]
                                  then '{
                                    fu_state_packet.mult_packet[i].dest_prn,
                                    fu_state_packet.mult_packet[i].result
                                  }
                                  else 0
        end
        
        // load
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            other_rob_packet[`NUM_FU_MULT+i] = '{
                fu_state_packet.load_packet[i].robn,
                fu_state_packet.load_prepared[i],
                1'b0, // not taken
                32'b0 // null address
            }
            other_cdb_packet[`NUM_FU_MULT+i] = if fu_state_packet.load_prepared[i]
                                            then '{
                                                fu_state_packet.load_packet[i].dest_prn,
                                                fu_state_packet.load_packet[i].result
                                            }
                                            else 0
        end
    end

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
        .mult_select(mult_select),
        .fu_rob_packet(fu_rob_packet),
        .cdb_packet(cdb_output)
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            cdb_state <= 0;
        end else begin
            cdb_state <= fu_state_packet;
        end
    end

endmodule


module select_insn (
    input FU_ROB_PACKET [`NUM_FU_ALU+`NUM_FU_MULt+`NUM_FU_LOAD-1:0] rob_packets;
    input CDB_PACKET [`NUM_FU_ALU+`NUM_FU_MULt+`NUM_FU_LOAD-1:0] cdb_packets;
    input logic [`N-1:0][`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD-1:0] mux_select;

    output FU_ROB_PACKET [`N-1:0] fu_rob_packet;
    output CDB_PACKET [`N-1:0] cdb_packet;
);
    mux_cdb mux_cdb_inst [`N-1:0] (
        .rob_packets(rob_packets),
        .cdb_packets(cdb_packets),
        .select(mux_select), // TODO: check field match
        .fu_rob_packet(fu_rob_packet),
        .cdb_packet(cdb_packet)
    )
endmodule

module mux_cdb (
    input FU_ROB_PACKET [`NUM_FU_ALU+`NUM_FU_MULt+`NUM_FU_LOAD-1:0] rob_packets;
    input CDB_PACKET [`NUM_FU_ALU+`NUM_FU_MULt+`NUM_FU_LOAD-1:0] cdb_packets;
    input logic [`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD-1:0] select;

    output FU_ROB_PACKET fu_rob_packet;
    output CDB_PACKET cdb_packet;
);
    always_comb begin
        fu_rob_packet = 0;
        cdb_packet = 0;
        for (int i = 0; i < `NUM_FU_ALU+`NUM_FU_MULt+`NUM_FU_LOAD; i++) begin
            fu_rob_packet = fu_rob_packet | (rob_packets[i] & {`ROB_CNT_WIDTH+2+32{select[i]}});
            cdb_packet = cdb_packet | (cdb_packets[i] & {32+`PRN_WIDTH{select[i]}});
        end
    end
endmodule