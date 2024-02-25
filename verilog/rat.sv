`include "sys_defs.svh"

module rat(
    input clock, reset,
    input RAT_IS_INPUT rat_is_input,
    input RRAT_CT_OUTPUT rrat_ct_output,


    output RAT_IS_OUTPUT rat_is_output,
);
    free_list free_l;
    PRN [31:0] rat_table;
    PRN [31:0] next_rat_table;

    always_comb begin
        // If squash, copy entire table and free list
        // else, push valid PR into free list
    end

    always_ff @(posedge clock) begin

    end


endmodule
