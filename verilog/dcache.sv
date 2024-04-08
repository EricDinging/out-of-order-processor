`include "verilog/sys_defs.svh"
`define CPU_DEBUG_OUT

typedef struct packet {
    MEM_BLOCK                     data;
    logic [26-`DCACHE_INDEX_BITS] tag; // 32 - 6 block index bits
    logic                         valid;
    logic                         dirty;
} DCACHE_ENTRY;

module dmshr (

);

endmodule
/*
module icache (
    input clock,
    input reset,
    input squash,
    // From memory
    input MEM_TAG   Imem2proc_transaction_tag,
    input MEM_BLOCK Imem2proc_data,
    input MEM_TAG   Imem2proc_data_tag,
    // From fetch stage
    input ADDR  [`N-1:0] proc2Icache_addr,
    input logic [`N-1:0] valid,
    // From Dcache
    input logic  dcache_request,
    // To memory
    output MEM_COMMAND proc2Imem_command,
    output ADDR        proc2Imem_addr,
    // To fetch
    output MEM_BLOCK [`N-1:0] Icache_data_out,
    output logic     [`N-1:0] Icache_valid_out
`ifdef CPU_DEBUG_OUT
    , output IMSHR_ENTRY [`N-1:0] imshr_entries_debug
`endif
);
*/

module dcache #(
    parameter SIZE = `DCACHE_LINES,
)(
    input clock,
    input reset,
    // From memory
    input MEM_TAG   Dmem2proc_transaction_tag,
    input MEM_BLOCK Dmem2proc_data,
    input MEM_TAG   Dmem2proc_data_tag,
    // From LSQ
    LQ_DCACHE_PACKET [`N-1:0] lq_dcache_packet,
    SQ_DCACHE_PACKET [`N-1:0] sq_dcache_packet,
    // To memory
    output MEM_COMMAND proc2Dmem_command,
    output ADDR        proc2Dmem_addr,
    // To LSQ current result
    output logic     [`N-1:0] store_req_accept,
    output logic     [`N-1:0] load_req_accept,
    output MEM_BLOCK [`N-1:0] load_req_data,
    // To LSQ future request
    output DCACHE_LQ_PACKET [`N-1:0] dcache_lq_packet
);

endmodule
