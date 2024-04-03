`include "sys_defs.svh"
`define CPU_DEBUG_OUT


/*
module icache (
    input clock,
    input reset,

    // From memory
    input MEM_TAG   Imem2proc_transaction_tag, // Should be zero unless there is a response
    input MEM_BLOCK Imem2proc_data,
    input MEM_TAG   Imem2proc_data_tag,

    // From fetch stage
    input ADDR [`N-1:0] proc2Icache_addr,
    // TODO add valid check
    input logic [`N-1:0] valid,
    // To memory
    output MEM_COMMAND proc2Imem_command,
    output ADDR        proc2Imem_addr,

    // To fetch stage
    output MEM_BLOCK [`N-1:0] Icache_data_out, // Data is mem[proc2Icache_addr]
    output logic     [`N-1:0] Icache_valid_out // When valid is high
);*/

module testbench;

    logic clock, reset, correct;
    logic [31:0] clock_cycle;

    // From memory
    MEM_TAG   Imem2proc_transaction_tag;
    MEM_BLOCK Imem2proc_data;
    MEM_TAG   Imem2proc_data_tag;
    // From fetch stage
    ADDR [`N-1:0] proc2Icache_addr;
    logic [`N-1:0] valid;
    // To memory
    MEM_COMMAND proc2Imem_command, correct_proc2Imem_command;
    ADDR        proc2Imem_addr, correct_proc2Imem_addr;
    // To fetch stage
    MEM_BLOCK [`N-1:0] Icache_data_out, correct_Icache_data_out;
    logic     [`N-1:0] Icache_valid_out, correct_Icache_valid_out;

    icache dut(
        .clock(clock),
        .reset(reset),
        .Imem2proc_transaction_tag(Imem2proc_transaction_tag),
        .Imem2proc_data(Imem2proc_data),
        .Imem2proc_data_tag(Imem2proc_data_tag),
        .proc2Icache_addr(proc2Icache_addr),
        .valid(valid),
        // output
        .proc2Imem_command(proc2Imem_command),
        .proc2Imem_addr(proc2Imem_addr),
        .Icache_data_out(Icache_data_out),
        .Icache_valid_out(Icache_valid_out)
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
        if (clock && ~reset) begin
            clock_cycle += 1;
        end
    end

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            $display("@@@ Failed ENDING TESTBENCH : ERROR !");
            print_icache_output();
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (~correct) begin
            exit_on_error();
        end
    end


    task print_icache_output;
        $display("========= Clock: %2d =========", clock_cycle);
        if (proc2Imem_command == MEM_NONE) begin
            $display("proc2Imem_command: MEM_NONE");
        end else if (proc2Imem_command == MEM_LOAD) begin
            $display("proc2Imem_command: MEM_LOAD");
            $display("proc2Imem_addr: %2d", proc2Imem_addr);
        end
        for (int i = 0; i < `N; i = i + 1) begin
            if (Icache_valid_out[i]) begin
                $display("Icache_data_out[%2d]: %2d", i, Icache_data_out[i]);
            end else begin
                $display("Icache_data_out[%2d]: invalid", i);
            end
        end
    endtask

    task init;
        reset   = 1;
        correct = 1;

        Imem2proc_transaction_tag = 0;
        Imem2proc_data            = 0;
        Imem2proc_data_tag        = 0;

        proc2Icache_addr = 0;
        valid            = {`N{`FALSE}};

        @(negedge clock);
        reset = 0;
        @(negedge clock);
    endtask

    task test_cache_miss;
        init();
        proc2Icache_addr = 0;
        valid[0]         = `TRUE;
        
        #(`CLOCK_PERIOD/5);

        correct_proc2Imem_command = MEM_NONE;
        correct_Icache_valid_out  = {`N{`FALSE}};
        correct = correct && (proc2Imem_command == correct_proc2Imem_command) && (Icache_valid_out == correct_Icache_valid_out);
        print_icache_output();

        @(negedge clock);
        #1;
        print_icache_output();
        correct_proc2Imem_command = MEM_LOAD;
        correct_proc2Imem_addr    = 0;
        correct = correct && (proc2Imem_command == correct_proc2Imem_command)
              && (proc2Imem_addr == correct_proc2Imem_addr)
              && (Icache_valid_out == correct_Icache_valid_out);
        
        $display("@@@ Passed test_cache_miss");
    endtask
    
    initial begin
        clock = 0;
        clock_cycle = 0;

        test_cache_miss();
        $display("@@@ Passed");
        $finish;
    end

endmodule