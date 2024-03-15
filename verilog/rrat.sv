`include "sys_defs.svh"

module rrat(
    input clock, reset,
    input RRAT_CT_INPUT rrat_ct_input,


    output RRAT_CT_OUTPUT rrat_ct_output,
);
    rrat_free_list free_l;
    PRN [31:0] rrat_table;
    PRN [31:0] next_rrat_table;

    always_comb begin
        // before squash, set valid for corresponding PR
        // when meeting squash, output entire table and free list
        // if squash, update prn by RRAT or RRAT free list
    end

    always_ff @(posedge clock) begin
        if reset begin
        end else begin
        end
    end

    

endmodule
