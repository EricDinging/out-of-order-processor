`include "verilog/sys_defs.svh"
// `define CPU_DEBUG_OUT

module dmshr_queue (
    input clock, reset,
    input logic squash,
    input DMSHR_Q_PACKET  [2*`N-1:0] push_packet,
    input logic           [2*`N-1:0] push_valid,
    input logic                      flush,
    output logic          [2*`N-1:0] push_accept,
    output DMSHR_Q_PACKET [`N-1:0]   flush_packet,
    output logic          [`N-1:0]   flush_valid
`ifdef CPU_DEBUG_OUT
    , output logic [`N_CNT_WIDTH-1:0] counter_debug
`endif
);

    DMSHR_Q_PACKET  [`N-1:0] dmshr_q_entries, next_dmshr_q_entries;
    logic [`N_CNT_WIDTH-1:0] counter, next_counter;
    logic [`N_CNT_WIDTH-1:0] head, next_head, tail, next_tail;
`ifdef CPU_DEBUG_OUT
    assign counter_debug = counter;
`endif

    always_comb begin
        next_head            = head;
        next_tail            = tail;
        next_counter         = counter;
        next_dmshr_q_entries = dmshr_q_entries;
        flush_packet         = 0;
        flush_valid          = {`N{`FALSE}};
        push_accept          = {`N{`FALSE}};

        if (squash) begin
            for (int i = 0 ; i < `N; i++) begin
                if (dmshr_q_entries[(next_tail-1)%`N].inst_command == INST_LOAD && next_counter > 0) begin
                    next_tail = (next_tail - 1) % `N;
                    next_counter -= 1;
                end else begin
                    break;
                end
            end
        end

        if (flush) begin
            for (int i = 0; i < next_counter; ++i) begin
                flush_valid[i]  = `TRUE;
                flush_packet[i] = dmshr_q_entries[(head + i) % `N];
            end
            next_head = 0;
            next_tail = 0;
            next_dmshr_q_entries = 0;
            next_counter = 0;
        end else begin
            for (int i = 0; i < 2*`N; ++i) begin
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
    parameter SIZE = `DMSHR_SIZE
)(
    input clock, reset,
    input logic squash,
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
    `ifdef CPU_DEBUG_OUT
    , output DMSHR_ENTRY [SIZE-1:0] dmshr_entries_debug
    , output logic [SIZE-1:0][`N_CNT_WIDTH-1:0] counter_debug
    `endif
);

    DMSHR_ENTRY [SIZE-1:0] dmshr_entries, next_dmshr_entries;

    logic [`N-1:0][SIZE-1:0] dmshr_load_hit;
    logic [`N-1:0][SIZE-1:0] dmshr_store_hit;

    logic [`N-1:0] dmshr_load_allocate;
    logic [`N-1:0] dmshr_store_allocate;
    
    // DMSHR Q input
    logic          [SIZE-1:0][2*`N-1:0] push_valids;
    DMSHR_Q_PACKET [SIZE-1:0][2*`N-1:0] push_packets;
    logic          [SIZE-1:0]           flushes;
    // DMSHR Q output
    logic          [SIZE-1:0][2*`N-1:0] push_accepts;
    DMSHR_Q_PACKET [SIZE-1:0][`N-1:0]   flush_packets;
    logic          [SIZE-1:0][`N-1:0]   flush_valids;

    wire [SIZE-1:0] entries_pending;
    wire [SIZE-1:0] entries_pending_gnt_bus;

`ifdef CPU_DEBUG_OUT
    assign dmshr_entries_debug = dmshr_entries;
`endif

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
                .squash(squash),
                .push_packet(push_packets[i]),
                .push_valid(push_valids[i]),
                .flush(flushes[i]),
                .push_accept(push_accepts[i]),
                .flush_packet(flush_packets[i]),
                .flush_valid(flush_valids[i])
            `ifdef CPU_DEBUG_OUT
                , .counter_debug(counter_debug[i])
            `endif
            );
        end
    endgenerate

    generate
        for (i = 0; i < SIZE; ++i) begin
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
                    push_packets[j][i+`N] = '{
                        INST_STORE,               // inst_command
                        sq_dcache_packet[i].mem_func, // mem_func
                        sq_dcache_packet[i].data, // data
                        sq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS-1:0], // block_offset
                        {`LU_IDX_BITS{1'b0}}    // lq_idx
                    };
                    push_valids[j][i+`N] = `TRUE;
                    store_req_accept[i] = push_accepts[j][i+`N];
                end
            end
            if (~(|dmshr_store_hit[i]) && sq_dcache_packet[i].valid && sq_dcache_miss[i]) begin
                for (int j = 0; j < SIZE; ++j) begin
                    if (next_dmshr_entries[j].state == DMSHR_INVALID && ~dmshr_store_allocate[i]) begin
                        dmshr_store_allocate[i] = `TRUE;
                        next_dmshr_entries[j].state = DMSHR_PENDING;
                        next_dmshr_entries[j].tag = sq_dcache_packet[i].addr[31:`DCACHE_INDEX_BITS+`DCACHE_BLOCK_OFFSET_BITS];
                        next_dmshr_entries[j].index = sq_dcache_packet[i].addr[`DCACHE_INDEX_BITS+`DCACHE_BLOCK_OFFSET_BITS-1:`DCACHE_BLOCK_OFFSET_BITS];
                        push_packets[j][i+`N] = '{
                            INST_STORE,               // inst_command
                            sq_dcache_packet[i].mem_func, // mem_func
                            sq_dcache_packet[i].data, // data
                            sq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS-1:0], // block_offset
                            {`LU_IDX_BITS{1'b0}}    // lq_idx
                        };
                        push_valids[j][i+`N] = `TRUE;
                        store_req_accept[i] = push_accepts[j][i+`N];
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
                next_dmshr_entries[i].state = DMSHR_INVALID;
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
`ifdef CPU_DEBUG_OUT
    , output DMSHR_ENTRY [`DMSHR_SIZE-1:0] dmshr_entries_debug
    , output DCACHE_ENTRY [SIZE-1:0] dcache_data_debug
    , output logic [`DMSHR_SIZE-1:0][`N_CNT_WIDTH-1:0] counter_debug
`endif
);
    DCACHE_ENTRY [SIZE-1:0] dcache_data, next_dcache_data;

    logic store_valid, next_store_valid;
    ADDR  store_addr, next_store_addr;
    DATA  store_data, next_store_data;

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
    wire [`N-1:0][`DCACHE_BLOCK_OFFSET_BITS-1:0] load_offset, store_offset;

`ifdef CPU_DEBUG_OUT
    assign dcache_data_debug = dcache_data;
`endif

    genvar i;
    generate
        for (i = 0; i < `N; ++i) begin
            assign load_index[i]   = lq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS+`DCACHE_INDEX_BITS-1:`DCACHE_BLOCK_OFFSET_BITS];
            assign store_index[i]  = sq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS+`DCACHE_INDEX_BITS-1:`DCACHE_BLOCK_OFFSET_BITS];
            assign load_tag[i]     = lq_dcache_packet[i].addr[31:`DCACHE_BLOCK_OFFSET_BITS+`DCACHE_INDEX_BITS];
            assign store_tag[i]    = sq_dcache_packet[i].addr[31:`DCACHE_BLOCK_OFFSET_BITS+`DCACHE_INDEX_BITS];
            assign store_offset[i] = sq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS-1:0];
            assign load_offset[i]  = lq_dcache_packet[i].addr[`DCACHE_BLOCK_OFFSET_BITS-1:0];
        end
    endgenerate

    dmshr mshr (
        .clock(clock),
        .reset(reset),
        .squash(squash),
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
    `ifdef CPU_DEBUG_OUT
        , .dmshr_entries_debug(dmshr_entries_debug)
        , .counter_debug(counter_debug)
    `endif
    );

    always_comb begin
        // dcache output
        proc2Dmem_command   = MEM_NONE;
        proc2Dmem_addr      = 0;
        load_req_data       = 0;
        load_req_data_valid = {`N{`FALSE}};
        dcache_lq_packet    = 0;
        // dcache_request      = `FALSE;
        load_req_accept     = {`N{`FALSE}};
        store_req_accept    = {`N{`FALSE}};
        // dmshr input
        dcache_evict      = `FALSE;
        lq_dcache_miss    = {`N{`FALSE}};
        sq_dcache_miss    = {`N{`FALSE}};

        next_dcache_data  = dcache_data;

        next_store_addr = 0;
        next_store_data = 0;
        next_store_valid = `FALSE;

        proc2Dmem_addr    = dmshr_proc2Dmem_addr;
        proc2Dmem_command = dmshr_proc2Dmem_command;
        proc2Dmem_data    = 0;
        // dcache_request    = dmshr_request;

        dcache_evict = store_valid;
        dcache_request = store_valid ? `TRUE : dmshr_request;
        if (store_valid) begin
            proc2Dmem_addr    = store_addr;
            proc2Dmem_command = MEM_STORE;
            proc2Dmem_data    = store_data;
        end

        // memory to dcache
        if (ready) begin
            // if dirty evict, set dcache_evict
            if (dcache_data[cache_index].dirty && dcache_data[cache_index].valid) begin
                next_store_valid = `TRUE;
                next_store_addr = {
                    dcache_data[cache_index].tag,
                    cache_index,
                    {`DCACHE_BLOCK_OFFSET_BITS{1'b0}}
                };
                next_store_data = dcache_data[cache_index].data;
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
                            next_dcache_data[cache_index].data.word_level[dmshr_flush_packet[i].block_offset[2]] // data
                        };
                        // dcache_lq_packet[i].valid = `TRUE;
                        // dcache_lq_packet[i].lq_idx = dmshr_flush_packet[i].lq_idx;
                        // case (dmshr_flush_packet[i].mem_func)
                        //     MEM_BYTE | MEM_BYTEU: 
                        //         dcache_lq_packet[i].data = {24'b0, next_dcache_data[cache_index].data.byte_level[dmshr_flush_packet[i].block_offset]};
                        //     MEM_HALF | MEM_HALFU:
                        //         dcache_lq_packet[i].data = {16'b0, next_dcache_data[cache_index].data.half_level[dmshr_flush_packet[i].block_offset[2:1]]};
                        //     MEM_WORD:
                        //         dcache_lq_packet[i].data = next_dcache_data[cache_index].data.word_level[dmshr_flush_packet[i].block_offset[2]];
                        // endcase
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
                if (next_dcache_data[load_index[i]].tag == load_tag[i] && next_dcache_data[load_index[i]].valid) begin
                    // hit
                    load_req_accept[i]     = `TRUE;
                    load_req_data[i]       = next_dcache_data[load_index[i]].data.word_level[load_offset[i][2]];
                    // case (lq_dcache_packet[i].mem_func)
                    //     MEM_BYTE | MEM_BYTEU: 
                    //         load_req_data[i] = {24'b0, next_dcache_data[load_index[i]].data.byte_level[load_offset[i]]};
                    //     MEM_HALF | MEM_HALFU:
                    //         load_req_data[i] = {16'b0, next_dcache_data[load_index[i]].data.half_level[load_offset[i][2:1]]};
                    //     MEM_WORD:
                    //         load_req_data[i] = next_dcache_data[load_index[i]].data.word_level[load_offset[i][2]];
                    // endcase
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
                if (next_dcache_data[store_index[i]].tag == store_tag[i] && next_dcache_data[store_index[i]].valid) begin
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
            store_valid <= `FALSE;
            store_addr  <= 0;
            store_data  <= 0;
        end else begin
            dcache_data <= next_dcache_data;
            store_valid <= next_store_valid;
            store_addr  <= next_store_addr;
            store_data  <= next_store_data;
        end
    end

endmodule
