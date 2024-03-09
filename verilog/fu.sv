`include "sys_defs.svh"
`define DEBUG_OUT


// ALU: computes the result of FUNC applied with operands A and B
// This module is purely combinational
module alu (
    input DATA opa,
    input DATA opb,
    ALU_FUNC   func,

    output DATA result
);

    logic signed [31:0]   signed_opa, signed_opb;

    assign signed_opa   = opa;
    assign signed_opb   = opb;

    always_comb begin
        case (func)
            ALU_ADD:    result = opa + opb;
            ALU_SUB:    result = opa - opb;
            ALU_AND:    result = opa & opb;
            ALU_SLT:    result = signed_opa < signed_opb;
            ALU_SLTU:   result = opa < opb;
            ALU_OR:     result = opa | opb;
            ALU_XOR:    result = opa ^ opb;
            ALU_SRL:    result = opa >> opb[4:0];
            ALU_SLL:    result = opa << opb[4:0];
            ALU_SRA:    result = signed_opa >>> opb[4:0]; // arithmetic from logical shift
            default:    result = 32'hfacebeec;  // here to prevent latches
        endcase
    end
endmodule // alu

// Conditional branch module: compute whether to take conditional branches
// This module is purely combinational
module conditional_branch (
    input [2:0] func, // Specifies which condition to check
    input DATA  rs1,  // Value to check against condition
    input DATA  rs2,

    output logic take // True/False condition result
);

    logic signed [31:0] signed_rs1, signed_rs2;
    assign signed_rs1 = rs1;
    assign signed_rs2 = rs2;
    always_comb begin
        case (func)
            3'b000:  take = signed_rs1 == signed_rs2; // BEQ
            3'b001:  take = signed_rs1 != signed_rs2; // BNE
            3'b100:  take = signed_rs1 <  signed_rs2; // BLT
            3'b101:  take = signed_rs1 >= signed_rs2; // BGE
            3'b110:  take = rs1 <  rs2;               // BLTU
            3'b111:  take = rs1 >= rs2;               // BGEU
            default: take = `FALSE;
        endcase
    end

endmodule // conditional_branch

module alu_cond (
    input FU_PACKET fu_alu_packet,
    output logic valid
    output logic take_branch,
    output DATA alu_result,
    output PRN dest_prn,
    output ROBN robn
);
    assign valid = fu_alu_packet.valid;
    assign dest_prn = fu_alu_packet.dest_prn;
    assign robn = fu_alu_packet.robn;
    assign take_branch = fu_alu_packet.uncond_branch || (fu_alu_packet.cond_branch && take_conditional);

    DATA opa_mux_out, opb_mux_out;
    logic take_conditional;
    // ALU opA mux
    always_comb begin
        case (fu_alu_packet.opa_select)
            OPA_IS_RS1:  opa_mux_out = fu_alu_packet.op1;
            OPA_IS_PC:   opa_mux_out = fu_alu_packet.PC;
            OPA_IS_ZERO: opa_mux_out = 0;
            default:     opa_mux_out = 32'hdeadface; // dead face
        endcase
    end

    // ALU opB mux
    always_comb begin
        case (fu_alu_packet.opb_select)
            OPB_IS_RS2:   opb_mux_out = fu_alu_packet.op2;
            OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(fu_alu_packet.inst);
            OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(fu_alu_packet.inst);
            OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(fu_alu_packet.inst);
            OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(fu_alu_packet.inst);
            OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(fu_alu_packet.inst);
            default:      opb_mux_out = 32'hfacefeed; // face feed
        endcase
    end

    alu alu_0 (
        // Inputs
        .opa(opa_mux_out),
        .opb(opb_mux_out),
        .func(fu_alu_packet.func),

        // Output
        .result(alu_result)
    );

    conditional_branch conditional_branch_0 (
        // Inputs
        .func(fu_alu_packet.inst.b.funct3),
        .rs1(fu_alu_packet.op1),
        .rs2(fu_alu_packet.op2),

        // Output
        .take(take_conditional)
    );

endmodule

module mult (
    input FU_PACKET fu_mult_packet,
    output logic valid,
    output DATA mult_result,
    output PRN dest_prn,
    output ROBN robn
);
    
endmodule

/*
typedef struct packed {
    logic   valid;
    INST    inst;
    ADDR    PC;
    FU_FUNC func;
    DATA    op1, op2;
    PRN     dest_prn;
    ROBN    robn;
    ALU_OPA_SELECT opa_select; // used for select signal in FU
    ALU_OPB_SELECT opb_select; // same as above
    logic    cond_branch;   // Is inst a conditional branch?
    logic    uncond_branch; // Is inst an unconditional branch?
} FU_PACKET

typedef struct packed {
    logic valid;
    PRN   dest_prn;
    DATA  value;
} CDB_PACKET;

typedef struct packed {
    ROBN  robn;
    logic executed;
    logic branch_taken;
    ADDR target_addr;
} FU_ROB_PACKET;
*/


module fu #(

)(
    input clock, reset,
    input FU_PACKET [`NUM_FU_ALU-1:0] fu_alu_packet,
    input FU_PACKET [`NUM_FU_MULT-1:0] fu_mult_packet,
    input FU_PACKET [`NUM_FU_LOAD-1:0] fu_load_packet,
    input FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet,
    output logic [`NUM_FU_ALU-1:0]   fu_alu_avail,
    output logic [`NUM_FU_MULT-1:0]  fu_mult_avail,
    output logic [`NUM_FU_LOAD-1:0]  fu_load_avail,
    output logic [`NUM_FU_STORE-1:0] fu_store_avail,
    output FU_ROB_PACKET [`CDB_SZ-1:0] fu_rob_packet,
    output CDB_PACKET [`CDB_SZ-1:0] cdb_packet
);


endmodule