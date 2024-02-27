`include "sys_defs.svh"

module onehotdec #(
    parameter WIDTH
) (
    input  logic [WIDTH-1:0]         in,
    output logic [$clog2(WIDTH)-1:0] out,
    output logic                     valid
);

    logic [$clog2(WIDTH)-1:0] count;

    assign valid = count == 1;

    always_comb begin
        count = 0;
        for (int i = 0; i < WIDTH; ++i) begin
            if (in[i]) begin
                out = i;
                ++count;
            end
        end
    end

endmodule
