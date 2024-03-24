`include "sys_defs.svh"

module fu_cdb(
    input clock, reset,
    input FU_PACKET [`NUM_FU_ALU-1:0] fu_alu_packet,
    input FU_PACKET [`NUM_FU_MULT-1:0] fu_mult_packet,
    input FU_PACKET [`NUM_FU_LOAD-1:0] fu_load_packet,
    input FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet,

    output logic [`NUM_FU_ALU-1:0]  alu_avail,
    output logic [`NUM_FU_MULT-1:0] mult_avail,
    output logic [`NUM_FU_LOAD-1:0] load_avail,
    output logic [`NUM_FU_STORE-1:0] store_avail,
    output FU_ROB_PACKET [`FU_ROB_PACKET_SZ-1:0] fu_rob_packet,
    output CDB_PACKET    [`N-1:0] cdb_output // for both cdb and prf
);

    FU_STATE_PACKET fu_state_packet;
    FU_ROB_PACKET [`NUM_FU_ALU-1:0] cond_rob_packet;
    FU_ROB_PACKET [`N-1:0] cdb_rob_packet;
    
    fu fu_inst(
        .clock(clock),
        .reset(reset),
        .fu_alu_packet(fu_alu_packet),
        .fu_mult_packet(fu_mult_packet),
        .fu_load_packet(fu_load_packet),
        .fu_store_packet(fu_store_packet),
        .alu_avail(alu_avail),
        .mult_avail(mult_avail),
        .load_avail(load_avail),
        .store_avail(store_avail),
        .cond_rob_packet(cond_rob_packet),
        .fu_state_packet(fu_state_packet)
    );
    cdb cdb_inst(
        .clock(clock),
        .reset(reset),
        .fu_state_packet(fu_state_packet),
        .alu_avail(alu_avail),
        .mult_avail(mult_avail),
        .load_avail(load_avail),
        .fu_rob_packet(cdb_rob_packet),
        .cdb_output(cdb_output)
    );

    assign fu_rob_packet = {cond_rob_packet, cdb_rob_packet};
endmodule
