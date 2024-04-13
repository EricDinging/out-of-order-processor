/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  cpu_test.sv                                         //
//                                                                     //
//  Description :  Testbench module for the verisimple processor.      //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"
`define CPU_DEBUG_OUT

// P4 TODO: Add your own debugging framework. Basic printing of data structures
//          is an absolute necessity for the project. You can use C functions
//          like in test/pipeline_print.c or just do everything in verilog.
//          Be careful about running out of space on CAEN printing lots of state
//          for longer programs (alexnet, outer_product, etc.)


// These link to the test/pipeline_print.c file, and are used below to print
// detailed output to the pipeline_output_file, initialized by open_pipeline_output_file()
// import "DPI-C" function void open_pipeline_output_file(string file_name);
// import "DPI-C" function void print_header();
// import "DPI-C" function void print_cycles(int clock_count);
// import "DPI-C" function void print_stage(int inst, int npc, int valid_inst);
// import "DPI-C" function void print_reg(int wb_data, int wb_idx, int wb_en);
// import "DPI-C" function void print_membus(int proc2mem_command, int proc2mem_addr,
//                                           int proc2mem_data_hi, int proc2mem_data_lo);
// import "DPI-C" function void close_pipeline_output_file();


module testbench;
    // string inputs for loading memory and output files
    // run like: ./simv +MEMORY=programs/<my_program.mem> +OUTPUT=output/<my_program>
    // this testbench will generate 3 output files based on the output
    // named OUTPUT.{cpi, wb, ppln} for the cpi, writeback, and pipeline outputs
    // and the testbench will display to stdout the final memory state of the
    // processor
    string program_memory_file, output_name;
    string cpi_output_file, writeback_output_file, pipeline_output_file;
    int cpi_fileno, wb_fileno, ppln_fileno; // verilog uses integer file handles with $fopen and $fclose

    // variables used in the testbench
    logic        clock;
    logic        reset;
    logic [31:0] clock_count; // also used for terminating infinite loops
    logic [31:0] instr_count;

    MEM_COMMAND proc2mem_command;
    ADDR        proc2mem_addr;
    MEM_BLOCK   proc2mem_data;
    MEM_TAG     mem2proc_transaction_tag;
    MEM_BLOCK   mem2proc_data;
    MEM_TAG     mem2proc_data_tag;
`ifndef CACHE_MODE
    MEM_SIZE    proc2mem_size;
