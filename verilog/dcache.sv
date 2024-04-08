`include "verilog/sys_defs.svh"
`define CPU_DEBUG_OUT

typedef struct packet {
    MEM_BLOCK                     data;
    logic [25-`DCACHE_INDEX_BITS] tag; // 32 - 6 block index bits
    logic                         valid;
    logic                         dirty;
} DCACHE_ENTRY;

module dmshr_queue (
    input clock, reset,
    input DMSHR_Q_PACKET  [`N-1:0] push_packet,
    input logic           [`N-1:0] push_valid,
    input logic                    flush,
    output logic          [`N-1:0] push_accept,
    output DMSHR_Q_PACKET [`N-1:0] flush_packet,
    output logic          [`N-1:0] flush_valid
);
    DMSHR_Q_PACKET  [`N-1:0] dmshr_q_entries, next_dmshr_q_entries;
    logic [`N_CNT_WIDTH-1:0] counter, next_counter;
    logic [`N_CNT_WIDTH-1:0] head, next_head, tail, next_tail;

    always_comb begin
        next_head            = head;
        next_tail            = tail;
        next_counter         = counter;
        next_dmshr_q_entries = dmshr_q_entries;
        flush_packet         = 0;
        flush_valid          = {`N{`FALSE}};
        push_accept          = {`N{`FALSE}};

        if (flush) begin
            next_head = 0;
            next_tail = 0;
            next_counter = 0;
            next_dmshr_q_entries = 0;
            for (int i = 0; i < counter; ++i) begin
                flush_valid[i]  = `TRUE;
                flush_packet[i] = dmshr_q_entries[(head + i) % `N];
            end
        end else begin
            for (int i = 0; i < `N; ++i) begin
                if (push_valid[i] && next_counter < `N) begin
                    next_dmshr_q_entries[next_tail] = push_packet[i];
                    next_tail                       = (next_tail + 1) % `N;
                    next_counter                    += 1;
                    push_accept[i]                  = `TRUE;
                end
            end
        end
    end
    
    always_ff @(posedge clock) begin
        if (reset) begin
            counter         <= 0;
            head            <= 0;
            tail            <= 0;
            dmshr_q_entries <= 0;
        end else begin
            counter         <= next_counter;
            head            <= next_head;
            tail            <= next_tail;
            dmshr_q_entries <= next_dmshr_q_entries;
        end
    end

endmodule

module dmshr #(
    parameter SIZE = 8
)(
    input clock, reset,
    // From memory
    input MEM_TAG   Dmem2proc_transaction_tag,
    input MEM_TAG   Dmem2proc_data_tag,
    // From dcache
    input logic     dcache_evict,
    // From cache
    LQ_DCACHE_PACKET [`N-1:0] lq_dcache_packet,
    SQ_DCACHE_PACKET [`N-1:0] sq_dcache_packet,
    // To memory
    output MEM_COMMAND proc2Dmem_command,
    output ADDR        proc2Dmem_addr,
    // To cache current result
    output logic      [`N-1:0] store_req_accept,
    output logic      [`N-1:0] load_req_accept,
    // To LSQ future result
    output DCACHE_LQ_PACKET [`N-1:0] dcache_lq_packet,
    output logic                     dmshr_request, // to icache
    // To dcache
    output logic [25-`DCACHE_INDEX_BITS:0] cache_tag,
    output logic [`DCACHE_INDEX_BITS-1:0]  cache_index,
    output logic                           ready
);

    DMSHR_ENTRY [SIZE-1:0] dmshr_entries, next_dmshr_entries;

    logic [`N-1:0][$clog2(SIZE+1)-1:0] l_mshr_index;
    logic [`N-1:0][$clog2(SIZE+1)-1:0] s_mshr_index;

    // DMSHR input
    logic          [SIZE-1:0][`N-1:0] push_valids;
    DMSHR_Q_PACKET [SIZE-1:0][`N-1:0] push_packets;
    logic          [SIZE-1:0][`N-1:0] push_accepts;
    logic          [SIZE-1:0]         flushes;
    // DMSHR output
    logic          [SIZE-1:0][`N-1:0] push_accepts;
    DMSHR_Q_PACKET [SIZE-1:0][`N-1:0] flush_packets;
    logic          [SIZE-1:0][`N-1:0] flush_valids;

    
    wire [SIZE-1:0] entries_free;
    wire [SIZE-1:0] entries_pending;

    wire [SIZE-1:0][SIZE-1:0] entries_free_gnt_bus;
    wire [SIZE-1:0]           entries_pending_gnt_bus;
    
    psel_gen #(
        .WIDTH(SIZE),
        .REQS(SIZE)
    ) free_entry_selector (
        .req(entries_free),
        .gnt(),
        .gnt_bus(entries_free_gnt_bus),
        .empty()
    );

    psel_gen #(
        .WIDTH(SIZE),
        .REQS(1)
    ) request_selector (
        .req(entries_pending),
        .gnt(),
        .gnt_bus(entries_pending_gnt_bus),
        .empty()
    );

    genvar i;
    generate
        for (i = 0; i < SIZE; ++i) begin
            dmshr_queue #(
                .N(`N),
                .N_CNT_WIDTH(`N_CNT_WIDTH)
            ) dmshr_q(
                .clock(clock),
                .reset(reset),
                .push_packet(push_packets[i]),
                .push_valid(push_valids[i]),
                .flush(flushes[i]),
                .push_accept(push_accepts[i]),
                .flush_packet(flush_packets[i]),
                .flush_valid(flush_valids[i])
            );
        end
    endgenerate


    always_comb begin
        next_dmshr_entries = dmshr_entries;

        cache_index = 0;
        cache_tag   = 0;
        ready       = `FALSE;
        for (int i = 0; i < SIZE; ++i) begin
            if (dmshr_entries[i].state == DMSHR_WAIT_DATA
             && dmshr_entries[i].transaction_tag == Dmem2proc_data_tag) begin

            end 
        end
        
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            dmshr_entries <= 0;
        end else begin
            dmshr_entries <= next_dmshr_entries;
        end
    end
endmodule

module dcache #(
    parameter SIZE = `DCACHE_LINES
)(
    input clock,
    input reset,
    input logic squash,
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
    output logic      [`N-1:0] store_req_accept,
    output logic      [`N-1:0] load_req_accept,
    output DATA_WIDTH [`N-1:0] load_req_data,
    // To LSQ future result
    output DCACHE_LQ_PACKET [`N-1:0] dcache_lq_packet,
    // To Icache
    output logic dcache_request
);
    DCACHE_ENTRY [SIZE-1:0] dcache_data, next_dcache_data;

endmodule
