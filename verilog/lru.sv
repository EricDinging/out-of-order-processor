module lru #(
    parameter WIDTH = 2
) (
    input logic clock,
    input logic reset,

    input  logic             hit,
    input  logic [WIDTH-1:0] index_hit,
    output logic [WIDTH-1:0] index_lru
);

    logic [(1<<WIDTH)-1:1] switch, next_switch;

    assign index_lru[WIDTH-1] = switch[1];
    assign next_switch[1] = hit ? ~index_hit[WIDTH-1] : switch[1];

    genvar i, j;
    generate
        for (i = 1; i < WIDTH; ++i) begin
            assign index_lru[WIDTH-i-1] = switch[{1'b1, index_lru[WIDTH-1:WIDTH-i]}];
            for (j = 0; j < 1 << i; ++j) begin
                assign next_switch[(1<<i)+j] = hit && (index_hit[WIDTH-1:WIDTH-i] == j) ? ~index_hit[WIDTH-i-1] : switch[(1<<i)+j];
            end
        end
    endgenerate

    always_ff @(posedge clock) begin
        if (reset) begin
            switch <= 0;
        end else begin
            switch <= next_switch;
        end
    end

endmodule
