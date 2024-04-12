`include "sys_defs.svh"

/*
typedef enum logic [1:0] {KNOWN, NO_FORWARD, ASKED} LU_STATE;

typedef struct packed {
    logic valid;
    MEM_FUNC sign_size;
    ADDR base;
    logic [11:0] offset;
    PRN prn;
    ROBN robn;
    SQ_IDX   tail_store;
} RS_LQ_PACKET;

typedef struct packed {
    ROBN robn;
    PRN dest_prn;
    DATA result;
} FU_STATE_BASIC_PACKET;

typedef struct packed {
    logic                           valid;
    logic [`LOAD_Q_INDEX_WIDTH-1:0] lq_idx;
    ADDR                            addr;
    MEM_FUNC                        sign_size;
} LQ_DCACHE_PACKET;

typedef struct packed {
    logic                               valid;
    logic     [`LOAD_Q_INDEX_WIDTH-1:0] lq_idx;
    DATA                          data;
} DCACHE_LQ_PACKET;
*/

module load_queue (
    input  logic clock, reset,
    // rs
    input  RS_LQ_PACKET          [`NUM_FU_LOAD-1:0] rs_lq_packet,
    output logic                 [`NUM_FU_LOAD-1:0] load_rs_avail,
    // cdb
    input  logic                 [`NUM_FU_LOAD-1:0] load_selected,
    output logic                 [`NUM_FU_LOAD-1:0] load_prepared,
    output FU_STATE_BASIC_PACKET [`NUM_FU_LOAD-1:0] load_packet,
    // SQ
    output ADDR                  [`NUM_FU_LOAD-1:0] sq_addr,
    output logic                 [`NUM_FU_LOAD-1:0][`SQ_IDX_BITS-1:0] store_range,
    output MEM_FUNC              [`NUM_FU_LOAD-1:0] load_byte_info,
    input  DATA                  [`NUM_FU_LOAD-1:0] value,
    input  logic                 [`NUM_FU_LOAD-1:0] fwd_valid,
    // Dcache
    input  DCACHE_LQ_PACKET [`N-1:0]             dcache_lq_packet,
    input  logic            [`NUM_LU_DCACHE-1:0] load_req_accept,
    input  DATA             [`NUM_LU_DCACHE-1:0] load_req_data,
    input  logic            [`NUM_LU_DCACHE-1:0] load_req_data_valid,
    output LQ_DCACHE_PACKET [`NUM_LU_DCACHE-1:0] lq_dcache_packet

`ifdef CPU_DEBUG_OUT
    , output LD_ENTRY   [`NUM_FU_LOAD-1:0]      entries_out
`endif
);

    function extend;
        input DATA     data;
        input MEM_FUNC byte_info;
        // input logic    signext;
        begin
            DATA data_signed, data_unsigned;

            case (byte_info)
                BYTE: begin
                    data_signed   =   signed'(data[ 7:0]);
                    data_unsigned = unsigned'(data[ 7:0]);
                end
                HALF: begin
                    data_signed   =   signed'(data[15:0]);
                    data_unsigned = unsigned'(data[15:0]);
                end
                WORD: begin
                    data_signed   =   signed'(data[31:0]);
                    data_unsigned = unsigned'(data[31:0]);
                end
                default: begin
                    data_signed   = data;
                    data_unsigned = data;
                end
            endcase

            extend = byte_info[2] ? data_unsigned : data_signed;
        end
    endfunction

    LD_ENTRY   [`NUM_FU_LOAD-1:0] entries,    next_entries;
`ifdef CPU_DEBUG_OUT
    assign entries_out = entries;
`endif
    LU_REG     [`NUM_FU_LOAD-1:0] lu_reg,     next_lu_reg;
    LU_FWD_REG [`NUM_FU_LOAD-1:0] lu_fwd_reg, next_lu_fwd_reg;
    LQ_DCACHE_PACKET [`NUM_FU_LOAD-1:0] mux_input;

    logic [`NUM_FU_LOAD-1:0] no_forwards;
    logic [`NUM_LU_DCACHE-1:0][`NUM_FU_LOAD-1:0] mux_select;

    // add
    always_comb begin
        next_lu_reg = lu_reg;
        foreach (next_lu_reg[i]) begin
            next_lu_reg[i].valid      = rs_lq_packet[i].valid;
            next_lu_reg[i].sign_size  = rs_lq_packet[i].sign_size;
            next_lu_reg[i].addr       = rs_lq_packet[i].base + {20'h0, rs_lq_packet[i].offset};
            next_lu_reg[i].prn        = rs_lq_packet[i].prn;
            next_lu_reg[i].robn       = rs_lq_packet[i].robn;
            next_lu_reg[i].tail_store = rs_lq_packet[i].tail_store;
        end
    end

    // query sq
    always_comb begin
        next_lu_fwd_reg = lu_fwd_reg;
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            sq_addr[i] = lu_reg[i].addr;
            store_range[i] = lu_reg[i].tail_store;
            load_byte_info[i] = lu_reg[i].sign_size;
            next_lu_fwd_reg[i].valid      = lu_reg[i].valid;
            next_lu_fwd_reg[i].sign_size  = lu_reg[i].sign_size;
            next_lu_fwd_reg[i].addr       = lu_reg[i].addr;
            next_lu_fwd_reg[i].prn        = lu_reg[i].prn;
            next_lu_fwd_reg[i].robn       = lu_reg[i].robn;
            next_lu_fwd_reg[i].tail_store = lu_reg[i].tail_store;
            next_lu_fwd_reg[i].value      = value[i];
            next_lu_fwd_reg[i].fwd_valid  = fwd_valid[i];
        end
    end

    // load_rs_avail
    always_comb begin
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            load_rs_avail[i] = !entries[i].valid && !lu_reg[i].valid && !lu_fwd_reg[i].valid;
        end
    end

    
    always_comb begin
        next_entries = entries;
        // entry
        // for (int i = 0, inst_cnt = 0; i < `NUM_FU_LOAD; i++) begin
        //     if (load_rs_avail[i] && inst_cnt < `NUM_FU_LOAD && rs_lq_packet[inst_cnt].valid) begin
        //         next_entries[i] = '{
        //             `TRUE,
        //             // lu_fwd_reg[inst_cnt].signext,
        //             lu_fwd_reg[inst_cnt].sign_size,
        //             lu_fwd_reg[inst_cnt].addr,
        //             lu_fwd_reg[inst_cnt].value,
        //             lu_fwd_reg[inst_cnt].tail_store,
        //             lu_fwd_reg[inst_cnt].prn,
        //             lu_fwd_reg[inst_cnt].robn,
        //             lu_fwd_reg[inst_cnt].fwd_valid ? KNOWN : NO_FORWARD
        //         };
        //         inst_cnt++;
        //     end
        // end
        for (int i = 0; i < `NUM_FU_LOAD; i++) begin
            if (lu_fwd_reg[i].valid) begin
                next_entries[i] = '{
                    `TRUE,
                    // lu_fwd_reg[inst_cnt].signext,
                    lu_fwd_reg[i].sign_size,
                    lu_fwd_reg[i].addr,
                    lu_fwd_reg[i].value,
                    lu_fwd_reg[i].tail_store,
                    lu_fwd_reg[i].prn,
                    lu_fwd_reg[i].robn,
                    lu_fwd_reg[i].fwd_valid ? KNOWN : NO_FORWARD
                };
            end
        end

        // CDB
        foreach (entries[i]) begin
            load_packet[i].robn = entries[i].robn;
            load_packet[i].dest_prn = entries[i].prn;
            // adjust to fit the byte type
            // load_packet[i].result = entries[i].data;
            if (entries[i].valid && entries[i].load_state == KNOWN) begin
                load_prepared[i] = `TRUE;
            end else begin
                load_prepared[i] = `FALSE;
            end

            if (load_selected[i]) begin
                next_entries[i] = 0;
            end
        end

        // dcache
        no_forwards = 0;
        foreach (entries[i]) begin
            if (entries[i].valid && entries[i].load_state == NO_FORWARD) begin
                no_forwards[i] = `TRUE;
            end
            mux_input[i].valid  = entries[i].valid && entries[i].load_state == NO_FORWARD;
            mux_input[i].lq_idx = i; // TODO: width
            mux_input[i].addr   = entries[i].addr;
            mux_input[i].mem_func = entries[i].byte_info;
        end

        for (int i = 0; i < `NUM_LU_DCACHE; i++) begin
            if (load_req_accept[i] && load_req_data_valid[i]) begin
                next_entries[lq_dcache_packet[i].lq_idx].load_state = KNOWN;
                next_entries[lq_dcache_packet[i].lq_idx].data = load_req_data[i];
            end else if (load_req_accept) begin
                next_entries[lq_dcache_packet[i].lq_idx].load_state = ASKED;
            end
        end

        for (int i = 0; i < `N; i++) begin
            if (dcache_lq_packet[i].valid) begin
                next_entries[dcache_lq_packet[i].lq_idx].load_state = KNOWN;
                next_entries[dcache_lq_packet[i].lq_idx].data = dcache_lq_packet[i].data;
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < `NUM_FU_LOAD; i++) begin
            sign_align sa (
                .data(entries[i].data),
                .addr(entries[i].addr),
                .func(entries[i].byte_info),
                .out(load_packet[i].result)
            );
        end
    endgenerate

    onehot_mux #(
        .SIZE  ($bits(LQ_DCACHE_PACKET)),
        .WIDTH (`NUM_FU_LOAD)
    ) mux_dcache[`NUM_LU_DCACHE-1:0] (
        .in(mux_input),
        .select(mux_select),
        .out(lq_dcache_packet)
    );

    psel_gen #(
        .WIDTH(`NUM_FU_LOAD),
        .REQS(`NUM_LU_DCACHE)
    ) load_dcache_selector (
        .req(no_forwards),
        .gnt(),
        .gnt_bus(mux_select),
        .empty()
    );

    always_ff @(posedge clock) begin
        if (reset) begin
            entries    <= 0;
            lu_reg     <= 0;
            lu_fwd_reg <= 0;
        end else begin
            entries    <= next_entries;
            lu_reg     <= next_lu_reg;
            lu_fwd_reg <= next_lu_fwd_reg;
        end
    end

endmodule
