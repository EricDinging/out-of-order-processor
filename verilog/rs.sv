`include "sys_defs.svh"

module rs #(
    parameter SIZE = `RS_SZ,
    parameter ALERT_DEPTH = `N
)(
    input clock, reset,
    
    input RS_IS_PACKET rs_is_packet,

    input [`N-1:0] CDB_PACKET cdb_packet,
    
    input [`NUM_FU_ALU-1:0]   logic fu_alu_avail,
    input [`NUM_FU_MULT-1:0]  logic fu_mult_avail,
    input [`NUM_FU_LOAD-1:0]  logic fu_load_avail,
    input [`NUM_FU_STORE-1:0] logic fu_store_avail,
    
    output [`NUM_FU_ALU-1:0]   FU_PACKET fu_alu_packet,
    output [`NUM_FU_MULT-1:0]  FU_PACKET fu_mult_packet,
    output [`NUM_FU_LOAD-1:0]  FU_PACKET fu_load_packet,
    output [`NUM_FU_STORE-1:0] FU_PACKET fu_store_packet,

    output logic almost_full
);

    parameter CNT_WIDTH = $clog2(SIZE);
    logic [CNT_WIDTH-1:0] counter;

    psel_gen#(.WIDTH = `RS_SZ, .REQS = `NUM_FU_ALU)   alu_sel;
    psel_gen#(.WIDTH = `RS_SZ, .REQS = `NUM_FU_MULT)  mult_sel;
    psel_gen#(.WIDTH = `RS_SZ, .REQS = `NUM_FU_LOAD)  load_sel;
    psel_gen#(.WIDTH = `RS_SZ, .REQS = `NUM_FU_STORE) store_sel;
    
    // Combinational
    always_comb begin
        for (int i = 0; i < SIZE; i++) {
            // Check CDB value

            // Input new value
            
        }
    end


    // Sequential
    always_ff @(posedge clock) begin
        
    end

endmodule

