/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  regfile.sv                                          //
//                                                                     //
//  Description :  This module creates the Regfile used by the ID and  //
//                 WB Stages of the Pipeline.                          //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`include "sys_defs.svh"

module regfile (
    input         clock, // system clock
    // note: no system reset, register values must be written before they can be read
    input REG_IDX read_idx_1, read_idx_2, write_idx,
    input         write_en,
    input DATA    write_data,

    output DATA   read_out_1, read_out_2
);

    logic [31:1] [31:0] registers; // 31 32-length Registers (0 is known)

    // Read port 1
    always_comb begin
        if (read_idx_1 == `ZERO_REG) begin
            read_out_1 = 0;
        end else if (write_en && (write_idx == read_idx_1)) begin
            read_out_1 = write_data; // internal forwarding
        end else begin
            read_out_1 = registers[read_idx_1];
        end
    end

    // Read port 2
    always_comb begin
        if (read_idx_2 == `ZERO_REG) begin
            read_out_2 = 0;
        end else if (write_en && (write_idx == read_idx_2)) begin
            read_out_2 = write_data; // internal forwarding
        end else begin
            read_out_2 = registers[read_idx_2];
        end
    end

    // Write port
    always_ff @(posedge clock) begin
        if (write_en && write_idx != `ZERO_REG) begin
            registers[write_idx] <= write_data;
        end
    end

endmodule // regfile
