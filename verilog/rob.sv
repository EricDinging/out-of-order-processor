`include "sys_defs.svh"

module rob #(
    parameter SIZE = `ROB_SZ,
    parameter ALERT_DEPTH = `N
)(
    input clock, reset,
    
    input ROB_IS_PACKET rob_is_packet,

    input FU_ROB_PACKET [`CDB_SZ-1:0] fu_rob_packet,

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
