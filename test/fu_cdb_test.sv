
`include "sys_defs.svh"
`include "ISA.svh"
module testbench;

    logic clock, reset, correct;

    FU_PACKET   [`NUM_FU_ALU-1:0] fu_alu_packet;
    FU_PACKET  [`NUM_FU_MULT-1:0] fu_mult_packet;
    FU_PACKET  [`NUM_FU_LOAD-1:0] fu_load_packet;
    FU_PACKET [`NUM_FU_STORE-1:0] fu_store_packet;
    logic       [`NUM_FU_ALU-1:0]  alu_avail;
    logic      [`NUM_FU_MULT-1:0] mult_avail;
    logic      [`NUM_FU_LOAD-1:0] load_avail;
    logic     [`NUM_FU_STORE-1:0] store_avail;

    FU_ROB_PACKET [`NUM_FU_ALU-1:0] cond_rob_packet;
    FU_ROB_PACKET [`N-1:0]          cdb_rob_packet;
    CDB_PACKET    [`N-1:0]          cdb_output;

    // testing parameters
    FU_ROB_PACKET [`NUM_FU_ALU-1:0] correct_cond_rob_packet;
    
    // debug output 
    FU_STATE_PACKET fu_state_packet_debug;
    logic [`NUM_FU_ALU+`NUM_FU_MULT+`NUM_FU_LOAD-1:0] select_debug;


    fu_cdb dut(
        .clock(clock),
        .reset(reset),
        .fu_alu_packet(fu_alu_packet),
        .fu_mult_packet(fu_mult_packet),
        .fu_load_packet(fu_load_packet),
        .fu_store_packet(fu_store_packet),
        .alu_avail(alu_avail),
        .mult_avail(mult_avail),
        .load_avail(load_avail),
        .store_avail(store_avail),
        .fu_rob_packet({cond_rob_packet, cdb_rob_packet}),
        .cdb_output(cdb_output)
        `ifdef CPU_DEBUG_OUT
        , .fu_state_packet_debug(fu_state_packet_debug)
        , .select_debug(select_debug)
        `endif
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f", $time);
            // $display("Time:%4.0f clock:%b counter:%b, almost_full:%b\n", $time, clock, counter_out, almost_full);
            // $display(fmt, $time, clock, counter_out, almost_full, entries_out, rs_is_packet, 
            //          fu_alu_packet, fu_mult_packet, fu_load_packet, fu_store_packet, cdb_packet);
            $display("@@@ Failed ENDING TESTBENCH : ERROR !");
            $finish;
        end
    endtask
    
    task setInvalid;
        for (int i = 0; i < `NUM_FU_ALU; i++) begin
            fu_alu_packet[i].valid = 0;
        end
        for (int i = 0; i < `NUM_FU_MULT; i++) begin
            fu_mult_packet[i].valid = 0;
        end
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            fu_load_packet[i].valid = 0;
        end
        for (int i = 0; i < `NUM_FU_STORE; i++) begin
            fu_store_packet[i].valid = 0;
        end
    endtask

    task init;
        reset = 1;
        correct = 1;
        setInvalid;
        @(negedge clock);
        reset = 0;
    endtask



    // typedef struct packed {
    //     logic   valid;
    //     INST    inst;
    //     ADDR    PC;
    //     FU_FUNC func;
    //     DATA    op1, op2;
    //     PRN     dest_prn;
    //     ROBN    robn;
    //     ALU_OPA_SELECT opa_select; // used for select signal in FU
    //     ALU_OPB_SELECT opb_select; // same as above
    //     logic cond_branch;
    //     logic uncond_branch;
    // } FU_PACKET;

    task set_n_alu;
        input int n;
        for (int i = 0; i < n; ++i) begin
            fu_alu_packet[i].valid         = `TRUE;
            fu_alu_packet[i].inst          = `RV32_ADD;
            fu_alu_packet[i].PC            = 0;
            fu_alu_packet[i].func.alu      = ALU_ADD;
            fu_alu_packet[i].op1           = 1;
            fu_alu_packet[i].op2           = 1;
            fu_alu_packet[i].dest_prn      = 1;
            fu_alu_packet[i].opa_select    = OPA_IS_RS1;
            fu_alu_packet[i].opb_select    = OPB_IS_RS2;
            fu_alu_packet[i].cond_branch   = `FALSE;
            fu_alu_packet[i].uncond_branch = `FALSE;
        end
    endtask

    task print_cdb;
        for (int i = 0; i < `N; ++i) begin
            $display(
                "cdb_output[%1d].dest_prn = %2d, cdb_output[%1d].value = 0x%08x",
                i, cdb_output[i].dest_prn, i, cdb_output[i].value
            );
        end
    endtask

    task mixed_alu_w_cond_branch;
        int count;
        init;

        fu_alu_packet[0] = '{
            1, // valid
            `RV32_ADD, // inst
            32'h00000000, // PC
            ALU_ADD, // func
            32'h00000001, // op1
            32'h00000002, // op2
            5'h01, // dest_prn
            5'h00, // robn
            OPA_IS_RS1, // opa_select
            OPB_IS_RS2, // opb_select
            0, // cond_branch
            0 // uncond_branch
        };
        fu_alu_packet[1] = '{
            1, // valid
            {{7{1'b0}},{5{1'b0}},{5{1'b0}},3'b000,{5{1'b0}},`RV32_BRANCH}, // inst // BEQ
            32'h00000003, // PC
            ALU_ADD, // func
            32'h00000001, // op1
            32'h00000001, // op2
            5'h02, // dest_prn
            5'h01, // robn
            OPA_IS_RS1, // opa_select
            OPB_IS_RS2, // opb_select
            1, // cond_branch
            0 // uncond_branch
        };

        // cond_rob_packet
        correct_cond_rob_packet[1] = '{
            5'h01, // robn
            1, // prepared
            1, // take_branch
            32'h00000003 // result
        };
        #(`CLOCK_PERIOD/5.0);
        count = 0;
        correct = cond_rob_packet[1] == correct_cond_rob_packet[1];
        @(negedge clock);
        for (int i = 0; i < `N; i++) begin
            $display("cdb_output[%0d].dest_prn = %0d, cdb_output[%0d].value = %0d", i, cdb_output[i].dest_prn, i, cdb_output[i].value);
            if (cdb_output[i].dest_prn != 0)
                ++count;
        end
        correct &= count == 1;
    endtask

    task more_than_n_alu;
        int n;
        int count;
        init;
        count = 0;
        n = `N + 1;
        set_n_alu(n);
        // @(negedge clock);
        @(negedge clock);
        // correct = &alu_avail[`NUM_FU_ALU-1:`N + 2] && ~|alu_avail[`N + 1:`N] && &alu_avail[`N-1:0];
        for (int i = 0; i < `N; ++i) begin
            if (cdb_output[i].dest_prn == 1 && cdb_output[i].value == 2)
                ++count;
        end
        correct &= count == n;
    endtask

    task exactly_n_alu;
        int n;
        int count;
        init;
        print_cdb;
        count = 0;
        n = `N;
        @(negedge clock);
        set_n_alu(n);
        print_cdb;

        @(negedge clock);
        print_cdb;
        @(negedge clock);
        $display("alu_avail = %0d, mult_avail = %0d", alu_avail, mult_avail);
        correct = &alu_avail && &mult_avail;
        print_cdb;
        for (int i = 0; i < `N; ++i) begin
            if (cdb_output[i].dest_prn == 1 && cdb_output[i].value == 2) ++count;
        end
        correct = count == n;
    endtask

    task less_than_n_alu;
        int n;
        int count;
        init;
        count = 0;
        n = `N - 1;
        set_n_alu(n);
        @(negedge clock);
        @(negedge clock);
        
        correct = &alu_avail && &mult_avail;
        for (int i = 0; i < `N; ++i) begin
            $display("cdb_output[%0d].dest_prn = %0d, cdb_output[%0d].value = %0d", i, cdb_output[i].dest_prn, i, cdb_output[i].value);
            if (cdb_output[i].dest_prn == 1 && cdb_output[i].value == 2)
                ++count;
        end
        correct &= count == n;
    endtask

    task set_n_mult;
    endtask
    
    task only_mult;
        init;
        for (int i = 0; i < `NUM_FU_MULT; i++) begin
            fu_mult_packet[i] = '{
                1'b1,
                32'b0, // dummy
                32'b0,
                M_MUL,
                32'h5,
                32'h5,
                5'h1,
                5'h1,
                OPA_IS_RS1, // unused
                OPB_IS_RS2, // unused
                1'b0,
                1'b0
            };
        end
        @(negedge clock);
        setInvalid;
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        for (int i = 0; i < `N; i++) begin
            correct = correct && mult_avail[i];
            correct = correct && !cond_rob_packet[i].executed;
            correct = correct && cdb_rob_packet[i].robn == 1;
            correct = correct && cdb_rob_packet[i].executed;
            correct = correct && cdb_output[i].dest_prn == 1;
            correct = correct && cdb_output[i].value == 25;
        end
    endtask

    task mult_w_alu;
    endtask


    always_ff @(negedge clock) begin
        if (!correct) begin
            exit_on_error();
        end
    end

    initial begin
        clock = 0;
        // mixed_alu_w_cond_branch;
        // more_than_n_alu;
        exactly_n_alu;
        // less_than_n_alu;
        // only_mult;
        $finish;
    end
    
endmodule
