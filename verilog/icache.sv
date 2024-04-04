`include "verilog/sys_defs.svh"

typedef struct packed {
    MEM_BLOCK                     data;
    // (13 bits) since only need 16 bits to access all memory and 3 are the offset
    logic [12-`CACHE_LINE_BITS:0] tags;
    logic                         valid;
} ICACHE_ENTRY;

module imshr (
    input clock,
    input reset,
    // From dcache
    input logic  dcache_request,
    // From memory
    input MEM_TAG   Imem2proc_transaction_tag,
    input MEM_TAG   Imem2proc_data_tag,
    // From icache
    input logic [`N-1:0][`CACHE_LINE_BITS-1:0]  miss_cache_indexes,
    input logic [`N-1:0][12-`CACHE_LINE_BITS:0] miss_cache_tags,
    input logic [`N-1:0]                        miss_cache_valid,

    // Output to memory via cache
    output ADDR        proc2Imem_addr,
    output MEM_COMMAND proc2Imem_command,
    // Output to cache
    output logic [`CACHE_LINE_BITS-1:0]  cache_index,
    output logic [12-`CACHE_LINE_BITS:0] cache_tag,
    output logic ready
`ifdef CPU_DEBUG_OUT
    , output IMSHR_ENTRY [`N-1:0] imshr_entries_debug
`endif
);

    IMSHR_ENTRY [`N-1:0] imshr_entries, next_imshr_entries;

    wire        [`N-1:0] entries_free;
    wire        [`N-1:0] entries_pending;
    wor         [`N-1:0] imshr_hit;

    wire [`N-1:0][`N-1:0] entries_free_gnt_bus;
    wire [`N-1:0]         entries_pending_gnt_bus;

    logic outstanding_request_valid, next_outstanding_request_valid;
    logic [`N_CNT_WIDTH-1:0] outstanding_request_index, next_outstanding_request_index;

    genvar i;
    generate
        for (i = 0; i < `N; ++i) begin
            assign entries_free[i] = imshr_entries[i].state == IMSHR_INVALID;
            assign entries_pending[i] = imshr_entries[i].state == IMSHR_PENDING;
        end
    endgenerate

    genvar j;
    generate
        for (i = 0; i < `N; ++i) begin
            for (j = 0; j < i; ++j) begin
                assign imshr_hit[i] = miss_cache_valid[i] && miss_cache_valid[j]
                                 && miss_cache_indexes[i] == miss_cache_indexes[j]
                                 && miss_cache_tags[i]    == miss_cache_tags[j];
            end
            for (j = 0; j < `N; ++j) begin
                assign imshr_hit[i] = imshr_entries[j].index == miss_cache_indexes[i]
                                   && imshr_entries[j].tag   == miss_cache_tags[i]
                                   && imshr_entries[j].state != IMSHR_INVALID;
            end
        end
    endgenerate

`ifdef CPU_DEBUG_OUT
    assign imshr_entries_debug = imshr_entries;
`endif

    psel_gen #(
      .WIDTH(`N),
      .REQS(`N)
    ) free_entry_selector (
      .req(entries_free),
      .gnt(),
      .gnt_bus(entries_free_gnt_bus),
      .empty()
    );

    psel_gen #(
      .WIDTH(`N),
      .REQS(1)
    ) request_selector (
      .req(entries_pending),
      .gnt(),
      .gnt_bus(entries_pending_gnt_bus),
      .empty()
    );

    always_comb begin
        next_imshr_entries             = imshr_entries;
        next_outstanding_request_valid = `FALSE;
        next_outstanding_request_index = 0;

        // Handle memory returns
        cache_index = 0;
        cache_tag   = 0;
        ready       = `FALSE;
        for (int i = 0; i < `N; ++i) begin
            if (imshr_entries[i].state == IMSHR_WAIT_DATA
             && imshr_entries[i].transaction_tag == Imem2proc_data_tag) begin
                cache_index                 = imshr_entries[i].index;
                cache_tag                   = imshr_entries[i].tag;
                ready                       = `TRUE;
                next_imshr_entries[i].state = IMSHR_INVALID;
            end
        end

        // Allocate new entries for cache miss
        for (int i = 0; i < `N; ++i) begin
            if (miss_cache_valid[i] && ~imshr_hit[i]) begin
                for (int j = 0; j < `N; ++j) begin
                    if (entries_free_gnt_bus[i][j]) begin
                        next_imshr_entries[j].state = IMSHR_PENDING;
                        next_imshr_entries[j].index = miss_cache_indexes[i];
                        next_imshr_entries[j].tag   = miss_cache_tags[i];
                    end
                end
            end
        end
        
        proc2Imem_addr    = 0;
        proc2Imem_command = MEM_NONE;
        if (~dcache_request) begin
            for (int i = 0; i < `N; ++i) begin
                if (entries_pending_gnt_bus[i]) begin
                    proc2Imem_addr = {
                        16'b0,
                        imshr_entries[i].tag,
                        imshr_entries[i].index,
                        3'b0
                    };
                    proc2Imem_command              = MEM_LOAD;
                    next_outstanding_request_valid = `TRUE;
                    next_outstanding_request_index = i;
                    next_imshr_entries[i].state    = IMSHR_WAIT_TAG;
                end
            end
        end

        if (outstanding_request_valid && Imem2proc_transaction_tag != 0) begin
            next_imshr_entries[outstanding_request_index].transaction_tag = Imem2proc_transaction_tag;
            next_imshr_entries[outstanding_request_index].state = IMSHR_WAIT_DATA;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            imshr_entries <= 0;
            outstanding_request_valid <= `FALSE;
            outstanding_request_index <= 0;
        end else begin
            imshr_entries <= next_imshr_entries;
            outstanding_request_valid <= next_outstanding_request_valid;
            outstanding_request_index <= next_outstanding_request_index;
        end
    end
endmodule

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

    ICACHE_ENTRY [`CACHE_LINES-1:0] icache_data, next_icache_data;

    logic [`N-1:0][12-`CACHE_LINE_BITS:0] miss_cache_tags;
    logic [`N-1:0][`CACHE_LINE_BITS-1:0]  miss_cache_indexes;
    logic [`N-1:0]                        miss_cache_valid;

    logic [`CACHE_LINE_BITS-1:0]  cache_index;
    logic [12-`CACHE_LINE_BITS:0] cache_tag;
    logic ready;

    imshr mshr (
        .clock(clock),
        .reset(reset || squash),
        .dcache_request(dcache_request),
        .Imem2proc_transaction_tag(Imem2proc_transaction_tag),
        .Imem2proc_data_tag(Imem2proc_data_tag),
        .miss_cache_indexes(miss_cache_indexes),
        .miss_cache_tags(miss_cache_tags),
        .miss_cache_valid(miss_cache_valid),
        // output
        .proc2Imem_addr(proc2Imem_addr),
        .proc2Imem_command(proc2Imem_command),
        .cache_index(cache_index),
        .cache_tag(cache_tag),
        .ready(ready)
    `ifdef CPU_DEBUG_OUT
        , .imshr_entries_debug(imshr_entries_debug)
    `endif
    );

    always_comb begin
        next_icache_data = icache_data;
        // Handle cache queries
        for (int i = 0; i < `N; ++i) begin
            miss_cache_valid[i] = `FALSE;
            Icache_valid_out[i] = `FALSE;
            Icache_data_out[i]  = 0;
            {miss_cache_tags[i], miss_cache_indexes[i]} = proc2Icache_addr[i][15:3];

            if (valid[i]) begin
                if (icache_data[miss_cache_indexes[i]].tags == miss_cache_tags[i]
                 && icache_data[miss_cache_indexes[i]].valid) begin
                    Icache_data_out[i]  = icache_data[miss_cache_indexes[i]].data;
                    Icache_valid_out[i] = `TRUE;
                end else begin
                    miss_cache_valid[i] = `TRUE;
                end
            end
        end
        // Update cache
        if (ready) begin
            next_icache_data[cache_index].valid = `TRUE;
            next_icache_data[cache_index].tags  = cache_tag;
            next_icache_data[cache_index].data  = Imem2proc_data;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            icache_data <= 0;
        end else begin
            icache_data <= next_icache_data;
        end
    end

endmodule
