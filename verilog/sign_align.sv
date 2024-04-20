`include "sys_defs.svh"

// module sign_align (
//     input  DATA     data,
//     input  ADDR     addr,
//     input  MEM_FUNC func,
//     output DATA     out
// );

//     union packed {
//         logic   signed [3:0][ 7:0]   signed_byte;
//         logic unsigned [3:0][ 7:0] unsigned_byte;
//         logic   signed [1:0][15:0]   signed_half;
//         logic unsigned [1:0][15:0] unsigned_half;
//     } word;

//     assign word = data;

//     logic [1:0] byte_offset;
//     logic       half_offset;

//     assign byte_offset = addr[1:0];
//     assign half_offset = addr[1];

//     logic    func_unsigned;
//     MEM_SIZE func_size;

//     assign func_unsigned = func[2];
//     assign func_size     = func[1:0];

//     always_comb begin
//         case (func_size)
//             BYTE: begin
//                 if (func_unsigned)
//                     out = word.unsigned_byte[byte_offset];
//                 else
//                     out = word.signed_byte[byte_offset];
//             end

//             HALF: begin
//                 if (func_unsigned)
//                     out = word.unsigned_half[half_offset];
//                 else
//                     out = word.  signed_half[half_offset];
//             end

//             default: out = data;
//         endcase
//     end

// endmodule


module sign_align (
    input  DATA     data,
    input  ADDR     addr,
    input  MEM_FUNC func,
    output DATA     out
);

    union packed {
        logic [3:0][ 7:0] byte_level;
        logic [1:0][15:0] half_level;
    } word;

    assign word = data;

    logic [1:0] byte_offset;
    logic       half_offset;

    assign byte_offset = addr[1:0];
    assign half_offset = addr[1];

    always_comb begin
        out = 0;
        case (func)
            MEM_BYTE: begin
                // out[7:0]  = word.byte_level[byte_offset];
                // out[31:8] = {(24){word.byte_level[byte_offset][7]}};
                // out = {(24){word.byte_level[byte_offset][7]}, word.byte_level[byte_offset]};
                out = 32'(signed'(word.byte_level[byte_offset]));
            end
            MEM_HALF: begin
                // out = {16'b(word.half_level[half_offset][15]), word.half_level[half_offset]};
                // out[15:0] = word.half_level[half_offset];
                // out = {(16){word.half_level[half_offset][15]}, word.half_level[half_offset]};
                out = 32'(signed'(word.half_level[half_offset]));
            end
            MEM_WORD: begin
                out = data;
            end
            MEM_BYTEU: begin
                out = {24'b0, word.byte_level[byte_offset]};
            end
            MEM_HALFU: begin
                out = {16'b0, word.half_level[half_offset]};
            end
        endcase
    end

endmodule

