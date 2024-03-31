`include "sys_defs.svh"
`include "ISA.svh"


// ALU: computes the result of FUNC applied with operands A and B
// This module is purely combinational
module alu (
    input DATA opa,
    input DATA opb,
    input ALU_FUNC   func,

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
    input logic clock, reset, // unused, purely combinational
    input FU_PACKET fu_alu_packet,
    input logic avail, // unused, purely combinational
    output logic prepared,
    output FU_STATE_ALU_PACKET fu_state_alu_packet
);
    assign prepared = fu_alu_packet.valid;
    assign fu_state_alu_packet.basic.dest_prn = fu_alu_packet.dest_prn;
    assign fu_state_alu_packet.basic.robn = fu_alu_packet.robn;
    assign fu_state_alu_packet.cond_branch = fu_alu_packet.cond_branch;
    assign fu_state_alu_packet.uncond_branch = fu_alu_packet.uncond_branch;

    logic internal_take;
    DATA opa_mux_out, opb_mux_out;
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

    assign fu_state_alu_packet.take_branch = fu_alu_packet.uncond_branch || (fu_alu_packet.cond_branch && internal_take);
    alu alu_0 (
        // Inputs
        .opa(opa_mux_out),
        .opb(opb_mux_out),
        .func(fu_alu_packet.func.alu),

        // Output
        .result(fu_state_alu_packet.basic.result)
    );

    conditional_branch conditional_branch_0 (
        // Inputs
        .func(fu_alu_packet.inst.b.funct3),
        .rs1(fu_alu_packet.op1),
        .rs2(fu_alu_packet.op2),

        // Output
        .take(internal_take)
    );

endmodule

