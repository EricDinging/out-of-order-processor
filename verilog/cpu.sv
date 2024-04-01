/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  cpu.sv                                              //
//                                                                     //
//  Description :  Top-level module of the verisimple processor;       //
//                 This instantiates and connects the 5 stages of the  //
//                 Verisimple pipeline together.                       //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module cpu (
    input clock, // System clock
    input reset, // System reset

    input MEM_TAG   mem2proc_transaction_tag, // Memory tag for current transaction
    input MEM_BLOCK mem2proc_data,            // Data coming back from memory
    input MEM_TAG   mem2proc_data_tag,        // Tag for which transaction data is for

    output logic [1:0] proc2mem_command, // Command sent to memory
    output ADDR        proc2mem_addr,    // Address sent to memory
    output MEM_BLOCK   proc2mem_data,    // Data sent to memory

`ifndef CACHE_MODE // no longer sending size to memory
    output MEM_SIZE    proc2mem_size,    // Data size sent to memory
`endif

`ifdef CPU_DEBUG_OUT
    output IF_ID_PACKET  [`N-1:0] if_id_reg_debug,
    output ID_OOO_PACKET          id_ooo_reg_debug,
    output logic                  squash_debug,
    output ROB_IF_PACKET          rob_if_packet_debug,
    output CDB_PACKET    [`N-1:0] cdb_packet_debug,
    output FU_STATE_PACKET fu_state_packet_debug,
    output logic [`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD-1:0] select_debug,
    // rob
    output ROB_ENTRY [`ROB_SZ-1:0]        rob_entries_out,
    output logic     [`RS_CNT_WIDTH-1:0]  rob_counter_out,
    output logic     [`ROB_PTR_WIDTH-1:0] rob_head_out,
    output logic     [`ROB_PTR_WIDTH-1:0] rob_tail_out,
    // rs
    output RS_ENTRY  [`RS_SZ-1:0]         rs_entries_out,
    output logic     [`RS_CNT_WIDTH-1:0]  rs_counter_out,
    // prf
    output PRF_ENTRY [`PHYS_REG_SZ_R10K-1:0] prf_entries_debug,
    // rat
    output PRN                              rat_head, rat_tail,
    output logic [`FREE_LIST_CTR_WIDTH-1:0] rat_counter,
    output PRN   [`PHYS_REG_SZ_R10K-1:0]    rat_free_list,
    output PRN   [`ARCH_REG_SZ-1:0]         rat_table_out,
    // rrat
    output PRN   [`ARCH_REG_SZ-1:0]         rrat_entries,
    // fu_packet (rs output state)
    output FU_PACKET [`NUM_FU_ALU-1:0]   fu_alu_packet_debug,
    output FU_PACKET [`NUM_FU_MULT-1:0]  fu_mult_packet_debug,
    output FU_PACKET [`NUM_FU_LOAD-1:0]  fu_load_packet_debug,
    output FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet_debug,
