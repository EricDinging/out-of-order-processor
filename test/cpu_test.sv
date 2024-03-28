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
    string cpi_output_file, writeback_output_file; //, pipeline_output_file;
    int cpi_fileno, wb_fileno; // verilog uses integer file handles with $fopen and $fclose

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
    ID_OOO_PACKET id_ooo_reg_debug;
`endif

    // ADDR  if_NPC_dbg;
    // DATA  if_inst_dbg;
    // logic if_valid_dbg;
    // ADDR  if_id_NPC_dbg;
    // DATA  if_id_inst_dbg;
    // logic if_id_valid_dbg;
    // ADDR  id_ex_NPC_dbg;
    // DATA  id_ex_inst_dbg;
    // logic id_ex_valid_dbg;
    // ADDR  ex_mem_NPC_dbg;
    // DATA  ex_mem_inst_dbg;
    // logic ex_mem_valid_dbg;
    // ADDR  mem_wb_NPC_dbg;
    // DATA  mem_wb_inst_dbg;
    // logic mem_wb_valid_dbg;


    task print_if_id_reg;
        $display("IF/ID Register:");
        for (int i = 0; i < `N; ++i) begin
            $display("  PC[%0d]: %x", i, if_id_reg_debug[i].PC);
            $display("  Instruction[%0d]: %x", i, if_id_reg_debug[i].inst);
            $display("  Valid[%0d]: %x", i, if_id_reg_debug[i].valid);
        end
    endtask

    task print_id_ooo_reg;
        $display("ID/EX Register:");
        for (int i = 0; i < `N; ++i) begin
            $display("  PC[%0d]: %0d", i, id_ooo_reg_debug.rob_is_packet.entries[i].PC);
            $display("  dest_arn[%0d]: %0d", i, id_ooo_reg_debug.rat_is_input.entries[i].dest_arn);
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
        .if_id_reg_debug (if_id_reg_debug),
        .id_ooo_reg_debug(id_ooo_reg_debug),

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

        // P4 TODO: You must keep cpi and memory output the same for the autograder,
        //          but you should add new output files to print your own data structures.
        if ($value$plusargs("OUTPUT=%s", output_name)) begin
            $display("Using output files : %s.{cpi, wb}"/*, ppln}*/, output_name);
            cpi_output_file       = {output_name,".cpi"}; // this is how you concatenate strings in verilog
            writeback_output_file = {output_name,".wb"};
            // pipeline_output_file  = {output_name,".ppln"};
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
        // open_pipeline_output_file(pipeline_output_file);
        // print_header();

        $display("  %16t : Running Processor", $realtime);
    end


    always @(negedge clock) begin
        if (!reset) begin
            #2; // wait a short time to avoid a clock edge
            print_if_id_reg();
            print_id_ooo_reg();

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
                if (pipeline_error_status[i] != NO_ERROR || clock_count > 50000000) begin
                    $display("  %16t : Processor Finished", $realtime);

                    // display the final memory and status
                    show_mem_and_status(pipeline_error_status[i], 0,`MEM_64BIT_LINES - 1);
                    // output the final CPI
                    output_cpi_file();
                    // close the writeback and pipeline output files
                    // close_pipeline_output_file();
                    $fclose(wb_fileno);

                    $display("\n---- Finished CPU Testbench ----\n");

                    #100 $finish;
                end
            end
        end // if(reset)
    end

endmodule // module testbench
