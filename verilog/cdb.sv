`include "sys_defs.svh"

module cdb #(
    parameter SIZE = `CDB_SZ
)(
    input clock, reset,

    input CDB_PACKET [SIZE-1:0] cdb_input,

    output CDB_PACKET [SIZE-1:0] cdb_output
);

    always_ff @(posedge clock) begin
        if (reset) begin
            cdb_output <= 0;
        end else begin
            cdb_output <= cdb_input;
        end
    end

endmodule
