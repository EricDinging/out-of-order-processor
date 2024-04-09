`include "sys_defs.svh"

module load_queue (
    input logic clock, reset,
    // rs
    input  RS_LQ_PACKET          [`NUM_FU_LOAD-1:0] rs_lq_packet,
    // cdb
    output logic                 [`NUM_FU_LOAD-1:0] load_prepared,
    output FU_STATE_BASIC_PACKET [`NUM_FU_LOAD-1:0] load_packet,
    // SQ
    output  ADDR  [`NUM_FU_LOAD-1:0] sq_addr,
    output  logic [`NUM_FU_LOAD-1:0][`SQ_IDX_BITS-1:0] store_range,
    input DATA  [`NUM_FU_LOAD-1:0] value,
    input logic [`NUM_FU_LOAD-1:0] fwd_valid,
    // Dcache
    output LQ_DCACHE_PACKET [`NUM_LU_DCACHE-1:0] lq_dcache_packet,
    input DCACHE_LQ_PACKET [`N-1:0] dcacahe_lq_packet,
    input logic      [`NUM_LU_DCACHE-1:0] load_req_accept,
    input DATA [`NUM_LU_DCACHE-1:0] load_req_data,
    input logic [`NUM_LU_DCACHE-1:0] load_req_data_valid
`ifdef CPU_DEBUG_OUT

`endif
);

endmodule
