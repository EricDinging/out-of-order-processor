`include "sys_defs.svh"

module rrat #(
    parameter SIZE = `ARCH_REG_SZ,
)(
    input clock, reset,
    input RRAT_CT_INPUT rrat_ct_input,

    output RRAT_CT_OUTPUT rrat_ct_output,
);

    PRN [SIZE-1:0] rrat_table, next_rrat_table;
    logic          success, next_success;
    
    FREE_LIST_PACKET [`N-1:0] push_packet;
    // FREE_LIST_PACKET [`N-1:0] pop_packet;
    logic            [`N-1:0] pop_en;

    rrat_free_list free_l(
        .clock(clock),
        .reset(reset),
        .push_packet(push_packet),
        .pop_en(pop_en),
        .intput_free_list({`PHYS_REG_SZ_R10K{0}}),
        .rat_squash(0),
        .head_in(0),
        .tail_in(0),
        .counter_in(0),
        // output
        .pop_packet(),
        .output_free_list(rrat_ct_output.free_list),
        .head_out(rrat_ct_output.head),
        .tail_out(rrat_ct_output.tail),
        .counter_out(rrat_ct_output.free_list_counter),
    );

    always_comb begin
        next_success    = `TRUE;
        next_rrat_table = rrat_table;
        pop_en          = {`N{`FALSE}};
        for (int i = 0; i < N; i++) begin
            push_packet[i].valid = `FALSE;
            push_packet[i].prn   = 0;
        end

        for (int i = 0; i < N; i++) begin
            if (rrat_ct_input.success[i] && next_success) begin
                if (!rrat_ct_input[i].arns[0]) begin
                    next_rrat_table[rrat_ct_input[i].arns[0]] = rrat_ct_input[i].prn;
                    pop_en[i]                                 = `TRUE;
                    push_packet[i].valid                      = `TRUE;
                    push_packet[i].prn                        = rrat_ct_input[i].prn;
                end
            end else begin
                next_success = `FALSE;
            end
        end
    end

    assign rrat_ct_output.squash  = ~success;
    assign rrat_ct_output.entries = rrat_table;

    always_ff @(posedge clock) begin
        if (reset) begin
            success <= `TRUE;
            for (int i = 0; i < SIZE; i++) begin
                rrat_table[i].valid <= `FALSE;
                rrat_table[i].prn   <= 0;
            end
        end else begin
            success    <= next_success;
            rrat_table <= next_rrat_table;
        end
    end

    

endmodule
