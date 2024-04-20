`include "sys_defs.svh"

module onehotdec #(
    parameter WIDTH
) (
    input  logic [WIDTH-1:0]         in,
    output wor   [$clog2(WIDTH)-1:0] out,
    output logic                     valid
);

    assign valid = |in;

    genvar i;
    generate
        for (i = 0; i < WIDTH; ++i) begin
            assign out = in[i] ? i : 0;
        end
    endgenerate

endmodule
