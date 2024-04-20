`include "sys_defs.svh"
`include "ISA.svh"
// `define CPU_DEBUG_OUT

// ALU: computes the result of FUNC applied with operands A and B
// This module is purely combinational
module alu (
    input DATA     opa,
    input DATA     opb,
    input ALU_FUNC func,

    output DATA result
);

    logic signed [31:0] signed_opa, signed_opb;

    assign signed_opa = opa;
    assign signed_opb = opb;

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
    input  logic clock, reset, // unused, purely combinational
    input  FU_PACKET fu_alu_packet,
    input  logic avail, // unused, purely combinational
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
    assign fu_state_alu_packet.NPC = fu_alu_packet.PC + 4;
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


module fu #(

)(
    input clock, reset,
    input squash,
    input FU_PACKET [`NUM_FU_ALU-1:0]   fu_alu_packet,
    input FU_PACKET [`NUM_FU_MULT-1:0]  fu_mult_packet,
    input FU_PACKET [`NUM_FU_LOAD-1:0]  fu_load_packet,
    input FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet,

    // From memory to dcache
    input MEM_TAG   Dmem2proc_transaction_tag,
    input MEM_BLOCK Dmem2proc_data,
    input MEM_TAG   Dmem2proc_data_tag,

    // given back from priority selector
    input logic  [`NUM_FU_ALU-1:0]  alu_avail,
    input logic  [`NUM_FU_MULT-1:0] mult_avail,
    input logic  [`NUM_FU_LOAD-1:0] load_avail,
    output logic [`NUM_FU_LOAD-1:0] load_rs_avail,

    // store_queue
    input ID_SQ_PACKET [`N-1:0]            id_sq_packet,
    input SQ_IDX                   rob_num_commit_insns,

    // tell rs whether the next value will be accepted
    output logic           [`NUM_FU_STORE-1:0] store_avail,
    output SQ_IDX                              sq_head,
    output SQ_IDX                              sq_tail,
    output SQ_IDX                              sq_tail_ready,
    output logic                               sq_almost_full,
    output SQ_IDX                              sq_num_sent_insns,
    output FU_ROB_PACKET   [`NUM_FU_ALU-1:0]   cond_rob_packet,
    output FU_STATE_PACKET                     fu_state_packet,
    // To memory from dcache
    output MEM_COMMAND proc2Dmem_command,
    output ADDR        proc2Dmem_addr,
    output MEM_BLOCK   proc2Dmem_data,
    // To icache from dcache
    output logic       dcache_request,
    output DMSHR_ENTRY    [`DMSHR_SIZE-1:0]   dmshr_entries_debug,
    output DMSHR_Q_PACKET [`DMSHR_SIZE-1:0][`N-1:0] dmshr_q_debug,
    output DCACHE_ENTRY     [`DCACHE_LINES-1:0] dcache_data_debug,
    output SQ_ENTRY [(`SQ_LEN+1)-1:0] sq_entries_debug,
    output SQ_IDX                     sq_commit_head_debug,
    output SQ_IDX                     sq_commit_tail_debug
`ifdef CPU_DEBUG_OUT
    , output logic            [`DMSHR_SIZE-1:0][`N_CNT_WIDTH-1:0] counter_debug
    , output LQ_DCACHE_PACKET [`NUM_LU_DCACHE-1:0] lq_dcache_packet_debug
    , output LD_ENTRY         [`NUM_FU_LOAD-1:0]   lq_entries_out
    , output RS_LQ_PACKET     [`NUM_FU_LOAD-1:0]   rs_lq_packet_debug
    , output LU_REG           [`NUM_FU_LOAD-1:0]   lu_reg_debug
    , output LU_FWD_REG       [`NUM_FU_LOAD-1:0]   lu_fwd_reg_debug
    , output logic            [`NUM_FU_LOAD-1:0]   load_req_data_valid_debug
    , output DATA             [`NUM_FU_LOAD-1:0]   load_req_data_debug
    , output SQ_DCACHE_PACKET [`NUM_SQ_DCACHE-1:0] sq_dcache_packet_debug
    , output logic [`N-1:0] store_req_accept_debug
    , output logic [`N-1:0] load_req_accept_debug
    , output DCACHE_LQ_PACKET [`N-1:0] dcache_lq_packet_debug
`endif
);
    
    RS_SQ_PACKET [`NUM_FU_STORE-1:0] rs_sq_packet;

    // store_queue and load_queue
    ADDR     [`NUM_FU_LOAD-1:0] addr;
    SQ_IDX   [`NUM_FU_LOAD-1:0] tail_store;
    MEM_FUNC [`NUM_FU_LOAD-1:0] load_byte_info;
    DATA     [`NUM_FU_LOAD-1:0] value;
    logic    [`NUM_FU_LOAD-1:0] fwd_valid;
    SQ_DCACHE_PACKET [`NUM_SQ_DCACHE-1:0] sq_dcache_packet;
    logic            [`NUM_SQ_DCACHE-1:0] dcache_sq_accept;
    // load queue - dcache
    DCACHE_LQ_PACKET [`N-1:0]             dcache_lq_packet;
    logic            [`NUM_LU_DCACHE-1:0] load_req_accept;
    DATA             [`NUM_LU_DCACHE-1:0] load_req_data;
    logic            [`NUM_LU_DCACHE-1:0] load_req_data_valid;
    LQ_DCACHE_PACKET [`NUM_LU_DCACHE-1:0] lq_dcache_packet;

    logic    [`NUM_FU_LOAD-1:0][3:0] forwarded;

    genvar i;
    generate
        for (i = 0; i < `NUM_FU_STORE; ++i) begin
            assign rs_sq_packet[i] = '{
                fu_store_packet[i].valid,                      // valid
                fu_store_packet[i].op1,                        // base
                {fu_store_packet[i].inst.s.off, fu_store_packet[i].inst.s.set}, // offset
                fu_store_packet[i].op2,                        // data
                fu_store_packet[i].sq_idx                      // sq_idx
            };
        end
    endgenerate

    RS_LQ_PACKET [`NUM_FU_LOAD-1:0] rs_lq_packet;
    generate
        for (i = 0; i < `NUM_FU_LOAD; ++i) begin
            assign rs_lq_packet[i] = '{
                fu_load_packet[i].valid,    // logic valid;
                fu_load_packet[i].mem_func, // MEM_FUNC sign_size;
                fu_load_packet[i].op1,      // ADDR base;
                fu_load_packet[i].inst.i.imm, // logic [11:0] offset;
                fu_load_packet[i].dest_prn, // PRN prn;
                fu_load_packet[i].robn,     // ROBN robn;
                fu_load_packet[i].sq_idx    // SQ_IDX   tail_store;
            };
        end
    endgenerate
    `ifdef CPU_DEBUG_OUT
        assign rs_lq_packet_debug = rs_lq_packet;
        assign sq_dcache_packet_debug = sq_dcache_packet;
        assign dcache_lq_packet_debug = dcache_lq_packet;
    `endif

    dcache cache (
        .clock(clock),
        .reset(reset),
        .squash(squash),
        // from memory
        .Dmem2proc_transaction_tag(Dmem2proc_transaction_tag),
        .Dmem2proc_data(Dmem2proc_data),
        .Dmem2proc_data_tag(Dmem2proc_data_tag),
        // from lsq
        .lq_dcache_packet(lq_dcache_packet),
        .sq_dcache_packet(sq_dcache_packet),
        // to memory
        .proc2Dmem_command(proc2Dmem_command),
        .proc2Dmem_addr(proc2Dmem_addr),
        .proc2Dmem_data(proc2Dmem_data),
        // to lsq
        .store_req_accept(dcache_sq_accept),
        .load_req_accept(load_req_accept),
        .load_req_data(load_req_data),
        .load_req_data_valid(load_req_data_valid),
        .dcache_lq_packet(dcache_lq_packet),
        // to Icache
        .dcache_request(dcache_request),
        .dcache_data_debug(dcache_data_debug),
        .dmshr_entries_debug(dmshr_entries_debug),
        .dmshr_q_debug(dmshr_q_debug)
    `ifdef CPU_DEBUG_OUT
        , .counter_debug(counter_debug)
        , .store_req_accept_debug(store_req_accept_debug)
        , .load_req_accept_debug(load_req_accept_debug)
    `endif
    );

    `ifdef CPU_DEBUG_OUT
        assign load_req_data_valid_debug = load_req_data_valid;
        assign load_req_data_debug = load_req_data;
    `endif

    alu_cond alu_components [`NUM_FU_ALU-1:0] (
        .clock(clock), // not needed for 1-cycle alu
        .reset(reset || squash), // not needed for 1-cycle alu
        .fu_alu_packet(fu_alu_packet),
        .avail(alu_avail), // not needed for 1-cycle alu
        //output
        .prepared(fu_state_packet.alu_prepared),
        .fu_state_alu_packet(fu_state_packet.alu_packet)
    );

    mult_impl mult_components [`NUM_FU_MULT-1:0] (
        .clock(clock),
        .reset(reset || squash),
        .fu_mult_packet(fu_mult_packet),
        .avail(mult_avail),
        //output
        .prepared(fu_state_packet.mult_prepared),
        .fu_state_mult_packet(fu_state_packet.mult_packet)
    );
 
    store_queue store_component (
        .clock(clock),
        .reset(reset),
        .squash(squash),
        // id
        .id_sq_packet(id_sq_packet),
        .almost_full(sq_almost_full),
        // rs
        .rs_sq_packet(rs_sq_packet),
        // rob
        .num_commit_insns(rob_num_commit_insns),
        .num_sent_insns(sq_num_sent_insns),
        // dcache
        .sq_dcache_packet(sq_dcache_packet),
        .dcache_accept(dcache_sq_accept),
        // rs for load
        .head(sq_head),
        .tail(sq_tail),
        .tail_ready(sq_tail_ready),
        // lq
        .addr(addr),
        .tail_store(tail_store),
        .load_byte_info(load_byte_info),
        .value(value),
        .fwd_valid(fwd_valid),
        .forwarded(forwarded),
        .sq_entries_debug(sq_entries_debug),
        .sq_commit_head_debug(sq_commit_head_debug),
        .sq_commit_tail_debug(sq_commit_tail_debug)
    `ifdef CPU_DEBUG_OUT
    `endif
    );

    load_queue load_unit (
        .clock(clock),
        .reset(reset || squash),
        // rs
        .rs_lq_packet(rs_lq_packet),
        .load_rs_avail(load_rs_avail),
        // cdb
        .load_avail(load_avail),
        .load_prepared(fu_state_packet.load_prepared),
        .load_packet(fu_state_packet.load_packet),
        // sq
        .sq_addr(addr),
        .store_range(tail_store),
        .load_byte_info(load_byte_info),
        .value(value),
        .fwd_valid(fwd_valid),
        .forwarded(forwarded),
        // Dcache
        .dcache_lq_packet(dcache_lq_packet),
        .load_req_accept(load_req_accept),
        .load_req_data(load_req_data),
        .load_req_data_valid(load_req_data_valid),
        .lq_dcache_packet(lq_dcache_packet)
    `ifdef CPU_DEBUG_OUT
        , .entries_out(lq_entries_out)
        , .lu_reg_debug(lu_reg_debug)
        , .lu_fwd_reg_debug(lu_fwd_reg_debug)
    `endif
    );
    
    `ifdef CPU_DEBUG_OUT
        assign lq_dcache_packet_debug = lq_dcache_packet;
    `endif

    always_comb begin
        store_avail = {`NUM_FU_STORE{`TRUE}};
        
        for (int i = 0; i < `NUM_FU_ALU; i++) begin
            cond_rob_packet[i].robn         = fu_state_packet.alu_packet[i].basic.robn;
            cond_rob_packet[i].executed     = fu_state_packet.alu_prepared[i] && fu_state_packet.alu_packet[i].cond_branch;
            cond_rob_packet[i].branch_taken = fu_state_packet.alu_packet[i].take_branch;
            cond_rob_packet[i].target_addr  = fu_state_packet.alu_packet[i].basic.result;
        end
    end

endmodule
