`include "verilog/sys_defs.svh"
`define CACHE_LINES 32
`define CACHE_LINE_BITS $clog2(`CACHE_LINES)

typedef struct packed {
    MEM_BLOCK                     data;
    // (13 bits) since only need 16 bits to access all memory and 3 are the offset
    logic [12-`CACHE_LINE_BITS:0] tags;
    logic                         valid;
} ICACHE_ENTRY;

module imshr (
    input clock,
    input reset
);

    IMSHR_ENTRY [`N-1:0] ishr_entries, next_ishr_entries;

    always_comb begin
        next_ishr_entries = ishr_entries;
        
    end

    always_ff(@posedge clock) begin
        if (reset) begin
            ishr_entries <= 0;
        end else begin
            ishr_entries <= next_ishr_entries;
        end
    end
endmodule

module icache_nb (
    input clock,
    input reset,
    // From memory
    input MEM_TAG   Imem2proc_transaction_tag,
    input MEM_BLOCK Imem2proc_data,
    input MEM_TAG   Imem2proc_data_tag,
    // From fetch stage
    input ADDR  [`N-1:0] proc2Icache_addr,
    input logic [`N-1:0] valid,
    // To memory
    output MEM_COMMAND proc2Imem_command,
    output ADDR        proc2Imem_addr,
    // To fetch
    output MEM_BLOCK [`N-1:0] Icache_data_out,
    output logic     [`N-1:0] Icache_valid_out
);
    ICACHE_ENTRY [`CACHE_LINES-1:0] icache_data, next_icache_data;

    imshr mshr (
        .clock(clock),
        .reset(reset)
    );

    always_comb begin
        next_icache_data = icache_data;
    end

    always_ff(@posedge clock) begin
        if (reset) begin
            icache_data <= 0;
        end else begin
            icache_data <= next_icache_data;
        end
    end
    
endmodule