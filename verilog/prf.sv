`include "sys_defs.svh"
// PRN, DATA
/*
typedef struct packed {
    logic valid;
    DATA value;
} PRF_ENTRY;

typedef struct packed {
    DATA value; // valid here means to write or not
    PRN prn;
} PRF_WRITE;

*/

module prf #(
    parameter SIZE = `PHYS_REG_SZ_R10K
)(
    // issue
    input clock, reset,
    input PRN [2*`N-1:0] read_prn,
    output PRF_ENTRY [2*`N-1:0] output_value,

    // finish exectution
    input PRF_WRITE [`N-1:0] write_data,
     
    // commit or issue (set prf entry invalid)
    input PRN [`N-1:0] prn_invalid,

    // // on mispredict
    // input logic mispredict

    // for writeback file
    input PRN [`N-1:0] wb_read_prn,
    output DATA [`N-1:0] wb_prf_out

    `ifdef DEBUG_OUT
    , output PRF_ENTRY [SIZE-1:0] entries_out
    , output PRN counter
    `endif
);
    // State
    PRF_ENTRY [SIZE-1:0] entries, next_entries;

    `ifdef DEBUG_OUT
    assign entries_out = entries;
    PRN next_counter;
    `endif

    logic [`N-1:0] write_valid;

    genvar i;
    generate
        for (i = 0; i < `N; ++i) begin
            assign write_valid[i] = write_data[i].prn != 0;
            assign wb_prf_out[i] = entries[wb_read_prn[i]].value;
        end
    endgenerate

    always_comb begin
        // read and set invalid should never occur simultaneously
        for (int i = 0; i < 2 * `N; i++) begin
            output_value[i] = entries[read_prn[i]];
            for (int j = 0; j < `N; j++) begin
                if (write_valid[j] && write_data[j].prn == read_prn[i]) begin
                    output_value[i].value = write_data[j].value;
                    output_value[i].valid = `TRUE;
                end
            end
        end

        `ifdef DEBUG_OUT
            next_counter = counter;
            for (int i = 0; i < `N; i++) begin
                if (write_valid[i] && !entries[write_data[i].prn].valid) begin
                    next_counter += 1;
                end
                if (prn_invalid[i] != 0 && entries[prn_invalid[i]].valid) begin
                    next_counter -= 1;
                end 
            end
        `endif

        next_entries = entries;
        for (int i = 0; i < `N; i++) begin
            if (write_valid[i]) begin
                next_entries[write_data[i].prn] = '{`TRUE, write_data[i].value};
            end
            if (prn_invalid[i] != 0) begin
                next_entries[prn_invalid[i]].valid = `FALSE;
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            for (int i = 0; i < `ARCH_REG_SZ; i++) begin
                entries[i] <= '{`TRUE, 0};
            end
            entries[`PHYS_REG_SZ_R10K-1:`ARCH_REG_SZ] <= 0;
            `ifdef DEBUG_OUT
            counter <= `ARCH_REG_SZ - 1;
            `endif
        end else begin
            entries <= next_entries;
            `ifdef DEBUG_OUT
            counter <= next_counter;
            `endif
        end
    end
endmodule