module mult_impl (
    input logic clock, reset,
    input FU_PACKET fu_mult_packet,
    input logic avail,
    output logic prepared,
    output FU_STATE_BASIC_PACKET fu_state_mult_packet
);
    
    DATA opa_mux_out, opb_mux_out;
    // ALU opA mux
    always_comb begin
        case (fu_mult_packet.opa_select)
            OPA_IS_RS1:  opa_mux_out = fu_mult_packet.op1;
            OPA_IS_PC:   opa_mux_out = fu_mult_packet.PC;
            OPA_IS_ZERO: opa_mux_out = 0;
            default:     opa_mux_out = 32'hdeadface; // dead face
        endcase
    end

    // ALU opB mux
    always_comb begin
        case (fu_mult_packet.opb_select)
            OPB_IS_RS2:   opb_mux_out = fu_mult_packet.op2;
            OPB_IS_I_IMM: opb_mux_out = `RV32_signext_Iimm(fu_mult_packet.inst);
            OPB_IS_S_IMM: opb_mux_out = `RV32_signext_Simm(fu_mult_packet.inst);
            OPB_IS_B_IMM: opb_mux_out = `RV32_signext_Bimm(fu_mult_packet.inst);
            OPB_IS_U_IMM: opb_mux_out = `RV32_signext_Uimm(fu_mult_packet.inst);
            OPB_IS_J_IMM: opb_mux_out = `RV32_signext_Jimm(fu_mult_packet.inst);
            default:      opb_mux_out = 32'hfacefeed; // face feed
        endcase
    end

    mult multiplier (
        .clock(clock),
        .reset(reset),

        // input
        .start(fu_mult_packet.valid), // read into the state
        // note that valid is not related to avail
        // they are one cycle off -- another state register within the rs
        .avail(avail), // simply stall all the state registers
        .rs1(opa_mux_out),
        .rs2(opb_mux_out),
        .func(fu_mult_packet.func.mult),
        .robn(fu_mult_packet.robn),
        .dest_prn(fu_mult_packet.dest_prn),

        // output
        .result(fu_state_mult_packet.result),
        .output_robn(fu_state_mult_packet.robn),
        .output_dest_prn(fu_state_mult_packet.dest_prn),
        .done(prepared)
    );
endmodule

module load (
    input logic clock, reset,
    input FU_PACKET fu_load_packet,
    input logic avail,
    output logic prepared,
    output FU_STATE_BASIC_PACKET fu_state_load_packet
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
    logic cond_branch;
    logic uncond_branch;
} FU_PACKET;

typedef struct packed {
    PRN   dest_prn;
    DATA  value;
} CDB_PACKET;

typedef struct packed {
    ROBN  robn;
    logic executed;
    logic branch_taken;
    ADDR target_addr;
} FU_ROB_PACKET;

typedef struct packed {
    ROBN robn;
    PRN dest_prn;
    DATA result;
} FU_STATE_BASIC_PACKET;

typedef struct packed {
    FU_STATE_BASIC_PACKET basic;
    logic take_branch;
    logic cond_branch;
    logic uncond_branch;
    ADDR PC;
} FU_STATE_ALU_PACKET;

typedef struct packed {
    logic [`NUM_FU_ALU-1:0] alu_prepared;
    FU_STATE_ALU_PACKET   [`NUM_FU_ALU-1:0] alu_packet;
    logic [`NUM_FU_MULT-1:0] mult_prepared;
    FU_STATE_BASIC_PACKET [`NUM_FU_MULT-1:0] mult_packet;
    logic [`NUM_FU_LOAD-1:0] load_prepared;
    FU_STATE_BASIC_PACKET [`NUM_FU_LOAD-1:0] load_packet;
} FU_STATE_PACKET;
*/


module fu #(

)(
    input clock, reset,
    input FU_PACKET [`NUM_FU_ALU-1:0]   fu_alu_packet,
    input FU_PACKET [`NUM_FU_MULT-1:0]  fu_mult_packet,
    input FU_PACKET [`NUM_FU_LOAD-1:0]  fu_load_packet,
    input FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet,

    // given back from priority selector
    input logic [`NUM_FU_ALU-1:0]  alu_avail,
    input logic [`NUM_FU_MULT-1:0] mult_avail,
    input logic [`NUM_FU_LOAD-1:0] load_avail,

    // TODO: packet for store, to rob and maybe prf
    // tell rs whether it the next value will be accepted
    output logic           [`NUM_FU_STORE-1:0] store_avail,
    output FU_ROB_PACKET   [`NUM_FU_ALU-1:0]   cond_rob_packet,
    output FU_STATE_PACKET                     fu_state_packet
);

    alu_cond alu_components [`NUM_FU_ALU-1:0] (
        .clock(clock), // not needed for 1-cycle alu
        .reset(reset), // not needed for 1-cycle alu
        .fu_alu_packet(fu_alu_packet),
        .avail(alu_avail), // not needed for 1-cycle alu
        //output
        .prepared(fu_state_packet.alu_prepared),
        .fu_state_alu_packet(fu_state_packet.alu_packet)
    );

    mult_impl mult_components [`NUM_FU_MULT-1:0] (
        .clock(clock),
        .reset(reset),
        .fu_mult_packet(fu_mult_packet),
        .avail(mult_avail),
        //output
        .prepared(fu_state_packet.mult_prepared),
        .fu_state_mult_packet(fu_state_packet.mult_packet)
    );

    load load_components [`NUM_FU_LOAD-1:0] (
        .clock(clock),
        .reset(reset),
        .fu_load_packet(fu_load_packet),
        .avail(load_avail),
        //output
        .prepared(fu_state_packet.load_prepared),
        .fu_state_load_packet(fu_state_packet.load_packet)
    );

    // TODO store

    always_comb begin
        store_avail = {`NUM_FU_STORE{1'b0}};
        
        for (int i = 0; i < `NUM_FU_ALU; i++) begin
            cond_rob_packet[i].robn         = fu_state_packet.alu_packet[i].basic.robn;
            cond_rob_packet[i].executed     = fu_state_packet.alu_prepared[i] && fu_state_packet.alu_packet[i].cond_branch;
            cond_rob_packet[i].branch_taken = fu_state_packet.alu_packet[i].take_branch;
            cond_rob_packet[i].target_addr  = fu_state_packet.alu_packet[i].basic.result;
        end
    end

endmodule


/*
typedef struct packed {
    ROBN  robn;
    logic executed;
    logic branch_taken;
    ADDR target_addr;
} FU_ROB_PACKET;
*/
