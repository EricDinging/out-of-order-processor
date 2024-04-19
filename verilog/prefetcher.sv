`include "verilog/sys_defs.svh"
`define CPU_DEBUG_OUT

typedef enum logic [1:0] {
    RESET = 2'h0,
    ON    = 2'h1,
    STOP  = 2'h2
} PREF_STATE;

module prefetcher (
    input clock,
    input reset,
    input ADDR next_pc_start,
    input logic hit_valid_line,
    output ADDR pref2Icache_addr,
    output logic pref2Icache_valid
);

    logic [$clog2(`MAX_PREFETCH_LINE+1)-1:0] cnt, next_cnt;
    PREF_STATE pref_state, next_pref_state;
    ADDR pref_addr, next_pref_addr;

    always_comb begin
        next_cnt        = cnt;
        next_pref_state = pref_state;
        next_pref_addr  = pref_addr;

        case (pref_state)
            RESET: begin
                next_cnt        = 0;
                next_pref_state = INIT;
                next_pref_addr  = next_pc_start;
            end

            ON: begin
                // reset is handeled in always_ff block
            end

            STOP: begin

            end
        endcase

    end

    always_ff @(posedge clock) begin
        if (reset) begin
            cnt        <= 0;
            pref_state <= RESET;
            pref_addr  <= 0;
        end else begin
            cnt        <= next_cnt;
            pref_state <= next_pref_state;
            pref_addr  <= next_pref_addr;
        end
    end

endmodule