`endif

    logic [`N_CNT_WIDTH-1:0] pipeline_completed_insts;
    EXCEPTION_CODE  [`N-1:0] pipeline_error_status;
    REG_IDX         [`N-1:0] pipeline_commit_wr_idx;
    DATA            [`N-1:0] pipeline_commit_wr_data;
    logic           [`N-1:0] pipeline_commit_wr_en;
    ADDR            [`N-1:0] pipeline_commit_NPC;

`ifdef CPU_DEBUG_OUT
    IF_ID_PACKET [`N-1:0]  if_id_reg_debug;
    ID_OOO_PACKET          id_ooo_reg_debug;
    logic                  squash_debug;
    ROB_IF_PACKET          rob_if_packet_debug;
    // cdb  
    CDB_PACKET    [`N-1:0] cdb_packet_debug;
    FU_STATE_PACKET        fu_state_packet_debug;

    // ROB
    ROB_ENTRY [`ROB_SZ-1:0]    rob_entries_out;
    logic [`ROB_CNT_WIDTH-1:0] rob_counter_out;
    logic [`ROB_PTR_WIDTH-1:0] rob_head_out;
    logic [`ROB_PTR_WIDTH-1:0] rob_tail_out;

    // rs
    RS_ENTRY  [`RS_SZ-1:0]     rs_entries_out;
    logic [`RS_CNT_WIDTH-1:0]  rs_counter_out;
    
    logic [`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LOAD-1:0] select_debug;
    FU_PACKET [`NUM_FU_ALU-1:0]                       fu_alu_packet_debug;
    FU_PACKET [`NUM_FU_MULT-1:0]                      fu_mult_packet_debug;
    FU_PACKET [`NUM_FU_LOAD-1:0]                      fu_load_packet_debug;
    FU_PACKET [`NUM_FU_STORE-1:0]                     fu_store_packet_debug;
    
    // rat
    PRN                              rat_head, rat_tail;
    logic [`FREE_LIST_CTR_WIDTH-1:0] rat_counter;
    PRN   [`PHYS_REG_SZ_R10K-1:0]    rat_free_list;
    PRN   [`ARCH_REG_SZ-1:0]         rat_table_out;

    // rrat
    PRN   [`ARCH_REG_SZ-1:0]         rrat_entries;

    // prf
    PRF_ENTRY [`PHYS_REG_SZ_R10K-1:0] prf_entries_debug;
    
    // memory
    IMSHR_ENTRY [`N-1:0] imshr_entries_debug;

    // branch predictor
    BTB_ENTRY [`BTB_SIZE-1:0] btb_entries_debug;
    logic [`BHT_SIZE-1:0][`BHT_WIDTH-1:0] branch_history_table_debug;
    PHT_ENTRY_STATE [`PHT_SIZE-1:0] pattern_history_table_debug;

    // dcache
    DMSHR_ENTRY [`DMSHR_SIZE-1:0] dmshr_entries_debug;
    DCACHE_ENTRY [`DCACHE_LINES-1:0] dcache_data_debug;
    logic [`DMSHR_SIZE-1:0][`N_CNT_WIDTH-1:0] dmshr_counter_debug;
    LQ_DCACHE_PACKET [`NUM_LU_DCACHE-1:0] lq_dcache_packet_debug;

    // lq
    LD_ENTRY [`NUM_FU_LOAD-1:0]     lq_entries_out;
    RS_LQ_PACKET [`NUM_FU_LOAD-1:0] rs_lq_packet_debug;
    LU_REG     [`NUM_FU_LOAD-1:0]   lu_reg_debug;
    LU_FWD_REG [`NUM_FU_LOAD-1:0]   lu_fwd_reg_debug;
    logic      [`NUM_FU_LOAD-1:0]   load_selected_debug;
    logic      [`NUM_FU_LOAD-1:0]   load_req_data_valid_debug;
    DATA       [`NUM_FU_LOAD-1:0]   load_req_data_debug;
`endif

    task print_load_queue;
        $fdisplay(ppln_fileno, "### LOAD_QUEUE:");
        for (int i = 0; i < `NUM_FU_LOAD; ++i) begin
            if (lq_entries_out[i].valid) begin
                $fdisplay(ppln_fileno, "  addr[%0d]: %h, data: %h, tail_score: %0d, prn: %0d, robn: %0d", 
                          i, lq_entries_out[i].addr, lq_entries_out[i].data, lq_entries_out[i].tail_store, lq_entries_out[i].prn, lq_entries_out[i].robn);
                case (lq_entries_out[i].byte_info)
                    MEM_BYTE:
                        $fdisplay(ppln_fileno, "    byte_info[%0d]: MEM_BYTE", i);
                    MEM_HALF: 
                        $fdisplay(ppln_fileno, "    byte_info[%0d]: MEM_HALF", i);
                    MEM_WORD:
                        $fdisplay(ppln_fileno, "    byte_info[%0d]: MEM_WORD", i);
                    MEM_BYTEU:
                        $fdisplay(ppln_fileno, "    byte_info[%0d]: MEM_BYTEU", i);
                    MEM_HALFU:
                        $fdisplay(ppln_fileno, "    byte_info[%0d]: MEM_HALFU", i);
                endcase
                case (lq_entries_out[i].load_state)
                    KNOWN:
                        $fdisplay(ppln_fileno, "    load_state[%0d]: KNOWN", i);
                    NO_FORWARD:
                        $fdisplay(ppln_fileno, "    load_state[%0d]: NO_FORWARD", i);
                    ASKED:
                        $fdisplay(ppln_fileno, "    load_state[%0d]: ASKED", i);
                endcase
            end else begin
                $fdisplay(ppln_fileno, "  invalid[%0d]", i);
            end
        end
        $fdisplay(ppln_fileno, "    cdb_load_selected: %b", load_selected_debug);

    endtask

    task print_rs_lq_packet;
        $fdisplay(ppln_fileno, "### RS_LQ_PACKET:");
        for (int i = 0; i < `NUM_FU_LOAD; ++i) begin
            $fdisplay(ppln_fileno, "  valid[%0d]: %b, base[%0d]: %0d, offset[%0d]: %0d, tail: %0d",
             i, rs_lq_packet_debug[i].valid, i, rs_lq_packet_debug[i].base, i, rs_lq_packet_debug[i].offset, rs_lq_packet_debug[i].tail_store);
            $fdisplay(ppln_fileno, "  lu_reg[%0d]: %0d, lu_fwd_reg[%0d]: %0d", i, lu_reg_debug[i].valid, i, lu_fwd_reg_debug[i].valid);
        end

    endtask

    task print_fu_load_packet_debug;
        $fdisplay(ppln_fileno, "### FU_LOAD_PACKET:");
        for (int i = 0; i < `NUM_FU_LOAD; ++i) begin
            $fdisplay(ppln_fileno, "  valid[%0d]: %b", i, fu_load_packet_debug[i].valid);
            $fdisplay(ppln_fileno, "    inst[%0d]: %0h", i, fu_load_packet_debug[i].inst);
            $fdisplay(ppln_fileno, "    PC[%0d]: %d", i, fu_load_packet_debug[i].PC);
            // $fdisplay(ppln_fileno, "  func[%0d]: %0d", i, fu_load_packet_debug[i].func);
            $fdisplay(ppln_fileno, "    op1[%0d]: %0d", i, fu_load_packet_debug[i].op1);
            $fdisplay(ppln_fileno, "    op2[%0d]: %0d", i, fu_load_packet_debug[i].op2);
            $fdisplay(ppln_fileno, "    dest_prn[%0d]: %0d", i, fu_load_packet_debug[i].dest_prn);
            $fdisplay(ppln_fileno, "    robn[%0d]: %0d", i, fu_load_packet_debug[i].robn);
            // $fdisplay(ppln_fileno, "  opa_select[%0d]: %0d", i, fu_load_packet_debug[i].opa_select);
            // $fdisplay(ppln_fileno, "  opb_select[%0d]: %0d", i, fu_load_packet_debug[i].opb_select);
            // $fdisplay(ppln_fileno, "  cond_branch[%0d]: %b", i, fu_load_packet_debug[i].cond_branch);
            // $fdisplay(ppln_fileno, "  uncond_branch[%0d]: %b", i, fu_load_packet_debug[i].uncond_branch);
            $fdisplay(ppln_fileno, "    sq_idx[%0d]: %0d", i, fu_load_packet_debug[i].sq_idx);
            case (fu_load_packet_debug[i].mem_func)
                MEM_BYTE:
                    $fdisplay(ppln_fileno, "    mem_func[%0d]: MEM_BYTE", i);
                MEM_HALF: 
                    $fdisplay(ppln_fileno, "    mem_func[%0d]: MEM_HALF", i);
                MEM_WORD:
                    $fdisplay(ppln_fileno, "    mem_func[%0d]: MEM_WORD", i);
                MEM_BYTEU:
                    $fdisplay(ppln_fileno, "    mem_func[%0d]: MEM_BYTEU", i);
                MEM_HALFU:
                    $fdisplay(ppln_fileno, "    mem_func[%0d]: MEM_HALFU", i);
            endcase
        end
    endtask

    task print_lq_dcache_packet;
        $fdisplay(ppln_fileno, "### LQ_DCACHE_PACKET:");
        for (int i = 0; i < `N; ++i) begin
            $fdisplay(ppln_fileno, "  valid[%0d]: %b", i, lq_dcache_packet_debug[i].valid);
            $fdisplay(ppln_fileno, "    lq_idx[%0d]: %0d", i, lq_dcache_packet_debug[i].lq_idx);
            $fdisplay(ppln_fileno, "    addr[%0d]: %h", i, lq_dcache_packet_debug[i].addr);
            case (lq_dcache_packet_debug[i].mem_func)
                MEM_BYTE:
                    $fdisplay(ppln_fileno, "    mem_func[%0d]: MEM_BYTE", i);
                MEM_HALF: 
                    $fdisplay(ppln_fileno, "    mem_func[%0d]: MEM_HALF", i);
                MEM_WORD:
                    $fdisplay(ppln_fileno, "    mem_func[%0d]: MEM_WORD", i);
                MEM_BYTEU:
                    $fdisplay(ppln_fileno, "    mem_func[%0d]: MEM_BYTEU", i);
                MEM_HALFU:
                    $fdisplay(ppln_fileno, "    mem_func[%0d]: MEM_HALFU", i);
            endcase
            $fdisplay(ppln_fileno, "    load_req_data_valid_debug: %b, load_req_data_debug: 0x%h", load_req_data_valid_debug[i], load_req_data_debug[i]);
        end
    endtask

    task print_dcache;
        $fdisplay(ppln_fileno, "### DMSHR_ENTRY:");
        for (int i = 0; i < `DMSHR_SIZE; ++i) begin
            case (dmshr_entries_debug[i].transaction_tag)
                DMSHR_INVALID: 
                    $fdisplay(ppln_fileno, "  state[%0d]: DMSHR_INVALID", i);
                DMSHR_PENDING:
                    $fdisplay(ppln_fileno, "  state[%0d]: DMSHR_PENDING", i);
                DMSHR_WAIT_TAG:
                    $fdisplay(ppln_fileno, "  state[%0d]: DMSHR_WAIT_TAG", i);
                DMSHR_WAIT_DATA:
                    $fdisplay(ppln_fileno, "  state[%0d]: DMSHR_WAIT_DATA", i);
            endcase
            $fdisplay(ppln_fileno, "    cache_index[%0d]: %0d", i, dmshr_entries_debug[i].index);
            $fdisplay(ppln_fileno, "    tag[%0d]: %h", i, dmshr_entries_debug[i].tag);
            $fdisplay(ppln_fileno, "    transaction_tag[%0d]: %0d", i, dmshr_entries_debug[i].transaction_tag);
            $fdisplay(ppln_fileno, "    queue_size[%0d]: %d", i, dmshr_counter_debug[i]);
        end
        $fdisplay(ppln_fileno, "### DCACHE_ENTRY:");
        for (int i = 0; i < `DCACHE_LINES; ++i) begin
            $fdisplay(ppln_fileno, "  valid[%0d]: %b", i, dcache_data_debug[i].valid);
            $fdisplay(ppln_fileno, "    data[%0d]: %h", i, dcache_data_debug[i].data);
            $fdisplay(ppln_fileno, "    tag[%0d]: %h", i, dcache_data_debug[i].tag);
            $fdisplay(ppln_fileno, "    dirty[%0d]: %b", i, dcache_data_debug[i].dirty);
        end
    endtask

    task print_if_id_reg;
        $fdisplay(ppln_fileno, "### IF/ID REG:");
        for (int i = 0; i < `N; ++i) begin
            $fdisplay(ppln_fileno, "  Valid[%0d]: %x", i, if_id_reg_debug[i].valid);
            $fdisplay(ppln_fileno, "    PC[%0d]: %0d", i, if_id_reg_debug[i].PC);
            $fdisplay(ppln_fileno, "    Instruction[%0d]: %x", i, if_id_reg_debug[i].inst);
        end
    endtask

    task print_id_ooo_reg;
        $fdisplay(ppln_fileno, "### ID/OOO REG:");
        for (int i = 0; i < `N; ++i) begin
            $fdisplay(ppln_fileno, "  PC[%0d]: %0d", i, id_ooo_reg_debug.rob_is_packet.entries[i].PC);
            $fdisplay(ppln_fileno, "  dest_arn[%0d]: %0d", i, id_ooo_reg_debug.rat_is_input.entries[i].dest_arn);
        end
    endtask

    task print_rob_if_debug;
        $fdisplay(ppln_fileno, "--- ROB IF OUTPUT");
        $fdisplay(ppln_fileno, "  Squash? %b", squash_debug);
        for (int i = 0; i < `N; ++i) begin
            $fdisplay(ppln_fileno, "  success? %0d, predict_taken? %0d, predict_target: %0d", rob_if_packet_debug.entries[i].success, rob_if_packet_debug.entries[i].predict_taken, rob_if_packet_debug.entries[i].predict_target); 
            $fdisplay(ppln_fileno, "  resolve_taken? %0d, resolve_target: %0d", rob_if_packet_debug.entries[i].resolve_taken, rob_if_packet_debug.entries[i].resolve_target);
        end
    endtask

    task print_cdb_packet;
        $fdisplay(ppln_fileno, "--- CDB PACKET");
        for (int i = 0; i < `N; ++i) begin
            $fdisplay(ppln_fileno, "PRN[%2d]=%2d, value[%2d]=%2d", i, cdb_packet_debug[i].dest_prn, i, cdb_packet_debug[i].value);
        end
    endtask

    task print_fu_state_packet;
        $fdisplay(ppln_fileno, "### FU STATE ALU PACKET:");
        for (int i = 0; i < `NUM_FU_ALU; ++i) begin
            $fdisplay(ppln_fileno, "Prepared[%2d]=%b, robn[%2d]=%2d", i, fu_state_packet_debug.alu_prepared[i], i, fu_state_packet_debug.alu_packet[i].basic.robn);
            $fdisplay(ppln_fileno, "result[%2d]=%b, dest_prn[%2d]=%2d", i, fu_state_packet_debug.alu_packet[i].basic.result, i, fu_state_packet_debug.alu_packet[i].basic.dest_prn);
        end
        $fdisplay(ppln_fileno, "### FU STATE MULT PACKET:");
        for (int i = 0; i < `NUM_FU_MULT; ++i) begin
            $fdisplay(ppln_fileno, "Prepared[%2d]=%b, robn[%2d]=%2d", i, fu_state_packet_debug.mult_prepared[i], i, fu_state_packet_debug.mult_packet[i].robn);
            $fdisplay(ppln_fileno, "result[%2d]=%b, dest_prn[%2d]=%2d", i, fu_state_packet_debug.mult_packet[i].result, i, fu_state_packet_debug.mult_packet[i].dest_prn);
        end
        $fdisplay(ppln_fileno, "### FU STATE LOAD PACKET:");
        for (int i = 0; i < `NUM_FU_LOAD; ++i) begin
            $fdisplay(ppln_fileno, "Prepared[%2d]=%b, robn[%2d]=%2d", i, fu_state_packet_debug.load_prepared[i], i, fu_state_packet_debug.load_packet[i].robn);
            $fdisplay(ppln_fileno, "result[%2d]=%b, dest_prn[%2d]=%2d", i, fu_state_packet_debug.load_packet[i].result, i, fu_state_packet_debug.load_packet[i].dest_prn);
        end
    endtask
    
    task print_rob;
        $fdisplay(ppln_fileno, "### ROB ENTRIES");
        $fdisplay(ppln_fileno, "counter=%2d, head=%2d, tail=%2d", rob_counter_out, rob_head_out, rob_tail_out);
        for (int i = 0; i < `ROB_SZ; i++) begin
            $fdisplay(ppln_fileno, 
                "ROB[%2d]: .executed=%b, .success=%b, .dest_prn=%2d, .dest_arn=%2d, .PC=%d %s",
                i, rob_entries_out[i].executed, rob_entries_out[i].success,
                rob_entries_out[i].dest_prn, rob_entries_out[i].dest_arn, rob_entries_out[i].PC,
                i == rob_head_out ? "h" : i == rob_tail_out ? "t" : " "
            );
        end
    endtask

    task print_rs;
        $fdisplay(ppln_fileno, "### RS ENTRIES");
        $fdisplay(ppln_fileno, "counter=%2d", rs_counter_out);
        for (int i = 0; i < `RS_SZ; i++) begin
            if (rs_entries_out[i].valid)
                $fdisplay(ppln_fileno, "RS[%2d]: .PC=%d, .op1_ready=%b, .op2_ready=%b, .op1_value=0x%8x, .op2_value=0x%8x, .dest_prn=%2d, .robn=%2d", //, .cond_branch=%d, .uncond_branch=%d",
                        i, rs_entries_out[i].PC, rs_entries_out[i].op1_ready, rs_entries_out[i].op2_ready, 
                        rs_entries_out[i].op1, rs_entries_out[i].op2, rs_entries_out[i].dest_prn, rs_entries_out[i].robn);
                        //,rs_entries_out[i].cond_branch, rs_entries_out[i].uncond_branch);
            else
                $fdisplay(ppln_fileno, "RS[%2d]: invalid", i);
        end
        // alu packet
        $fdisplay(ppln_fileno, "--- RS ALU PACKETS");
        for (int i = 0; i < `NUM_FU_ALU; ++i) begin
            if (fu_alu_packet_debug[i].valid)
                $fdisplay(ppln_fileno, "ALU[%2d]: .robn=%2d, .dest_prn=%2d, .op1=%2d, .op2=%2d, .PC=%2d",
                        i, rs_entries_out[i].robn, rs_entries_out[i].dest_prn, rs_entries_out[i].op1, rs_entries_out[i].op2, rs_entries_out[i].PC);
            else
                $fdisplay(ppln_fileno, "ALU[%2d]: invalid", i);
        end
    endtask


    task print_rat;
        $fdisplay(ppln_fileno, "### RAT ENTRIES");
        for (int i = 0; i < `ARCH_REG_SZ; ++i) begin
            $fdisplay(ppln_fileno, "RAT[%2d] = %2d", i, rat_table_out[i]);
        end
    endtask

    task print_rrat;
        $fdisplay(ppln_fileno, "### RRAT ENTRIES");
        for (int i = 0; i < `ARCH_REG_SZ; ++i) begin
            $fdisplay(ppln_fileno, "RRAT[%2d] = %2d", i, rrat_entries[i]);
        end
    endtask
    
    task print_select;
        $fdisplay(ppln_fileno, "--- FU_CDB SELECT:%b", select_debug);
    endtask

    task print_prf;
        $fdisplay(ppln_fileno, "### PRF ENTRIES");
        for (int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
            $fdisplay(ppln_fileno, 
                "PRF[%2d] = 0x%08x %s", i, prf_entries_debug[i].value,
                prf_entries_debug[i].valid ? "valid" : ""
            );
        end
    endtask

    task print_mem_cache;
        $fdisplay(ppln_fileno, "--- MEM CACHE SIGNAL");
        if (proc2mem_command == MEM_NONE) begin
            $fdisplay(ppln_fileno, "proc2mem_command: MEM_NONE");
        end else if (proc2mem_command == MEM_LOAD) begin
            $fdisplay(ppln_fileno, "proc2mem_command: MEM_LOAD");
            $fdisplay(ppln_fileno, "proc2mem_addr: %2d", proc2mem_addr);
        end else if (proc2mem_command == MEM_STORE) begin
            $fdisplay(ppln_fileno, "proc2mem_command: MEM_STORE");
            $fdisplay(ppln_fileno, "proc2mem_addr: %2d", proc2mem_addr);
        end
        $fdisplay(ppln_fileno,
            "transcation_tag: %2d, data_tag: %2d, data: %x", 
            mem2proc_transaction_tag, mem2proc_data_tag,
            mem2proc_data);
    endtask

    task print_imshr_entries_debug;
        $fdisplay(ppln_fileno, "### IMSHR_ENTRIES");
        for (int i = 0; i < `N; i = i + 1) begin
            case (imshr_entries_debug[i].state)
                IMSHR_INVALID: 
                    $fdisplay(ppln_fileno, "imshr_entries_debug[%2d]: IMSHR_INVALID", i);
                IMSHR_PENDING: 
                    $fdisplay(ppln_fileno, "imshr_entries_debug[%2d]: IMSHR_PENDING", i);
                IMSHR_WAIT_TAG: 
                    $fdisplay(ppln_fileno, "imshr_entries_debug[%2d]: IMSHR_WAIT_TAG", i);
                IMSHR_WAIT_DATA: 
                    $fdisplay(ppln_fileno, "imshr_entries_debug[%2d]: IMSHR_WAIT_DATA", i);
                default:
                    $fdisplay(ppln_fileno, "Invalid state");
            endcase
            $fdisplay(ppln_fileno, "tag: %2d; index: %2d", imshr_entries_debug[i].tag, imshr_entries_debug[i].index);
            $fdisplay(ppln_fileno, "transaction_tag: %2d", imshr_entries_debug[i].transaction_tag);
        end
    endtask

    task print_branch_predictor;
        $fdisplay(ppln_fileno, "### Predictor");
        $fdisplay(ppln_fileno, "    BTB entry");
        for (int i = 0; i < `BTB_SIZE; ++i) begin
            $fdisplay(ppln_fileno, "    BTB[%2d].valid:%b, .PC:%h, .tag:%h", i, btb_entries_debug[i].valid, btb_entries_debug[i].PC, btb_entries_debug[i].tag);
        end
        $fdisplay(ppln_fileno, "    BHT entry");
        for (int i = 0; i < `BHT_SIZE; ++i) begin
            $fdisplay(ppln_fileno, "    BHT[%2d] = %8b", i, branch_history_table_debug[i]);
        end
        $fdisplay(ppln_fileno, "    PHT entry");
        for (int i = 0; i < `PHT_SIZE; ++i) begin
            if (pattern_history_table_debug[i] == TAKEN) begin
                $fdisplay(ppln_fileno, "    PHT[%2d] = TAKEN", i);
            end else begin
                $fdisplay(ppln_fileno, "    PHT[%2d] = NOT_TAKEN", i);
            end
        end
    endtask

    // Instantiate the Pipeline
    cpu verisimpleV (
        // Inputs
        .clock (clock),
        .reset (reset),
        .mem2proc_transaction_tag (mem2proc_transaction_tag),
        .mem2proc_data            (mem2proc_data),
        .mem2proc_data_tag        (mem2proc_data_tag),

        // Outputs
        .proc2mem_command (proc2mem_command),
        .proc2mem_addr    (proc2mem_addr),
        .proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
        .proc2mem_size    (proc2mem_size),
`endif
`ifdef CPU_DEBUG_OUT
        .if_id_reg_debug (if_id_reg_debug),
        .id_ooo_reg_debug(id_ooo_reg_debug),
        .squash_debug(squash_debug),
        .rob_if_packet_debug(rob_if_packet_debug),
        .cdb_packet_debug(cdb_packet_debug),
        .fu_state_packet_debug(fu_state_packet_debug),
        .select_debug(select_debug),
        // rob
        .rob_entries_out(rob_entries_out),
        .rob_counter_out(rob_counter_out),
        .rob_head_out(rob_head_out),
        .rob_tail_out(rob_tail_out),
        // rs
        .rs_entries_out(rs_entries_out),
        .rs_counter_out(rs_counter_out),
        // prf
        .prf_entries_debug(prf_entries_debug),
        // rat
        .rat_head(rat_head),
        .rat_tail(rat_tail),
        .rat_counter(rat_counter),
        .rat_free_list(rat_free_list),
        .rat_table_out(rat_table_out),
        // rrat
        .rrat_entries(rrat_entries),
        // fu_packet
        .fu_alu_packet_debug(fu_alu_packet_debug),
        .fu_mult_packet_debug(fu_mult_packet_debug),
        .fu_load_packet_debug(fu_load_packet_debug),
        .fu_store_packet_debug(fu_store_packet_debug),
        .imshr_entries_debug(imshr_entries_debug),
        // branch predictor
        .btb_entries_debug(btb_entries_debug),
        .branch_history_table_debug(branch_history_table_debug),
        .pattern_history_table_debug(pattern_history_table_debug),
        // dcache
        .dmshr_entries_debug(dmshr_entries_debug),
        .dcache_data_debug(dcache_data_debug),
        .counter_debug(dmshr_counter_debug),
        .lq_dcache_packet_debug(lq_dcache_packet_debug),
        // lq
        .lq_entries_out(lq_entries_out),
        .rs_lq_packet_debug(rs_lq_packet_debug),
        .lu_reg_debug(lu_reg_debug),
        .lu_fwd_reg_debug(lu_fwd_reg_debug),
        .load_selected_debug(load_selected_debug),
        .load_req_data_valid_debug(load_req_data_valid_debug),
        .load_req_data_debug(load_req_data_debug),
`endif
        .pipeline_completed_insts (pipeline_completed_insts),
        .pipeline_error_status    (pipeline_error_status),
        .pipeline_commit_wr_data  (pipeline_commit_wr_data),
        .pipeline_commit_wr_idx   (pipeline_commit_wr_idx),
        .pipeline_commit_wr_en    (pipeline_commit_wr_en),
        .pipeline_commit_NPC      (pipeline_commit_NPC)

        // .if_NPC_dbg       (if_NPC_dbg),
        // .if_inst_dbg      (if_inst_dbg),
        // .if_valid_dbg     (if_valid_dbg),
        // .if_id_NPC_dbg    (if_id_NPC_dbg),
        // .if_id_inst_dbg   (if_id_inst_dbg),
        // .if_id_valid_dbg  (if_id_valid_dbg),
        // .id_ex_NPC_dbg    (id_ex_NPC_dbg),
        // .id_ex_inst_dbg   (id_ex_inst_dbg),
        // .id_ex_valid_dbg  (id_ex_valid_dbg),
        // .ex_mem_NPC_dbg   (ex_mem_NPC_dbg),
        // .ex_mem_inst_dbg  (ex_mem_inst_dbg),
        // .ex_mem_valid_dbg (ex_mem_valid_dbg),
        // .mem_wb_NPC_dbg   (mem_wb_NPC_dbg),
        // .mem_wb_inst_dbg  (mem_wb_inst_dbg),
        // .mem_wb_valid_dbg (mem_wb_valid_dbg)
    );


    // Instantiate the Data Memory
    mem memory (
        // Inputs
        .clock            (clock),
        .proc2mem_command (proc2mem_command),
        .proc2mem_addr    (proc2mem_addr),
        .proc2mem_data    (proc2mem_data),
`ifndef CACHE_MODE
        .proc2mem_size    (proc2mem_size),
`endif

        // Outputs
        .mem2proc_transaction_tag (mem2proc_transaction_tag),
        .mem2proc_data            (mem2proc_data),
        .mem2proc_data_tag        (mem2proc_data_tag)
    );


    // Generate System Clock
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end


    // Count the number of posedges and number of instructions completed
    // till simulation ends
    always @(posedge clock) begin
        if(reset) begin
            clock_count <= 0;
            instr_count <= 0;
        end else begin
            clock_count <= clock_count + 1;
            instr_count <= instr_count + pipeline_completed_insts;
        end
    end

    // Task to output the final CPI and # of elapsed clock edges
    task output_cpi_file;
        real cpi;
        int num_cycles;
        begin
            num_cycles = clock_count + 1;
            cpi = $itor(num_cycles) / instr_count; // must convert int to real
            cpi_fileno = $fopen(cpi_output_file);
            $fdisplay(cpi_fileno, "@@@  %0d cycles / %0d instrs = %f CPI",
                      num_cycles, instr_count, cpi);
            $fdisplay(cpi_fileno, "@@@  %4.2f ns total time to execute",
                      num_cycles * `CLOCK_PERIOD);
            $fclose(cpi_fileno);
        end
    endtask // task output_cpi_file
    


    // Show contents of a range of Unified Memory, in both hex and decimal
    // Also output the final processor status
    task show_mem_and_status;
        input EXCEPTION_CODE final_status;
        input [31:0] start_addr;
        input [31:0] end_addr;
        int showing_data;
        begin
            $display("\nFinal memory state and exit status:\n");
            $display("@@@ Unified Memory contents hex on left, decimal on right: ");
            $display("@@@");
            showing_data = 0;
            for (int k = start_addr; k <= end_addr; k = k+1) begin
                if (memory.unified_memory[k] != 0) begin
                    $display("@@@ mem[%5d] = %x : %0d", k*8, memory.unified_memory[k],
                                                             memory.unified_memory[k]);
                    showing_data = 1;
                end else if (showing_data != 0) begin
                    $display("@@@");
                    showing_data = 0;
                end
            end
            $display("@@@");

            case (final_status)
                LOAD_ACCESS_FAULT: $display("@@@ System halted on memory error");
                HALTED_ON_WFI:     $display("@@@ System halted on WFI instruction");
                ILLEGAL_INST:      $display("@@@ System halted on illegal instruction");
                default:           $display("@@@ System halted on unknown error code %x", final_status);
            endcase
            $display("@@@");
        end
    endtask // task show_mem_and_status


    initial begin
        $display("\n---- Starting CPU Testbench ----\n");

        // set paramterized strings, see comment at start of module
        if ($value$plusargs("MEMORY=%s", program_memory_file)) begin
            $display("Using memory file  : %s", program_memory_file);
        end else begin
            $display("Did not receive '+MEMORY=' argument. Exiting.\n");
            $finish;
        end

        if ($value$plusargs("OUTPUT=%s", output_name)) begin
            $display("Using output files : %s.{cpi, wb, ppln}", output_name);
            cpi_output_file       = {output_name,".cpi"}; // this is how you concatenate strings in verilog
            writeback_output_file = {output_name,".wb"};
            pipeline_output_file  = {output_name,".ppln"};
        end else begin
            $display("\nDid not receive '+OUTPUT=' argument. Exiting.\n");
            $finish;
        end

        clock = 1'b0;
        reset = 1'b0;

        $display("\n  %16t : Asserting Reset", $realtime);
        reset = 1'b1;

        @(posedge clock);
        @(posedge clock);

        $display("  %16t : Loading Unified Memory", $realtime);
        // load the compiled program's hex data into the memory module
        $readmemh(program_memory_file, memory.unified_memory);

        @(posedge clock);
        @(posedge clock);
        #1; // This reset is at an odd time to avoid the pos & neg clock edges
        $display("  %16t : Deasserting Reset", $realtime);
        reset = 1'b0;

        wb_fileno = $fopen(writeback_output_file);
        $fdisplay(wb_fileno, "Register writeback output");

        // Open pipeline output file AFTER throwing the reset otherwise the reset state is displayed
        ppln_fileno = $fopen(pipeline_output_file);
        $fdisplay(ppln_fileno, "Out of order pipeline output");
        // print_header();

        $display("  %16t : Running Processor", $realtime);
    end


    always @(negedge clock) begin
        if (!reset) begin
            #2; // wait a short time to avoid a clock edge
            $fdisplay(ppln_fileno, "============= Cycle %d", clock_count);
            print_if_id_reg();
            print_id_ooo_reg();
            print_rob_if_debug();
            print_mem_cache();
            // print_imshr_entries_debug();
            // print_fu_load_packet_debug();
            print_rs_lq_packet();
            print_load_queue();
            print_lq_dcache_packet();
            // print_dcache();
            print_cdb_packet();
            print_fu_state_packet();
            // print_select();
            print_rs();
            print_rob();
            // print_rat();
            // print_rrat();
            print_prf();
            // print_branch_predictor();
        
            $fdisplay(ppln_fileno, "=========");

            // print the pipeline debug outputs via c code to the pipeline output file
            // print_cycles(clock_count);
            // print_stage(if_inst_dbg,     if_NPC_dbg,     {31'b0,if_valid_dbg});
            // print_stage(if_id_inst_dbg,  if_id_NPC_dbg,  {31'b0,if_id_valid_dbg});
            // print_stage(id_ex_inst_dbg,  id_ex_NPC_dbg,  {31'b0,id_ex_valid_dbg});
            // print_stage(ex_mem_inst_dbg, ex_mem_NPC_dbg, {31'b0,ex_mem_valid_dbg});
            // print_stage(mem_wb_inst_dbg, mem_wb_NPC_dbg, {31'b0,mem_wb_valid_dbg});
            // print_reg(pipeline_commit_wr_data,
            //           {27'b0,pipeline_commit_wr_idx}, {31'b0,pipeline_commit_wr_en});
            // print_membus({30'b0,proc2mem_command}, proc2mem_addr[31:0],
            //              proc2mem_data[63:32], proc2mem_data[31:0]);

            // print register write information to the writeback output file
            for (int i = 0; i < pipeline_completed_insts; ++i) begin
                if (pipeline_commit_wr_en[i])
                    $fdisplay(wb_fileno, "PC=%x, REG[%d]=%x",
                              pipeline_commit_NPC[i] - 4,
                              pipeline_commit_wr_idx[i],
                              pipeline_commit_wr_data[i]);
                else
                    $fdisplay(wb_fileno, "PC=%x, ---", pipeline_commit_NPC[i] - 4);
            end

            // stop the processor
            for (int i = 0; i < `N; ++i) begin
                if (pipeline_error_status[i] != NO_ERROR || clock_count > 2000) begin
                    $display("  %16t : Processor Finished", $realtime);

                    // display the final memory and status
                    show_mem_and_status(pipeline_error_status[i], 0,`MEM_64BIT_LINES - 1);
                    // output the final CPI
                    output_cpi_file();
                    // close the writeback and pipeline output files
                    $fclose(ppln_fileno);
                    $fclose(wb_fileno);

                    $display("\n---- Finished CPU Testbench ----\n");

                    #100 $finish;
                end
            end
        end // if(reset)
    end

endmodule // module testbench