`endif

    // Note: these are assigned at the very bottom of the module
    output logic [`N_CNT_WIDTH-1:0] pipeline_completed_insts,
    output EXCEPTION_CODE  [`N-1:0] pipeline_error_status,
    output REG_IDX         [`N-1:0] pipeline_commit_wr_idx,
    output DATA            [`N-1:0] pipeline_commit_wr_data,
    output logic           [`N-1:0] pipeline_commit_wr_en,
    output ADDR            [`N-1:0] pipeline_commit_NPC

    // Debug outputs: these signals are solely used for debugging in testbenches
    // Do not change for project 3
    // You should definitely change these for project 4
    // output ADDR  if_NPC_dbg,
    // output DATA  if_inst_dbg,
    // output logic if_valid_dbg,
    // output ADDR  if_id_NPC_dbg,
    // output DATA  if_id_inst_dbg,
    // output logic if_id_valid_dbg,
    // output ADDR  id_ex_NPC_dbg,
    // output DATA  id_ex_inst_dbg,
    // output logic id_ex_valid_dbg,
    // output ADDR  ex_mem_NPC_dbg,
    // output DATA  ex_mem_inst_dbg,
    // output logic ex_mem_valid_dbg,
    // output ADDR  mem_wb_NPC_dbg,
    // output DATA  mem_wb_inst_dbg,
    // output logic mem_wb_valid_dbg

);

    //////////////////////////////////////////////////
    //                                              //
    //                Pipeline Wires                //
    //                                              //
    //////////////////////////////////////////////////

    // Pipeline register enables
    logic if_id_enable, id_ooo_enable;

    // Outputs from IF-Stage and IF/ID Pipeline Register
    // ADDR proc2Imem_addr;
    
    IF_ID_PACKET  [`N-1:0] if_packet, if_id_reg;

    // Input to OoO
    ID_OOO_PACKET id_ooo_packet, id_ooo_reg;
    // Output from OoO
    logic         structural_hazard;
    ROB_IF_PACKET rob_if_packet;
    logic         squash;
    OOO_CT_PACKET ooo_ct_packet;

    //////////////////////////////////////////////////
    //                                              //
    //                  Stage Fetch                 //
    //                                              //
    //////////////////////////////////////////////////

    stage_fetch fetch(
        .clock(clock),
        .reset(reset),
        .stall(squash ? `FALSE : structural_hazard),
        .mem2proc_transaction_tag(mem2proc_transaction_tag),
        .mem2proc_data(mem2proc_data),
        .mem2proc_data_tag(mem2proc_data_tag),
        .rob_if_packet(rob_if_packet),
        .proc2Imem_command(proc2mem_command),
        .proc2Imem_addr(proc2mem_addr),
        .if_id_packet(if_packet)
    );

    always_ff @(posedge clock) begin
        if (reset || squash) begin
            if_id_reg <= 0;
        end else if (if_id_enable) begin
            if_id_reg <= if_packet;
        end
    end

    assign if_id_enable = !structural_hazard;

`ifdef CPU_DEBUG_OUT
    assign if_id_reg_debug = if_id_reg;
`endif

    //////////////////////////////////////////////////
    //                                              //
    //                  Stage Decode                //
    //                                              //
    //////////////////////////////////////////////////
    // squash decode
    stage_decode decode (
        .if_id_packet(if_id_reg),
        .id_ooo_packet(id_ooo_packet)
    );

    always_ff @(posedge clock) begin
        if (reset || squash) begin
            id_ooo_reg <= 0;
        end else if (id_ooo_enable) begin
            id_ooo_reg <= id_ooo_packet;
        end
    end

    assign id_ooo_enable = !structural_hazard;

`ifdef CPU_DEBUG_OUT
    assign id_ooo_reg_debug = id_ooo_reg;
`endif

    //////////////////////////////////////////////////
    //                                              //
    //                  Out of Order                //
    //                                              //
    //////////////////////////////////////////////////

    ooo ooo_inst (
        .clock(clock),
        .reset(reset),
        .id_ooo_packet(id_ooo_reg),
        .structural_hazard(structural_hazard),
        .rob_if_packet(rob_if_packet),
        .squash(squash),
        .ooo_ct_packet(ooo_ct_packet)
    `ifdef CPU_DEBUG_OUT
        , .cdb_packet_debug(cdb_packet_debug)
        , .fu_state_packet_debug(fu_state_packet_debug)
        , .select_debug(select_debug)
        // prf
        , .prf_entries_debug(prf_entries_debug)
        // rob
        , .rob_entries_out(rob_entries_out)
        , .rob_counter_out(rob_counter_out)
        , .rob_head_out(rob_head_out)
        , .rob_tail_out(rob_tail_out)
        // rs
        , .rs_entries_out(rs_entries_out)
        , .rs_counter_out(rs_counter_out)
        // rat
        , .rat_head(rat_head)
        , .rat_tail(rat_tail)
        , .rat_counter(rat_counter)
        , .rat_free_list(rat_free_list)
        , .rat_table_out(rat_table_out)
        // rrat
        , .rrat_entries(rrat_entries)
        // fu_state_packet
        , .fu_alu_packet_debug(fu_alu_packet_debug)
        , .fu_mult_packet_debug(fu_mult_packet_debug)
        , .fu_load_packet_debug(fu_load_packet_debug)
        , .fu_store_packet_debug(fu_store_packet_debug)
    `endif
    );

    // Outputs from MEM-Stage to memory
    // ADDR proc2Dmem_addr;
    // DATA proc2Dmem_data;
    // logic [1:0]  proc2Dmem_command;
    // MEM_SIZE     proc2Dmem_size;

`ifdef CPU_DEBUG_OUT
    assign squash_debug        = squash;
    assign rob_if_packet_debug = rob_if_packet;
`endif

    //////////////////////////////////////////////////
    //                                              //
    //                Memory Outputs                //
    //                                              //
    //////////////////////////////////////////////////

    // these signals go to and from the processor and memory
    // we give precedence to the mem stage over instruction fetch
    // note that there is no latency in project 3
    // but there will be a 100ns latency in project 4

//     always_comb begin
//         if (proc2Dmem_command != MEM_NONE) begin // read or write DATA from memory
//             proc2mem_command = proc2Dmem_command;
//             proc2mem_addr    = proc2Dmem_addr;
// `ifndef CACHE_MODE
//             proc2mem_size    = proc2Dmem_size;  // size is never DOUBLE in project 3
// `endif
//         end else begin                          // read an INSTRUCTION from memory
//             proc2mem_command = MEM_LOAD;
//             proc2mem_addr    = proc2Imem_addr;
// `ifndef CACHE_MODE
//             proc2mem_size    = DOUBLE;          // instructions load a full memory line (64 bits)
// `endif
//         end
//         proc2mem_data = {32'b0, proc2Dmem_data};
//     end

    //////////////////////////////////////////////////
    //                                              //
    //               Pipeline Outputs               //
    //                                              //
    //////////////////////////////////////////////////

    // assign pipeline_completed_insts = {3'b0, mem_wb_reg.valid}; // commit one valid instruction
    // assign pipeline_error_status = mem_wb_reg.illegal ? ILLEGAL_INST :
    //                                mem_wb_reg.halt    ? HALTED_ON_WFI :
    //                                (mem2proc_transaction_tag == 4'h0) ? LOAD_ACCESS_FAULT : NO_ERROR;

    // assign pipeline_commit_wr_en   = wb_regfile_en;
    // assign pipeline_commit_wr_idx  = wb_regfile_idx;
    // assign pipeline_commit_wr_data = wb_regfile_data;
    // assign pipeline_commit_NPC     = mem_wb_reg.NPC;

    assign pipeline_completed_insts = ooo_ct_packet.completed_inst;
    assign pipeline_error_status    = ooo_ct_packet.exception_code; // TODO: LOAD_ACCESS_FAULT
    assign pipeline_commit_wr_idx   = ooo_ct_packet.wr_idx;
    assign pipeline_commit_wr_data  = ooo_ct_packet.wr_data;
    assign pipeline_commit_wr_en    = ooo_ct_packet.wr_en;
    assign pipeline_commit_NPC      = ooo_ct_packet.NPC;

endmodule // pipeline
