`include "verilog/sys_defs.svh"
// `define CPU_DEBUG_OUT

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
    ADDR past_pref2Icache_addr;

    always_comb begin
        next_cnt        = cnt;
        next_pref_state = pref_state;
        pref2Icache_addr  = past_pref2Icache_addr;
        pref2Icache_valid      = `FALSE;

        case (pref_state)
            RESET: begin
                next_cnt        = 0;
                next_pref_state = ON;
            end

            ON: begin
                if (cnt >= `MAX_PREFETCH_LINE) begin
                    next_pref_state = STOP;
                    next_cnt        = 0;
                end else begin
                    pref2Icache_addr = (past_pref2Icache_addr + 4 > next_pc_start)? 
                    past_pref2Icache_addr + 4 : next_pc_start;
                    pref2Icache_valid = `TRUE;
                    next_cnt = cnt + 1;
                    if (hit_valid_line) begin 
                        next_pref_state = STOP;
                    end
                end
            end

            STOP: begin
                if (pref2Icache_addr + 4 <= next_pc_start) begin
                    next_pref_state = ON;
                end
            end
        endcase

    end

    always_ff @(posedge clock) begin
        if (reset) begin
            cnt        <= 0;
            pref_state <= RESET;
            past_pref2Icache_addr  <= 0;
        end else begin
            cnt        <= next_cnt;
            pref_state <= next_pref_state;
            past_pref2Icache_addr  <= pref2Icache_addr;
        end
    end

endmodule
