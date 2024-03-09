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
    output logic take,
    // TODO: 
);
endmodule

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
    output FU_ROB_ALU_PACKET [`NUM_FU_ALU-1:0]  fu_rob_alu_packet,
    output FU_ROB_PACKET [`NUM_FU_MULT-1:0] fu_rob_mult_packet,
    output FU_ROB_PACKET [`NUM_FU_LOAD-1:0] fu_rob_load_packet,
    output FU_ROB_PACKET [`NUM_FU_STORE-1:0] fu_rob_store_packet,
    output CDB_PACKET [`CDB_SZ-1:0] cdb_packet
);


endmodule