module onehot_mux #(
    parameter SIZE,
    parameter WIDTH
) (
    input logic [WIDTH-1:0][SIZE-1:0] in,
    input logic [WIDTH-1:0] select,
    output wor [SIZE-1:0] out
);

    genvar i;
    generate
        for (i = 0; i < WIDTH; ++i) begin
            assign out = in[i] & {SIZE{select[i]}};
        end
    endgenerate
    
endmodule
