`include "sys_defs.svh"

module onehotenc #(
    parameter WIDTH
) (
    input  logic [$clog2(WIDTH)-1:0] in,
    output logic [WIDTH-1:0]         out
);

    genvar i;
    generate
        for (i = 0; i < WIDTH; ++i) begin
            assign out[i] = in == i;
        end
    endgenerate

endmodule
