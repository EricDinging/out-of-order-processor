`include "sys_defs.svh"

module cdb #(
    parameter SIZE = `CDB_SZ
)(
    input clock, reset,

    input CDB_PACKET cdb_input

    output CDB_PACKET cdb_output
);

endmodule
