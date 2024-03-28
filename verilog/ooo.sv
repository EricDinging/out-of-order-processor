`include "sys_defs.svh"
// fu_cdb, prf, rat, rrat, rob, rs
// decoder output - ooo: rob, rs, rat
// output: rs, rob almost_full
// rob: ROB_IF_PACKET
module ooo # (

)(
    input clock, reset,

    input ID_OOO_PACKET id_ooo_packet,

    output logic         structural_hazard,
    output logic         squash,
    output ROB_IF_PACKET rob_if_packet,
    output OOO_CT_PACKET ooo_ct_packet
);

    RS_IS_PACKET rs_is_packet;
    logic        rs_almost_full;

    ROB_IS_PACKET               rob_is_packet;
    logic                       rob_almost_full;
    ROB_CT_PACKET               rob_ct_packet;
    ROBN          [`N-1:0]      rob_tail_entries;

    RAT_IS_OUTPUT rat_is_output;

    RRAT_CT_INPUT  rrat_ct_input;
    RRAT_CT_OUTPUT rrat_ct_output;

    PRF_ENTRY [2*`N-1:0] prf_output_value; // prf output, used to calculate rs input
    PRN       [2*`N-1:0] read_prn;         // prn input, given by rat output
    PRN       [`N-1:0]   prn_invalid;      // prf input, given by rat output
    PRF_WRITE [`N-1:0]   prn_write_data;   // prf input, given by rob output

    // output of fu_cdb, connect to rob
    FU_ROB_PACKET [`FU_ROB_PACKET_SZ-1:0]   fu_rob_packet;

    // connecting rs and FU
    FU_PACKET [`NUM_FU_ALU-1:0]   fu_alu_packet;
    FU_PACKET [`NUM_FU_MULT-1:0]  fu_mult_packet;
    FU_PACKET [`NUM_FU_LOAD-1:0]  fu_load_packet;
    FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet;
    
    // output of fu_cdb, connect to rs
    logic [`NUM_FU_ALU-1:0]   alu_avail;
    logic [`NUM_FU_MULT-1:0]  mult_avail;
    logic [`NUM_FU_LOAD-1:0]  load_avail;
    logic [`NUM_FU_STORE-1:0] store_avail;

    // cdb output
    CDB_PACKET    [`N-1:0] cdb_packet;

    // prf input, connect to cpu output
    PRN [`N-1:0] wb_read_prn;

    rs rs_inst(
        .clock(clock),
        .reset(reset || squash),
        .rs_is_packet(rs_is_packet),
        .cdb_packet(cdb_packet),
        .fu_alu_avail(alu_avail),
        .fu_mult_avail(mult_avail),
        .fu_load_avail(load_avail),
        .fu_store_avail(store_avail),
        // output
        .fu_alu_packet(fu_alu_packet),
        .fu_mult_packet(fu_mult_packet),
        .fu_load_packet(fu_load_packet),
        .fu_store_packet(fu_store_packet),
        .almost_full(rs_almost_full)
    );

    fu_cdb fu_cdb_inst(
        .clock(clock),
        .reset(reset || squash),
        .fu_alu_packet(fu_alu_packet),
        .fu_mult_packet(fu_mult_packet),
        .fu_load_packet(fu_load_packet),
        .fu_store_packet(fu_store_packet),
        .alu_avail(alu_avail),
        .mult_avail(mult_avail),
        .load_avail(load_avail),
        .store_avail(store_avail),
        .fu_rob_packet(fu_rob_packet),
        .cdb_output(cdb_packet)
    );

    prf prf_inst(
        .clock(clock),
        .reset(reset),
        .read_prn(read_prn),
        .output_value(prf_output_value),
        .write_data(prn_write_data),
        .prn_invalid(prn_invalid),
        .wb_read_prn(wb_read_prn),
        .wb_prf_out(ooo_ct_packet.wr_data)
    );

    rob rob_inst (
        .clock(clock),
        .reset(reset),
        .rob_is_packet(rob_is_packet),
        .fu_rob_packet(fu_rob_packet),
        // output
        .almost_full(rob_almost_full),
        .rob_ct_packet(rob_ct_packet),
        .tail_entries(rob_tail_entries),
        .squash(squash)
    ); 

    rat rat_inst(
        .clock(clock),
        .reset(reset),
        .rat_is_input(id_ooo_packet.rat_is_input),
        .rrat_ct_output(rrat_ct_output),
        // output
        .rat_is_output(rat_is_output)
    );

    rrat rrat_inst(
        .clock(clock),
        .reset(reset),
        .rrat_ct_input(rrat_ct_input),
        // output
        .rrat_ct_output(rrat_ct_output)
    );

    always_comb begin
        // issue

        // rob input
        rob_is_packet = id_ooo_packet.rob_is_packet;
        for (int i = 0; i < `N; ++i) begin
            rob_is_packet.entries[i].dest_prn = rat_is_output.entries[i].dest_prn;
        end

        // rs input
        for (int i = 0; i < `N; ++i) begin
            // consecutive prf entry belongs to the same insn
            rs_is_packet.entries[i].op1_ready = prf_output_value[2*i].valid; // || id_ooo_packet.id_rs_packet[i].op1_ready;
            rs_is_packet.entries[i].op1       =
                prf_output_value[2*i].valid ? prf_output_value[2*i].value : rat_is_output.entries[i].op1_prn;
            rs_is_packet.entries[i].op2_ready = prf_output_value[2*i+1].valid; // || id_ooo_packet.id_rs_packet[i].op2_ready;
            rs_is_packet.entries[i].op2       =
                prf_output_value[2*i+1].valid ? prf_output_value[2*i+1].value : rat_is_output.entries[i].op2_prn;
            
            rs_is_packet.entries[i].inst  = id_ooo_packet.id_rs_packet[i].inst;
            rs_is_packet.entries[i].valid = id_ooo_packet.id_rs_packet[i].valid;
            rs_is_packet.entries[i].PC    = id_ooo_packet.id_rs_packet[i].PC;
            rs_is_packet.entries[i].fu    = id_ooo_packet.id_rs_packet[i].fu;
            rs_is_packet.entries[i].func  = id_ooo_packet.id_rs_packet[i].func;

            rs_is_packet.entries[i].opa_select    = id_ooo_packet.id_rs_packet[i].opa_select;
            rs_is_packet.entries[i].opb_select    = id_ooo_packet.id_rs_packet[i].opb_select;
            rs_is_packet.entries[i].cond_branch   = id_ooo_packet.id_rs_packet[i].cond_branch;
            rs_is_packet.entries[i].uncond_branch = id_ooo_packet.id_rs_packet[i].uncond_branch;

            rs_is_packet.entries[i].dest_prn = rat_is_output.entries[i].dest_prn;
            rs_is_packet.entries[i].robn     = rob_tail_entries[i];
        end

        // commit
        for (int i = 0; i < `N; ++i) begin
            rrat_ct_input.arns[i]    = rob_ct_packet.entries[i].dest_arn;
            rrat_ct_input.success[i] = rob_ct_packet.entries[i].success;

            rob_if_packet.entries[i].success        = rob_ct_packet.entries[i].success;
            rob_if_packet.entries[i].predict_taken  = rob_ct_packet.entries[i].predict_taken;
            rob_if_packet.entries[i].predict_target = rob_ct_packet.entries[i].predict_target;
            rob_if_packet.entries[i].resolve_taken  = rob_ct_packet.entries[i].resolve_taken;
            rob_if_packet.entries[i].resolve_target = rob_ct_packet.entries[i].resolve_target;
        end

        // prf input
        for (int i = 0; i < `N; ++i) begin
            prn_invalid[i]  = rat_is_output.entries[i].dest_prn; // TODO
            read_prn[2*i]   = rat_is_output.entries[i].op1_prn;
            read_prn[2*i+1] = rat_is_output.entries[i].op2_prn;
            prn_write_data[i].value = cdb_packet[i].value;
            prn_write_data[i].prn   = cdb_packet[i].dest_prn;
        end

        // rob ct output
        ooo_ct_packet.completed_inst = 0;
        for (int i = 0; i < `N; ++i) begin
            ooo_ct_packet.completed_inst += rob_ct_packet.entries[i].executed;
            ooo_ct_packet.exception_code[i] = 
                rob_ct_packet.entries[i].illegal ? ILLEGAL_INST :
                rob_ct_packet.entries[i].halt    ? HALTED_ON_WFI : NO_ERROR;
            wb_read_prn[i]          = rob_ct_packet.entries[i].dest_prn;
            ooo_ct_packet.wr_idx[i] = rob_ct_packet.entries[i].dest_arn;
            ooo_ct_packet.wr_en[i]  = ooo_ct_packet.wr_idx[i] != `ZERO_REG;
            // ooo_ct_packet.wr_en[i]  = `TRUE; // debug
            ooo_ct_packet.NPC[i]    = rob_ct_packet.entries[i].NPC;
        end
    end

    assign structural_hazard = rs_almost_full || rob_almost_full;

endmodule
