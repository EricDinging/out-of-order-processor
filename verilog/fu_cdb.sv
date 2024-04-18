`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module fu_cdb(
    input clock, reset, squash,
    input FU_PACKET [`NUM_FU_ALU-1:0]   fu_alu_packet,
    input FU_PACKET [`NUM_FU_MULT-1:0]  fu_mult_packet,
    input FU_PACKET [`NUM_FU_LOAD-1:0]  fu_load_packet,
    input FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet,
    // store queue
    input ID_SQ_PACKET [`N-1:0]            id_sq_packet,
    input SQ_IDX                   rob_num_commit_insns,

    // From memory to dcache
    input MEM_TAG   Dmem2proc_transaction_tag,
    input MEM_BLOCK Dmem2proc_data,
    input MEM_TAG   Dmem2proc_data_tag,

    output logic         [`NUM_FU_ALU-1:0]       alu_avail,
    output logic         [`NUM_FU_MULT-1:0]      mult_avail,
    output logic         [`NUM_FU_LOAD-1:0]      load_avail,
    output logic         [`NUM_FU_STORE-1:0]     store_avail,
    output FU_ROB_PACKET [`FU_ROB_PACKET_SZ-1:0] fu_rob_packet,
    output CDB_PACKET    [`N-1:0]                cdb_output, // for both cdb and prf
    output logic                                 sq_almost_full,
    output SQ_IDX                                sq_head,
    output SQ_IDX                                sq_tail,
    output SQ_IDX                                sq_tail_ready,
    output SQ_IDX                                sq_num_sent_insns,
    // To memory from dcache
    output MEM_COMMAND proc2Dmem_command,
    output ADDR        proc2Dmem_addr,
    output MEM_BLOCK   proc2Dmem_data,
    // To icache from dcache
    output logic       dcache_request

    `ifdef CPU_DEBUG_OUT
    , output FU_STATE_PACKET fu_state_packet_debug
    , output logic [`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD-1:0] select_debug
    , output DMSHR_ENTRY [`DMSHR_SIZE-1:0] dmshr_entries_debug
    , output DCACHE_ENTRY [`DCACHE_LINES-1:0] dcache_data_debug
    , output logic [`DMSHR_SIZE-1:0][`N_CNT_WIDTH-1:0] counter_debug
    , output LQ_DCACHE_PACKET [`NUM_LU_DCACHE-1:0] lq_dcache_packet_debug
    , output LD_ENTRY [`NUM_FU_LOAD-1:0] lq_entries_out
    , output RS_LQ_PACKET [`NUM_FU_LOAD-1:0]  rs_lq_packet_debug
    , output LU_REG     [`NUM_FU_LOAD-1:0]    lu_reg_debug
    , output LU_FWD_REG [`NUM_FU_LOAD-1:0]    lu_fwd_reg_debug
    , output logic      [`NUM_FU_LOAD-1:0]    load_selected_debug
    , output logic      [`NUM_FU_LOAD-1:0]    load_req_data_valid_debug
    , output DATA       [`NUM_FU_LOAD-1:0]    load_req_data_debug
    , output SQ_ENTRY[(`SQ_LEN+1)-1:0] sq_entries_out
    , output SQ_DCACHE_PACKET [`NUM_SQ_DCACHE-1:0] sq_dcache_packet_debug
    , output FU_STATE_PACKET cdb_state_debug
    , output logic [`N-1:0] store_req_accept_debug
    , output logic [`N-1:0] load_req_accept_debug
    `endif
);

    FU_STATE_PACKET fu_state_packet;
    FU_ROB_PACKET [`NUM_FU_ALU-1:0] cond_rob_packet;
    FU_ROB_PACKET [`N-1:0] cdb_rob_packet;

    logic [`NUM_FU_LOAD-1:0] cdb_lq_load_avail;
    
`ifdef CPU_DEBUG_OUT
    assign fu_state_packet_debug = fu_state_packet;
    assign load_selected_debug   = cdb_lq_load_avail;
`endif

   
    
    fu fu_inst(
        .clock(clock),
        .reset(reset),
        .squash(squash),
        .fu_alu_packet(fu_alu_packet),
        .fu_mult_packet(fu_mult_packet),
        .fu_load_packet(fu_load_packet),
        .fu_store_packet(fu_store_packet),
        // from memory to dcache
        .Dmem2proc_transaction_tag(Dmem2proc_transaction_tag),
        .Dmem2proc_data(Dmem2proc_data),
        .Dmem2proc_data_tag(Dmem2proc_data_tag),
        .alu_avail(alu_avail),
        .mult_avail(mult_avail),
        .load_avail(cdb_lq_load_avail),
        // output
        .load_rs_avail(load_avail),
        .id_sq_packet(id_sq_packet),
        .rob_num_commit_insns(rob_num_commit_insns),
        // output
        .store_avail(store_avail),
        .sq_head(sq_head),
        .sq_tail(sq_tail),
        .sq_tail_ready(sq_tail_ready),
        .sq_almost_full(sq_almost_full),
        .sq_num_sent_insns(sq_num_sent_insns),
        .cond_rob_packet(cond_rob_packet),
        .fu_state_packet(fu_state_packet),
        // from dcache to memory
        .proc2Dmem_command(proc2Dmem_command),
        .proc2Dmem_addr(proc2Dmem_addr),
        .proc2Dmem_data(proc2Dmem_data),
        .dcache_request(dcache_request)
    `ifdef CPU_DEBUG_OUT
        , .dmshr_entries_debug(dmshr_entries_debug)
        , .dcache_data_debug(dcache_data_debug)
        , .counter_debug(counter_debug)
        , .lq_dcache_packet_debug(lq_dcache_packet_debug)
        , .lq_entries_out(lq_entries_out)
        , .rs_lq_packet_debug(rs_lq_packet_debug)
        , .lu_reg_debug(lu_reg_debug)
        , .lu_fwd_reg_debug(lu_fwd_reg_debug)
        , .load_req_data_valid_debug(load_req_data_valid_debug)
        , .load_req_data_debug(load_req_data_debug)
        , .sq_entries_out(sq_entries_out)
        , .sq_dcache_packet_debug(sq_dcache_packet_debug)
        , .store_req_accept_debug(store_req_accept_debug)
        , .load_req_accept_debug(load_req_accept_debug)
    `endif
    );

    cdb cdb_inst(
        .clock(clock),
        .reset(reset || squash),
        .fu_state_packet(fu_state_packet),
        //output
        .alu_avail(alu_avail),
        .mult_avail(mult_avail),
        .load_avail(cdb_lq_load_avail),
        .fu_rob_packet(cdb_rob_packet),
        .cdb_output(cdb_output)
        `ifdef CPU_DEBUG_OUT
        , .select_debug(select_debug)
        , .cdb_state_debug(cdb_state_debug)
        `endif
    );

    assign fu_rob_packet = {cond_rob_packet, cdb_rob_packet};

endmodule
