`include "sys_defs.svh"

module sign_align (
    input  DATA     data;
    input  ADDR     addr;
    input  MEM_FUNC func;
    output DATA     out;
);

    union packed {
        logic [3:0]   signed [ 7:0]   signed_byte;
        logic [3:0] unsigned [ 7:0] unsigned_byte;
        logic [1:0]   signed [15:0]   signed_half;
        logic [1:0] unsigned [15:0] unsigned_half;
    } word;

    assign word = data;

    logic [2:0] byte_offset;
    logic [1:0] half_offset;

    assign byte_offset = addr[1:0];
    assign half_offset = addr[0];

    logic    func_unsigned;
    MEM_SIZE func_size;

    assign func_unsigned = func[2];
    assign func_size     = func[1:0];

    always_comb begin
        case (func_size)
            BYTE: begin
                if (func_unsigned)
                    out = word.unsigned_byte[byte_offset];
                else
                    out = word.  signed_byte[byte_offset];
            end

            HALF: begin
                if (func_unsigned)
                    out = word.unsigned_half[half_offset];
                else
                    out = word.  signed_half[half_offset];
            end

            default: out = data;
        endcase
    end

endmodule


// module re_align (
//     input  DATA     data;
//     input  ADDR     addr;
//     input  MEM_FUNC func;
//     output DATA     out;
// );
//     always_comb begin
//         out = 0;
//         case (func[1:0])
//             BYTE: begin
//                 out[(addr[1:0]+1)*8-1:addr[1:0]*8] = data[7:0];
//             end

//             HALF: begin
//                 out[(addr[0]+1)*16-1:addr[0]*16] = data[15:0];
//             end
//             default: begin
//                 out = data;
//             end
//         endcase
//     end

// endmodule

