`include "sys_defs.svh"
`define CPU_DEBUG_OUT

// `ifdef CPU_DEBUG_OUT
// `ifndef DEBUG_OUT
// `define DEBUG_OUT
// `endif
// `endif

module rat #(
    parameter SIZE = `ARCH_REG_SZ
) (
    input clock, reset,

    input RAT_IS_INPUT rat_is_input,
    input RRAT_CT_OUTPUT rrat_ct_output,
    output RAT_IS_OUTPUT rat_is_output

`ifdef CPU_DEBUG_OUT
    , output PRN                              head, tail
    , output logic [`FREE_LIST_CTR_WIDTH-1:0] counter
    , output PRN   [`PHYS_REG_SZ_R10K-1:0]    free_list
    , output PRN   [SIZE-1:0]                 rat_table_out
`endif
);
    PRN [SIZE-1:0] rat_table, next_rat_table;

    logic            [`N-1:0] pop_en;
    FREE_LIST_PACKET [`N-1:0] pop_packet;

    rat_free_list free_l(
        .clock(clock),
        .reset(reset),
        .push_packet(rrat_ct_output.free_packet),
        .pop_en(pop_en),
        .input_free_list(rrat_ct_output.free_list),
        .head_in(rrat_ct_output.head),
        .tail_in(rrat_ct_output.tail),
        .counter_in(rrat_ct_output.free_list_counter),
        .rat_squash(rrat_ct_output.squash),
        // output
        .pop_packet(pop_packet)
        `ifdef CPU_DEBUG_OUT
        , .head(head)
        , .tail(tail)
        , .counter(counter)
        , .free_list(free_list)
        `endif
    );

    always_comb begin
        next_rat_table = rat_table;

        for (int i = 0; i < `N; ++i) begin
            rat_is_output.entries[i].dest_prn = 0;
            rat_is_output.entries[i].op1_prn = 0;
            rat_is_output.entries[i].op2_prn = 0;
        end
        
        pop_en = {`N{`FALSE}};
        
        if (rrat_ct_output.squash) begin
            next_rat_table = rrat_ct_output.entries;
        end else begin
            for (int i = 0; i < `N; ++i) begin
                rat_is_output.entries[i].op1_prn = next_rat_table[rat_is_input.entries[i].op1_arn];
                rat_is_output.entries[i].op2_prn = next_rat_table[rat_is_input.entries[i].op2_arn];
                if (rat_is_input.entries[i].dest_arn != `ZERO_REG) begin
                    pop_en[i] = `TRUE;
                    if (pop_packet[i].valid) begin
                        next_rat_table[rat_is_input.entries[i].dest_arn] = pop_packet[i].prn;
                        rat_is_output.entries[i].dest_prn                = pop_packet[i].prn;
                    end
                end
            end
        end
    end

    `ifdef CPU_DEBUG_OUT
        assign rat_table_out = rat_table;
    `endif

    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < SIZE; i++) begin
                rat_table[i] <= i;
            end
        end else begin
            rat_table <= next_rat_table;
        end
    end

endmodule
