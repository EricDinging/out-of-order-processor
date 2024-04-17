`include "sys_defs.svh"

`define WIDTH 4

module testbench;

    logic clock, reset;

    logic              hit;
    logic [`WIDTH-1:0] index_hit;
    logic [`WIDTH-1:0] index_lru;

    lru #(`WIDTH) dut (
        .clock(clock), .reset(reset),

        .hit       (hit),
        .index_hit (index_hit),
        .index_lru (index_lru)
    );

    always #(`CLOCK_PERIOD/2.0) clock = ~clock;

    initial begin
        clock = 0;
        reset = 1;

        @(negedge clock);
        reset = 0;
        hit       = 0;
        index_hit = 0;
        
        for (int i = 0; i < 1 << `WIDTH; ++i) begin
            @(negedge clock);
            hit       = 1;
            index_hit = i;
            @(negedge clock);
            hit       = 0;
            index_hit = 0;
        end

        @(negedge clock);
        $finish;
    end

endmodule
