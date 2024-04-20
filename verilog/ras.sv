`include "sys_defs.svh"

module ras (
    input clock,
    input reset,
    input  ID_RAS_PACKET [`N-1:0] id_ras_packet,
    output RAS_IF_PACKET [`N-1:0] ras_if_packet
);

    function automatic logic link(input REG_IDX r);
        return r == 1 || r == 5;
    endfunction

    ADDR [`RAS_SIZE-1:0] stack, next_stack;
    RAS_PTR head, next_head, tail, next_tail;

    always_comb begin
        ras_if_packet = 0;

        next_stack = stack;
        next_head  = head;
        next_tail  = tail;

        for (int i = 0; i < `N; ++i) if (id_ras_packet[i].valid) begin
            // pop
            if (link(id_ras_packet[i].rs) && id_ras_packet[i].rs != id_ras_packet[i].rd && next_head != next_tail) begin
                --next_tail;
                ras_if_packet[i].valid = `TRUE;
                ras_if_packet[i].ra    = next_stack[next_tail];
            end

            // push
            if (link(id_ras_packet[i].rd)) begin
                next_stack[next_tail] = id_ras_packet[i].NPC;
                ++next_tail;
                if (next_head == next_tail) ++next_head;
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            stack <= 0;
            head  <= 0;
            tail  <= 0;
        end else begin
            stack <= next_stack;
            head  <= next_head;
            tail  <= next_tail;
        end
    end

endmodule
