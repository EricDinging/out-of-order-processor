`include "sys_defs.svh"

module rrat #(
    parameter SIZE = `ARCH_REG_SZ
) (
    input clock, reset,
    input RRAT_CT_INPUT rrat_ct_input,

    output RRAT_CT_OUTPUT rrat_ct_output
);
    // state
    PRN [SIZE-1:0] rrat_table, next_rrat_table;
    logic          success, next_success;
    
    FREE_LIST_PACKET [`N-1:0] push_packet;   // pr that is released
    logic            [`N-1:0] pop_en;
    FREE_LIST_PACKET [`N-1:0] pop_packet;

    rrat_free_list free_l(
        .clock(clock),
        .reset(reset),
        .push_packet(push_packet),
        .pop_en(pop_en),
        // output
        .pop_packet(pop_packet),
        .output_free_list(rrat_ct_output.free_list),
        .head_out(rrat_ct_output.head),
        .tail_out(rrat_ct_output.tail),
        .counter_out(rrat_ct_output.free_list_counter)
    );

    always_comb begin
        next_success    = `TRUE;
        next_rrat_table = rrat_table;
        pop_en          = {`N{`FALSE}};
        for (int i = 0; i < `N; i++) begin
            push_packet[i].valid = `FALSE;
            push_packet[i].prn   = 0;
        end

        for (int i = 0; i < `N; i++) begin
            if (rrat_ct_input.success[i] && next_success) begin
                if (rrat_ct_input.arns[i] != 0) begin
                    push_packet[i].prn                     = next_rrat_table[rrat_ct_input.arns[i]];
                    push_packet[i].valid                   = `TRUE;
                    pop_en[i]                              = `TRUE;
                    next_rrat_table[rrat_ct_input.arns[i]] = pop_packet[i].prn;
                end
            end else begin
                next_success = `FALSE;
            end
        end
    end

    assign rrat_ct_output.squash  = ~success;
    assign rrat_ct_output.entries = rrat_table;
    assign rrat_ct_output.free_packet = push_packet;

    always_ff @(posedge clock) begin
        if (reset) begin
            success <= `TRUE;
            for (int i = 0; i < SIZE; i++) begin
                rrat_table[i] = i;
            end
            
        end else begin
            success    <= next_success;
            rrat_table <= next_rrat_table;
        end
    end

endmodule
