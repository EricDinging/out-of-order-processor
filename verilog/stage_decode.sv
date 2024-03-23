`include "sys_defs.svh"

module stage_decode #(
    // nothing
) (
    input IF_ID_PACKET [`N-1:0] if_id_packet,

    output ID_OOO_PACKET id_ooo_packet
);

    ALU_OPA_SELECT [`N-1:0] opa_select;
    ALU_OPB_SELECT [`N-1:0] opb_select;
    logic          [`N-1:0] has_dest;
    FU_TYPE        [`N-1:0] fu;
    FU_FUNC        [`N-1:0] fu_func;
    logic          [`N-1:0] cond_branch, uncond_branch;
    logic          [`N-1:0] csr_op, halt, illegal;
    
    genvar i;

    generate
        for (i = 0; i < `N; ++i) begin
            decoder dec (
                // input
                .inst  (if_id_packet[i].inst),
                .valid (if_id_packet[i].valid),
                // output
                .opa_select    (opa_select[i]),
                .opb_select    (opb_select[i]),
                .has_dest      (has_dest[i]),
                .fu            (fu[i]),
                .fu_func       (fu_func[i]),
                .cond_branch   (cond_branch[i]),
                .uncond_branch (uncond_branch[i]),
                .csr_op        (csr_op[i]),
                .halt          (halt[i]),
                .illegal       (illegal[i])
            );
        end
    endgenerate

    generate
        for (i = 0; i < `N; ++i) begin
            // rs
            id_ooo_packet.id_rs_packet[i].inst          = if_id_packet[i].inst;
            id_ooo_packet.id_rs_packet[i].valid         = if_id_packet[i].valid;
            id_ooo_packet.id_rs_packet[i].PC            = if_id_packet[i].PC;
            id_ooo_packet.id_rs_packet[i].fu            = fu[i];
            id_ooo_packet.id_rs_packet[i].func          = fu_func[i];
            id_ooo_packet.id_rs_packet[i].opa_select    = opa_select[i];
            id_ooo_packet.id_rs_packet[i].opb_select    = opb_select[i];
            id_ooo_packet.id_rs_packet[i].cond_branch   = cond_branch[i];
            id_ooo_packet.id_rs_packet[i].uncond_branch = uncond_branch[i];
            // rob
            id_ooo_packet.rob_is_packet.valid[i] = if_id_packet[i].valid;

            id_ooo_packet.rob_is_packet.entries[i].executed       = `FALSE;
            id_ooo_packet.rob_is_packet.entries[i].success        = `TRUE;
            id_ooo_packet.rob_is_packet.entries[i].is_store       = fu[i] == FU_STORE;
            id_ooo_packet.rob_is_packet.entries[i].cond_branch    = cond_branch[i];
            id_ooo_packet.rob_is_packet.entries[i].uncond_branch  = uncond_branch[i];
            id_ooo_packet.rob_is_packet.entries[i].resolve_taken  = `FALSE;
            id_ooo_packet.rob_is_packet.entries[i].predict_taken  = if_id_packet[i].predict_taken;
            id_ooo_packet.rob_is_packet.entries[i].predict_target = if_id_packet[i].predict_target;
            id_ooo_packet.rob_is_packet.entries[i].resolve_target = 32'hB0BACAFE;  // undefined
            id_ooo_packet.rob_is_packet.entries[i].dest_prn       = 0;             // undefined
            id_ooo_packet.rob_is_packet.entries[i].dest_arn       = has_dest[i] ? if_id_packet[i].inst.r.rd : `ZERO_REG;
            id_ooo_packet.rob_is_packet.entries[i].PC             = if_id_packet[i].PC;
            id_ooo_packet.rob_is_packet.entries[i].NPC            = if_id_packet[i].NPC;
            id_ooo_packet.rob_is_packet.entries[i].halt           = halt[i];
            id_ooo_packet.rob_is_packet.entries[i].illegal        = illegal[i];
            id_ooo_packet.rob_is_packet.entries[i].csr_op         = csr_op[i];

            // rat
            id_ooo_packet.rat_is_input.entries[i].dest_arn =
                has_dest[i] ? if_id_packet[i].inst.r.rd : `ZERO_REG;
            id_ooo_packet.rat_is_input.entries[i].op1_arn  =
                (opa_select[i] == OPA_IS_RS1 || cond_branch[i]) ? if_id_packet[i].inst.r.rs1 : `ZERO_REG;
            id_ooo_packet.rat_is_input.entries[i].op2_arn  =
                (cond_branch[i] || opb_select[i] == OPB_IS_RS2) ? if_id_packet[i].inst.r.rs2 : `ZERO_REG;
        end
    endgenerate

endmodule
