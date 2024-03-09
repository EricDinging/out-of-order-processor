`include "sys_defs.svh"
// PRN, DATA
/*
typedef struct packed {
    logic valid;
    DATA value;
} PRF_ENTRY;

typedef struct packed {
    DATA value; // valid here means to write or not
    PRN prn;
} PRF_WRITE;

*/
module testbench;
    logic clock, reset, correct;
    PRN [2*`N-1:0] read_prn;
    PRF_ENTRY [2*`N-1:0] output_value;
    PRF_WRITE [`N-1:0] write_data;
    PRN [`N-1:0] prn_invalid;

    PRF_ENTRY [`PHYS_REG_SZ_R10K-1:0] entries, entries_out;
    PRN counter, counter_out;
    PRN temp;
    
    prf dut(
        .clock(clock),
        .reset(reset),
        .read_prn(read_prn),
        .output_value(output_value),
        .write_data(write_data),
        .prn_invalid(prn_invalid),
        .entries_out(entries_out),
        .counter(counter_out)
    );
    
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task write(int i, PRN prn, PRF_ENTRY entry);
        // ground truth
        if (prn != 0) begin
            entries[prn] = entry;
            counter += entry.valid;
        end

        write_data[i] = '{entry.value, prn};
    endtask

    task write_invalid(int i, PRN prn);
        // ground truth
        if (prn != 0) begin
            counter -= entries[prn].valid;   
            entries[prn].valid = `FALSE;
        end

        prn_invalid[i] = prn;
        $display("setting 0x%02x invalid", prn);
    endtask

    task check_table_match;
        for (int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
            correct = correct 
                && (entries[i].valid == entries_out[i].valid)
                && (!entries[i].valid || entries[i].value == entries_out[i].value);
        end
        correct = correct && (counter == counter_out);
    endtask

    task read_and_write;
        write_invalid($random % 2, 4);
        @(negedge clock);
        for (int i = 0; i < 2*`N; i++) begin
            write(i, i, {$random, `TRUE});
            read_prn[i] = i + 2;
        end
        #(`CLOCK_PERIOD/5.0);
        check_read;
        @(negedge clock);
        $display("@@@ Passed: read_and_write\n");
    endtask

    task check_read;
        for (int i = 0; i < 2*`N; i++) begin
            correct = correct && (output_value[i].valid == entries[read_prn[i]].valid);
            correct = correct && (!output_value[i].valid || output_value[i].value == entries[read_prn[i]].value);
        end
    endtask



    task init;
        reset = 1;
        correct = 1;
        entries[0].valid = `TRUE;
        entries[0].value = 0;
        prn_invalid = 0;
        write_data = 0;
        for (int i = 1; i < `PHYS_REG_SZ_R10K; i++) begin
            entries[i].valid = `FALSE;
        end
        counter = 0;
        
        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        @(negedge clock);
        
    endtask

    task set_full;
        for (int i = 0; i < `PHYS_REG_SZ_R10K/`N; i++) begin 
            for (int j = 0; j < `N; j++) begin
                write(j, i * `N + j, '{`TRUE, $random});
            end
            @(negedge clock);
            check_table_match;
        end
        @(negedge clock);
        write_data = 0;
        $display("@@@ Passed: set_full\n");
    endtask

    task set_invalid;
        for (int i = 0; i < 10; i++) begin
            for (int j = 0; j < `N; j++) begin
                write_invalid(j, $urandom % `PHYS_REG_SZ_R10K);
            end
            @(negedge clock);
            check_table_match;
        end
        @(negedge clock);
        $display("@@@ Passed: set_invalid\n");
    endtask
    
    task read;
        for (int i = 0; i < `N; i++) begin
            for (int j = 0; j < 2; j++) begin
                read_prn[i * 2 + j] = $urandom % `PHYS_REG_SZ_R10K;
            end
        end
        #(`CLOCK_PERIOD/5.0);
        check_read;
        @(negedge clock);
        $display("@@@ Passed: read\n");
    endtask
    

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f, clock %b\n", $time, clock);
            for (int i = 0; i < `PHYS_REG_SZ_R10K; i++) begin
                $display("prn %02x: value 0x%08x, valid %b, true_value 0x%08x, true_valid %b\n", i, entries_out[i].value, entries_out[i].valid, entries[i].value, entries[i].valid);
            end
            $display("counter:%d, true_counter: %d", counter_out, counter);
            $display("@@@ Failed PRF test!");
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (!correct) begin
            exit_on_error();
        end
    end

    initial begin
        $display("PRF size %d\n", `PHYS_REG_SZ_R10K);
        clock = 0;
        init; 
        set_full;
        set_invalid;

        init; 
        set_full;
        read;

        init;
        set_full;
        read_and_write;

        $finish;
    end
endmodule