`include "sys_defs.svh"
`define CPU_DEBUG_OUT
// fu_cdb, prf, rat, rrat, rob, rs
// decoder output - ooo: rob, rs, rat
// output: rs, rob almost_full
// rob: ROB_IF_PACKET
module ooo (
    input clock, reset,

    input ID_OOO_PACKET id_ooo_packet,
    // From memory to dcache
    input MEM_TAG   Dmem2proc_transaction_tag,
    input MEM_BLOCK Dmem2proc_data,
    input MEM_TAG   Dmem2proc_data_tag,

    output logic         structural_hazard,
    output logic         squash,
    output ROB_IF_PACKET rob_if_packet,
    output OOO_CT_PACKET ooo_ct_packet,
    // To memory from dcache
    output MEM_COMMAND proc2Dmem_command,
    output ADDR        proc2Dmem_addr,
    output MEM_BLOCK   proc2Dmem_data,
    // To icache from dcache
    output logic       dcache_request
`ifdef CPU_DEBUG_OUT
    , output CDB_PACKET [`N-1:0] cdb_packet_debug
    , output FU_STATE_PACKET fu_state_packet_debug
    , output logic [`NUM_FU_ALU + `NUM_FU_MULT + `NUM_FU_LOAD-1:0] select_debug
    // rob
    , output ROB_ENTRY [`ROB_SZ-1:0]        rob_entries_out
    , output logic     [`RS_CNT_WIDTH-1:0]  rob_counter_out
    , output logic     [`ROB_PTR_WIDTH-1:0] rob_head_out
    , output logic     [`ROB_PTR_WIDTH-1:0] rob_tail_out
    // rs
    , output RS_ENTRY  [`RS_SZ-1:0]         rs_entries_out
    , output logic     [`RS_CNT_WIDTH-1:0]  rs_counter_out
    // prf
    , output PRF_ENTRY [`PHYS_REG_SZ_R10K-1:0] prf_entries_debug
    // rra
    , output PRN       [`ARCH_REG_SZ-1:0] rrat_entries
    // rat
    , output PRN                              rat_head, rat_tail
    , output logic [`FREE_LIST_CTR_WIDTH-1:0] rat_counter
    , output PRN   [`PHYS_REG_SZ_R10K-1:0]    rat_free_list
    , output PRN   [`ARCH_REG_SZ-1:0]         rat_table_out
    , output FU_PACKET [`NUM_FU_ALU-1:0]   fu_alu_packet_debug
    , output FU_PACKET [`NUM_FU_MULT-1:0]  fu_mult_packet_debug
    , output FU_PACKET [`NUM_FU_LOAD-1:0]  fu_load_packet_debug
    , output FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet_debug
    // rrat
`endif
);

    RS_IS_PACKET rs_is_packet;
    logic        rs_almost_full;

    ROB_IS_PACKET               rob_is_packet;
    logic                       rob_almost_full;
    ROB_CT_PACKET               rob_ct_packet;
    ROBN          [`N-1:0]      rob_tail_entries;

    RAT_IS_INPUT  rat_is_input;
    RAT_IS_OUTPUT rat_is_output;

    RRAT_CT_INPUT  rrat_ct_input;
    RRAT_CT_OUTPUT rrat_ct_output;

    PRF_ENTRY [2*`N-1:0] prf_output_value; // prf output, used to calculate rs input
    PRN       [2*`N-1:0] read_prn;         // prn input, given by rat output
    PRN       [`N-1:0]   prn_invalid;      // prf input, given by rat output
    PRF_WRITE [`N-1:0]   prn_write_data;   // prf input, given by rob output

    ID_SQ_PACKET [`N-1:0] id_sq_packet;
    logic                 sq_almost_full;
    wor                   id_sq_valid;

    // output of fu_cdb, connect to rob
    FU_ROB_PACKET [`FU_ROB_PACKET_SZ-1:0]   fu_rob_packet;

    // connecting rs and FU
    FU_PACKET [`NUM_FU_ALU-1:0]   fu_alu_packet;
    FU_PACKET [`NUM_FU_MULT-1:0]  fu_mult_packet;
    FU_PACKET [`NUM_FU_LOAD-1:0]  fu_load_packet;
    FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet;

    `ifdef CPU_DEBUG_OUT
        assign fu_alu_packet_debug   = fu_alu_packet;
        assign fu_mult_packet_debug  = fu_mult_packet;
        assign fu_load_packet_debug  = fu_load_packet;
        assign fu_store_packet_debug = fu_store_packet;
    `endif
    
    // output of fu_cdb, connect to rs
    logic [`NUM_FU_ALU-1:0]   alu_avail;
    logic [`NUM_FU_MULT-1:0]  mult_avail;
    logic [`NUM_FU_LOAD-1:0]  load_avail;
    logic [`NUM_FU_STORE-1:0] store_avail;

    // cdb output
    CDB_PACKET    [`N-1:0] cdb_packet;

`ifdef CPU_DEBUG_OUT
    assign cdb_packet_debug = cdb_packet;
    assign rrat_entries = rrat_ct_output.entries;
`endif

    // prf input, connect to cpu output
    PRN [`N-1:0] wb_read_prn;

    // for error status
    logic halt;

    SQ_IDX sq_head, sq_tail, sq_tail_ready, sq_num_sent_insns, rob_num_commit_insns;

    rs rs_inst(
        .clock(clock),
        .reset(reset || squash),
        .rs_is_packet(rs_is_packet),
        .cdb_packet(cdb_packet),
        .fu_alu_avail(alu_avail),
        .fu_mult_avail(mult_avail),
        .fu_load_avail(load_avail),
        .fu_store_avail(store_avail),
        .head(sq_head),
        .tail(sq_tail),
        .tail_ready(sq_tail_ready),
        // output
        .fu_alu_packet(fu_alu_packet),
        .fu_mult_packet(fu_mult_packet),
        .fu_load_packet(fu_load_packet),
        .fu_store_packet(fu_store_packet),
        .almost_full(rs_almost_full)
    `ifdef CPU_DEBUG_OUT
        , .entries_out(rs_entries_out)
        , .counter_out(rs_counter_out)
    `endif
    );

    fu_cdb fu_cdb_inst(
        .clock(clock),
        .reset(reset || squash),
        .squash(squash),
        .fu_alu_packet(fu_alu_packet),
        .fu_mult_packet(fu_mult_packet),
        .fu_load_packet(fu_load_packet),
        .fu_store_packet(fu_store_packet),
        .id_sq_packet(id_sq_packet),
        .rob_num_commit_insns(rob_num_commit_insns),
        // from memory to dcache
        .Dmem2proc_transaction_tag(Dmem2proc_transaction_tag),
        .Dmem2proc_data(Dmem2proc_data),
        .Dmem2proc_data_tag(Dmem2proc_data_tag),
        //output
        .alu_avail(alu_avail),
        .mult_avail(mult_avail),
        .load_avail(load_avail),
        .store_avail(store_avail),
        .fu_rob_packet(fu_rob_packet),
        .cdb_output(cdb_packet),
        .sq_almost_full(sq_almost_full),
        .sq_head(sq_head),
        .sq_tail(sq_tail),
        .sq_tail_ready(sq_tail_ready),
        .sq_num_commit_insns(sq_num_sent_insns),
        // from dcache to memory
        .proc2mem_command(proc2Dmem_command),
        .proc2mem_addr(proc2Dmem_addr),
        .proc2mem_data(proc2Dmem_data),
        .dcache_request(dcache_request)
        `ifdef CPU_DEBUG_OUT
        , .fu_state_packet_debug(fu_state_packet_debug)
        , .select_debug(select_debug)
        `endif
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
        `ifdef CPU_DEBUG_OUT
        , .entries_out(prf_entries_debug)
        `endif
    );

    rob rob_inst (
        .clock(clock),
        .reset(reset),
        .rob_is_packet(rob_is_packet),
        .fu_rob_packet(fu_rob_packet),
        .sq_sent_insns_num(sq_num_sent_insns),
        // output
        .rob_commit_insns_num(rob_num_commit_insns),
        .almost_full(rob_almost_full),
        .rob_ct_packet(rob_ct_packet),
        .tail_entries(rob_tail_entries),
        .squash(squash)
    `ifdef CPU_DEBUG_OUT
        ,.entries_out(rob_entries_out)
        ,.counter_out(rob_counter_out)
        ,.head_out(rob_head_out)
        ,.tail_out(rob_tail_out)
    `endif
    ); 

    rat rat_inst(
        .clock(clock),
        .reset(reset),
        .rat_is_input(rat_is_input),
        .rrat_ct_output(rrat_ct_output),
        // output
        .rat_is_output(rat_is_output)
    `ifdef CPU_DEBUG_OUT
        , .head(rat_head)
        , .tail(rat_tail)
        , .counter(rat_counter)
        , .free_list(rat_free_list)
        , .rat_table_out(rat_table_out)
    `endif
    );

    rrat rrat_inst(
        .clock(clock),
        .reset(reset),
        .rrat_ct_input(rrat_ct_input),
        // output
        .rrat_ct_output(rrat_ct_output)
    );

    // sq almost full
    genvar i;
    generate
        for (i = 0; i < `N; ++i) begin
            assign id_sq_valid = id_ooo_packet.id_sq_packet[i].valid;
        end
    endgenerate


    always_comb begin
        // issue

        // rat input
        rat_is_input = structural_hazard ? 0 : id_ooo_packet.rat_is_input;

        // rob input
        for (int i = 0; i < `N; ++i) begin
            rob_is_packet.valid[i] = `FALSE;
            rob_is_packet.entries[i] = 0;
            rob_is_packet.entries[i].success = `TRUE;
        end
        if (~structural_hazard) begin
            rob_is_packet = id_ooo_packet.rob_is_packet;
            for (int i = 0; i < `N; ++i) begin
                rob_is_packet.entries[i].dest_prn = rat_is_output.entries[i].dest_prn;
            end
        end

        // rs input
        rs_is_packet = 0;
        if (~structural_hazard) begin
            for (int i = 0; i < `N; ++i) begin
                // consecutive prf entry belongs to the same insn
                rs_is_packet.entries[i].op1_ready = prf_output_value[2*i].valid; // || id_ooo_packet.id_rs_packet[i].op1_ready;
                rs_is_packet.entries[i].op1       =
                    prf_output_value[2*i].valid ? prf_output_value[2*i].value : rat_is_output.entries[i].op1_prn;
                rs_is_packet.entries[i].op2_ready = prf_output_value[2*i+1].valid || id_ooo_packet.id_rs_packet[i].fu == FU_LOAD; // || id_ooo_packet.id_rs_packet[i].op2_ready;
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
                rs_is_packet.entries[i].sq_idx   = id_ooo_packet.id_rs_packet[i].sq_idx;
                rs_is_packet.entries[i].mem_func   = id_ooo_packet.id_rs_packet[i].mem_func;
            end
        end
        
        // fu store queue input
        for (int i = 0; i < `N; ++i) begin
            id_sq_packet[i] = id_ooo_packet.id_sq_packet[i];
        end

        // commit
        for (int i = 0; i < `N; ++i) begin
            rrat_ct_input.arns[i]    = rob_ct_packet.entries[i].dest_arn;
            rrat_ct_input.success[i] = rob_ct_packet.entries[i].success;
            
            rob_if_packet.entries[i].valid          = rob_ct_packet.entries[i].executed;
            rob_if_packet.entries[i].success        = rob_ct_packet.entries[i].success;
            rob_if_packet.entries[i].predict_taken  = rob_ct_packet.entries[i].predict_taken;
            rob_if_packet.entries[i].predict_target = rob_ct_packet.entries[i].predict_target;
            rob_if_packet.entries[i].resolve_taken  = rob_ct_packet.entries[i].resolve_taken;
            rob_if_packet.entries[i].resolve_target = rob_ct_packet.entries[i].resolve_target;
            rob_if_packet.entries[i].PC             = rob_ct_packet.entries[i].PC;
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
        halt = `FALSE;
        for (int i = 0; i < `N; ++i) begin
            ooo_ct_packet.completed_inst += rob_ct_packet.entries[i].executed && !halt;
            ooo_ct_packet.exception_code[i] = 
                rob_ct_packet.entries[i].illegal ? ILLEGAL_INST :
                rob_ct_packet.entries[i].halt    ? HALTED_ON_WFI : NO_ERROR;
            halt |= ooo_ct_packet.exception_code[i] != NO_ERROR;
            wb_read_prn[i]          = rob_ct_packet.entries[i].dest_prn;
            ooo_ct_packet.wr_idx[i] = rob_ct_packet.entries[i].dest_arn;
            ooo_ct_packet.wr_en[i]  = ooo_ct_packet.wr_idx[i] != `ZERO_REG;
            // ooo_ct_packet.wr_en[i]  = `TRUE; // debug
            ooo_ct_packet.NPC[i]    = rob_ct_packet.entries[i].NPC;
        end
    end

    assign structural_hazard = rs_almost_full || rob_almost_full
                            || (sq_almost_full && id_sq_valid);

endmodule