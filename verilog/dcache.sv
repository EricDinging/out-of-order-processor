`include "verilog/sys_defs.svh"
`define CPU_DEBUG_OUT

typedef struct packed {
    MEM_BLOCK                    data;
    logic [`DCACHE_TAG_BITS-1:0] tag; // 32 - block index bits
    logic                        valid;
    logic                        dirty;
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
    input LQ_DCACHE_PACKET [`N-1:0] lq_dcache_packet,
    input logic            [`N-1:0] lq_dcache_miss,
    input SQ_DCACHE_PACKET [`N-1:0] sq_dcache_packet,
    input logic            [`N-1:0] sq_dcache_miss,
    // To memory
    output MEM_COMMAND proc2Dmem_command,
    output ADDR        proc2Dmem_addr,
    // To cache current result
    output logic      [`N-1:0] store_req_accept,
    output logic      [`N-1:0] load_req_accept,
    // To dcache
    output logic                          dmshr_request, // to icache
    output logic   [`DCACHE_TAG_BITS-1:0] cache_tag,
    output logic [`DCACHE_INDEX_BITS-1:0] cache_index,
    output logic                          ready,
    output DMSHR_Q_PACKET        [`N-1:0] dmshr_flush_packet,
    output logic                 [`N-1:0] dmshr_flush_valid
);

    DMSHR_ENTRY [SIZE-1:0] dmshr_entries, next_dmshr_entries;

    logic [`N-1:0][SIZE-1:0] dmshr_load_hit;
    logic [`N-1:0][SIZE-1:0] dmshr_store_hit;

    logic [`N-1:0] dmshr_load_allocate;
    logic [`N-1:0] dmshr_store_allocate;
    
    // DMSHR Q input
    logic          [SIZE-1:0][`N-1:0] push_valids;
    DMSHR_Q_PACKET [SIZE-1:0][`N-1:0] push_packets;
    logic          [SIZE-1:0]         flushes;
    // DMSHR Q output
    logic          [SIZE-1:0][`N-1:0] push_accepts;
    DMSHR_Q_PACKET [SIZE-1:0][`N-1:0] flush_packets;
    logic          [SIZE-1:0][`N-1:0] flush_valids;

    wire [SIZE-1:0] entries_pending;
    wire [SIZE-1:0] entries_pending_gnt_bus;

    psel_gen #(
        .WIDTH(SIZE),
        .REQS(1)
    ) request_selector (
        .req(entries_pending),
        .gnt(),
        .gnt_bus(entries_pending_gnt_bus),
        .empty()
    );

    // queue
    genvar i;
    generate
        for (i = 0; i < SIZE; ++i) begin
            dmshr_queue dmshr_q(
                .clock(clock),
                .reset(reset),
                .push_packet(push_packets[i]),
                .push_valid(push_valids[i]),
                .flush(flushes[i]),
                .push_accept(push_accepts[i]),
                .flush_packet(flush_packets[i]),
                .flush_valid(flush_valids[i])
            );
            assign entries_pending[i] = dmshr_entries[i].state == DMSHR_PENDING;
        end
    endgenerate

    always_comb begin
        next_dmshr_entries   = dmshr_entries;
        // DMSHR_q input
        push_valids          = 0;
        push_packets         = 0;
        flushes              = {SIZE{`FALSE}};
        // DMSHR output
        // to memory
        proc2Dmem_addr    = 0;
        proc2Dmem_command = MEM_NONE;
        // to cache current result
        store_req_accept     = {`N{`FALSE}};
        load_req_accept      = {`N{`FALSE}};
        // to dcache
        dmshr_request        = `FALSE;
        cache_index          = 0;
        cache_tag            = 0;
        ready                = `FALSE;
        dmshr_flush_packet   = 0;
        dmshr_flush_valid    = {`N{`FALSE}};
        // immediate values
        dmshr_load_allocate  = {`N{`FALSE}};
        dmshr_store_allocate = {`N{`FALSE}};

        // memory to dmshr
        for (int i = 0; i < SIZE; ++i) begin
            if (dmshr_entries[i].state == DMSHR_WAIT_DATA
             && dmshr_entries[i].transaction_tag == Dmem2proc_data_tag) begin
                cache_index = dmshr_entries[i].index;
                cache_tag   = dmshr_entries[i].tag;
                ready       = `TRUE;
                flushes[i]  = `TRUE;
                dmshr_flush_packet = flush_packets[i];
                dmshr_flush_valid  = flush_valids[i];
            end 
        end

        // load to dmshr
        for (int i = 0; i < `N; ++i) begin
            // check dmshr_entry hit
            for (int j = 0; j < SIZE; ++j) begin
                dmshr_load_hit[i][j] = next_dmshr_entries[j].state != DMSHR_INVALID
                                    && lq_dcache_packet[i].valid
                                    && next_dmshr_entries[j].tag == lq_dcache_packet[i].addr[31:`DCACHE_INDEX_BITS+`DCACHE_BLOCK_OFFSET_BITS]
                                    && next_dmshr_entries[j].index == lq_dcache_packet[i].addr[`DCACHE_INDEX_BITS+`DCACHE_BLOCK_OFFSET_BITS-1:`DCACHE_BLOCK_OFFSET_BITS];
                if (dmshr_load_hit[i][j] && lq_dcache_miss[i]) begin
                    push_packets[j][i] = '{
                        INST_LOAD,
                        lq_dcache_packet[i].mem_func,
                        {32'b0},
                        lq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS-1:0],
                        lq_dcache_packet[i].lq_idx
                    };
                    push_valids[j][i] = `TRUE;
                    // read push accept
                    load_req_accept[i] = push_accepts[j][i];
                end
            end
            if (~(|dmshr_load_hit[i]) && lq_dcache_packet[i].valid && lq_dcache_miss[i]) begin
                for (int j = 0; j < SIZE; ++j) begin
                    if (next_dmshr_entries[j].state == DMSHR_INVALID && ~dmshr_load_allocate[i]) begin
                        dmshr_load_allocate[i] = `TRUE;
                        next_dmshr_entries[j].state = DMSHR_PENDING;
                        next_dmshr_entries[j].tag = lq_dcache_packet[i].addr[31:`DCACHE_INDEX_BITS+`DCACHE_BLOCK_OFFSET_BITS];
                        next_dmshr_entries[j].index = lq_dcache_packet[i].addr[`DCACHE_INDEX_BITS+`DCACHE_BLOCK_OFFSET_BITS-1:`DCACHE_BLOCK_OFFSET_BITS];
                        push_packets[j][i] = {
                            INST_LOAD,
                            lq_dcache_packet[i].mem_func,
                            {32'b0},
                            lq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS-1:0],
                            lq_dcache_packet[i].lq_idx
                        };
                        push_valids[j][i] = `TRUE;
                        // read push accept
                        load_req_accept[i] = push_accepts[j][i];
                    end
                end
            end
        end

         // store to dmshr
        for (int i = 0; i < `N; ++i) begin
            for (int j = 0; j < SIZE; ++j) begin
                dmshr_store_hit[i][j] = next_dmshr_entries[j].state != DMSHR_INVALID
                                     && sq_dcache_packet[i].valid
                                     && next_dmshr_entries[j].tag == sq_dcache_packet[i].addr[31:`DCACHE_INDEX_BITS+`DCACHE_BLOCK_OFFSET_BITS]
                                     && next_dmshr_entries[j].index == sq_dcache_packet[i].addr[`DCACHE_INDEX_BITS+`DCACHE_BLOCK_OFFSET_BITS-1:`DCACHE_BLOCK_OFFSET_BITS];
                if (dmshr_store_hit[i][j] && sq_dcache_miss[i]) begin
                    push_packets[j][i] = '{
                        INST_STORE,               // inst_command
                        sq_dcache_packet[i].mem_func, // mem_func
                        sq_dcache_packet[i].data, // data
                        sq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS-1:0], // block_offset
                        {`LOAD_Q_INDEX_WIDTH{1'b0}}    // lq_idx
                    };
                    push_valids[j][i] = `TRUE;
                    store_req_accept[i] = push_accepts[j][i];
                end
            end
            if (~(|dmshr_store_hit[i]) && sq_dcache_packet[i].valid && sq_dcache_miss[i]) begin
                for (int j = 0; j < SIZE; ++j) begin
                    if (next_dmshr_entries[j].state == DMSHR_INVALID && ~dmshr_store_allocate[i]) begin
                        dmshr_store_allocate[i] = `TRUE;
                        next_dmshr_entries[j].state = DMSHR_PENDING;
                        next_dmshr_entries[j].tag = sq_dcache_packet[i].addr[31:`DCACHE_INDEX_BITS+`DCACHE_BLOCK_OFFSET_BITS];
                        next_dmshr_entries[j].index = sq_dcache_packet[i].addr[`DCACHE_INDEX_BITS+`DCACHE_BLOCK_OFFSET_BITS-1:`DCACHE_BLOCK_OFFSET_BITS];
                        push_packets[j][i] = '{
                            INST_STORE,               // inst_command
                            sq_dcache_packet[i].mem_func, // mem_func
                            sq_dcache_packet[i].data, // data
                            sq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS-1:0], // block_offset
                            {`LOAD_Q_INDEX_WIDTH{1'b0}}    // lq_idx
                        };
                        push_valids[j][i] = `TRUE;
                        store_req_accept[i] = push_accepts[j][i];
                    end
                end
            end
        end

        // send command to memory
        if (~dcache_evict) begin
            for (int i = 0; i < SIZE; ++i) begin
                if (entries_pending_gnt_bus[i]) begin
                    dmshr_request = `TRUE;
                    proc2Dmem_addr = {
                        dmshr_entries[i].tag,
                        dmshr_entries[i].index,
                        {`DCACHE_BLOCK_OFFSET_BITS{1'b0}}
                    };
                    proc2Dmem_command = MEM_LOAD;
                    if (Dmem2proc_transaction_tag != 0) begin
                        next_dmshr_entries[i].transaction_tag = Dmem2proc_transaction_tag;
                        next_dmshr_entries[i].state           = DMSHR_WAIT_DATA;
                    end
                end
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
    input logic clock,
    input logic reset,
    input logic squash,
    // From memory
    input MEM_TAG   Dmem2proc_transaction_tag,
    input MEM_BLOCK Dmem2proc_data,
    input MEM_TAG   Dmem2proc_data_tag,
    // From LSQ
    input LQ_DCACHE_PACKET [`N-1:0] lq_dcache_packet,
    input SQ_DCACHE_PACKET [`N-1:0] sq_dcache_packet,
    // To memory
    output MEM_COMMAND proc2Dmem_command,
    output ADDR        proc2Dmem_addr,
    output MEM_BLOCK   proc2Dmem_data,
    // To LSQ current result
    output logic      [`N-1:0] store_req_accept,
    output logic      [`N-1:0] load_req_accept,
    output DATA       [`N-1:0] load_req_data,
    output logic      [`N-1:0] load_req_data_valid,
    // To LSQ future result
    output DCACHE_LQ_PACKET [`N-1:0] dcache_lq_packet,
    // To Icache
    output logic dcache_request
);
    DCACHE_ENTRY [SIZE-1:0] dcache_data, next_dcache_data;

    // DMSHR input
    logic dcache_evict;
    logic [`N-1:0] lq_dcache_miss;
    logic [`N-1:0] sq_dcache_miss;
    // DMSHR output
    MEM_COMMAND                    dmshr_proc2Dmem_command;
    ADDR                           dmshr_proc2Dmem_addr;
    logic                          dmshr_request;
    logic [`DCACHE_TAG_BITS-1:0]   cache_tag;
    logic [`DCACHE_INDEX_BITS-1:0] cache_index;
    logic                          ready;
    DMSHR_Q_PACKET [`N-1:0]        dmshr_flush_packet;
    logic [`N-1:0]                 dmshr_flush_valid;
    logic [`N-1:0]                 dmhsr_store_req_accept;
    logic [`N-1:0]                 dmhsr_load_req_accept;

    wire [`N-1:0][`DCACHE_INDEX_BITS-1:0]        load_index, store_index;
    wire [`N-1:0][`DCACHE_TAG_BITS-1:0]          load_tag, store_tag;
    wire [`N-1:0][`DCACHE_BLOCK_OFFSET_BITS-1:0] store_offset;

    genvar i;
    generate
        begin
            for (i = 0; i < `N; ++i) begin
                assign load_index[i]   = lq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS+`DCACHE_INDEX_BITS-1:`DCACHE_BLOCK_OFFSET_BITS];
                assign store_index[i]  = sq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS+`DCACHE_INDEX_BITS-1:`DCACHE_BLOCK_OFFSET_BITS];
                assign load_tag[i]     = lq_dcache_packet[i].addr[31:`DCACHE_BLOCK_OFFSET_BITS+`DCACHE_INDEX_BITS];
                assign store_tag[i]    = sq_dcache_packet[i].addr[31:`DCACHE_BLOCK_OFFSET_BITS+`DCACHE_INDEX_BITS];
                assign store_offset[i] = sq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS-1:0];
            end
        end
    endgenerate

    dmshr mshr (
        .clock(clock),
        .reset(reset || squash),
        // From memory
        .Dmem2proc_transaction_tag(Dmem2proc_transaction_tag),
        .Dmem2proc_data_tag(Dmem2proc_data_tag),
        // From dcache
        .dcache_evict(dcache_evict),
        // From cache
        .lq_dcache_packet(lq_dcache_packet),
        .lq_dcache_miss(lq_dcache_miss),
        .sq_dcache_packet(sq_dcache_packet),
        .sq_dcache_miss(sq_dcache_miss),
        // output
        .proc2Dmem_command(dmshr_proc2Dmem_command),
        .proc2Dmem_addr(dmshr_proc2Dmem_addr),
        // To cache current result
        .store_req_accept(dmhsr_store_req_accept),
        .load_req_accept(dmhsr_load_req_accept),
        // To dcache
        .dmshr_request(dmshr_request), // to icache
        .cache_tag(cache_tag),
        .cache_index(cache_index),
        .ready(ready),
        .dmshr_flush_packet(dmshr_flush_packet),
        .dmshr_flush_valid(dmshr_flush_valid)
    );

    always_comb begin
        // dcache output
        proc2Dmem_command   = MEM_NONE;
        proc2Dmem_addr      = 0;
        load_req_data       = 0;
        load_req_data_valid = {`N{`FALSE}};
        dcache_lq_packet    = 0;
        dcache_request      = `FALSE;
        load_req_accept     = {`N{`FALSE}};
        store_req_accept    = {`N{`FALSE}};
        // dmshr input
        dcache_evict      = `FALSE;
        lq_dcache_miss    = {`N{`FALSE}};
        sq_dcache_miss    = {`N{`FALSE}};

        next_dcache_data  = dcache_data;

        proc2Dmem_addr    = dmshr_proc2Dmem_addr;
        proc2Dmem_command = dmshr_proc2Dmem_command;
        proc2Dmem_data    = 0;
        dcache_request    = dmshr_request;

        // memory to dcache
        if (ready) begin
            // if dirty evict, set dcache_evict
            if (dcache_data[cache_index].dirty && dcache_data[cache_index].valid) begin
                dcache_evict = `TRUE;
                proc2Dmem_addr = {
                    dcache_data[cache_index].tag,
                    cache_index,
                    {`DCACHE_BLOCK_OFFSET_BITS{1'b0}}
                };
                proc2Dmem_command = MEM_STORE;
                dcache_request    = `TRUE;
                proc2Dmem_data    = dcache_data[cache_index].data;
            end

            // directly mapped cache
            next_dcache_data[cache_index].valid = `TRUE;
            next_dcache_data[cache_index].tag   = cache_tag;
            next_dcache_data[cache_index].dirty = `FALSE;
            next_dcache_data[cache_index].data  = Dmem2proc_data;
            // update dcache data content for store, output load
            for (int i = 0; i < `N; ++i) begin
                if (dmshr_flush_valid[i]) begin
                    if (dmshr_flush_packet[i].inst_command == INST_LOAD) begin
                        dcache_lq_packet[i] = '{
                            `TRUE, // valid
                            dmshr_flush_packet[i].lq_idx, // lq_idx
                            next_dcache_data[cache_index].data // data
                        };
                    end else if (dmshr_flush_packet[i].inst_command == INST_STORE) begin
                        next_dcache_data[cache_index].dirty = `TRUE;
                        case (dmshr_flush_packet[i].mem_func)
                            MEM_BYTE: 
                                next_dcache_data[cache_index].data.byte_level[dmshr_flush_packet[i].block_offset]
                                    = dmshr_flush_packet[i].data[7:0];
                            MEM_HALF:
                                next_dcache_data[cache_index].data.half_level[dmshr_flush_packet[i].block_offset[2:1]]
                                    = dmshr_flush_packet[i].data[15:0];
                            MEM_WORD:
                                next_dcache_data[cache_index].data.word_level[dmshr_flush_packet[i].block_offset[2]]
                                    = dmshr_flush_packet[i].data[31:0];
                        endcase
                    end
                end
            end
        end

        // cache hit or miss
        // load
        for (int i = 0; i < `N; ++i) begin
            if (lq_dcache_packet[i].valid) begin
                if (next_dcache_data[load_index[i]].tag == load_tag[i]) begin
                    // hit
                    load_req_accept[i]     = `TRUE;
                    load_req_data[i]       = next_dcache_data[load_index[i]].data;
                    load_req_data_valid[i] = `TRUE;
                end else begin
                    // miss
                    lq_dcache_miss[i]  = `TRUE;
                    load_req_accept[i] = dmhsr_load_req_accept[i];
                end
            end
        end

        // store
        for (int i = 0; i < `N; ++i) begin
            if (sq_dcache_packet[i].valid) begin
                if (next_dcache_data[store_index[i]].tag == store_tag[i]) begin
                    // hit
                    store_req_accept[i]                    = `TRUE;
                    next_dcache_data[store_index[i]].dirty = `TRUE;
                    case (sq_dcache_packet[i].mem_func)
                        MEM_BYTE: 
                            next_dcache_data[store_index[i]].data.byte_level[store_offset[i]]
                                = sq_dcache_packet[i].data[7:0];
                        MEM_HALF:
                            next_dcache_data[store_index[i]].data.half_level[store_offset[i][2:1]]
                                = sq_dcache_packet[i].data[15:0];
                        MEM_WORD:
                            next_dcache_data[store_index[i]].data.word_level[store_offset[i][2]]
                                = sq_dcache_packet[i].data[31:0];
                    endcase
                end else begin
                    sq_dcache_miss[i]   = `TRUE;
                    store_req_accept[i] = dmhsr_store_req_accept[i];
                end
            end
        end

    end

    always_ff @(posedge clock) begin
        if (reset) begin
            dcache_data <= 0;
        end else begin
            dcache_data <= next_dcache_data;
        end
    end

endmodule
