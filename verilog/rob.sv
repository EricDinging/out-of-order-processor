`include "sys_defs.svh"

module rob #(
    parameter SIZE = `ROB_SZ,
    parameter ALERT_DEPTH = `N
)(
    input clock, reset,
    
    input ROB_IS_PACKET rob_is_packet,

    input [`NUM_FU_ALU-1:0]   FU_ROB_PACKET fu_alu_packet,
    input [`NUM_FU_MULT-1:0]  FU_ROB_PACKET fu_mult_packet,
    input [`NUM_FU_LOAD-1:0]  FU_ROB_PACKET fu_load_packet,
    input [`NUM_FU_STORE-1:0] FU_ROB_PACKET fu_store_packet,

    output almost_full,
    output ROB_CT_PACKET rob_ct_packet, 
    output ROBN tail
);
    // TODO break out FIFO module
    FIFO#(.SIZE=`ROB_SZ, .WIDTH=, .ALERT_DEPTH=`N) rob_fifo;
 
    always_comb begin
        
    end

    always_ff @(posedge clock) begin

    end
endmodule
