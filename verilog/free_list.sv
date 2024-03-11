`include "sys_defs.svh"

module free_list #(
    parameter SIZE = `PHYS_REG_SZ_R10K
)(
    input  clock, reset,
    
    input  FREE_LIST_PACKET [`N-1:0]           push_packet,
    input  logic            [`N-1:0]           pop_en,
    input  PRN              [SIZE-1:0]         input_free_list,
    input  logic                               rat_squash,

    output FREE_LIST_PACKET [`N-1:0]           pop_packet,
    output PRN              [SIZE-1:0]         output_free_list
);

    PRN [SIZE-1:0] free_list_entries, next_free_list_entries;
    logic [`FREE_LIST_CTR_WIDTH-1:0] counter, next_counter;
    logic [`FREE_LIST_PTR_WIDTH-1:0] head, next_head, tail, next_tail;
    
    
    always_comb begin
        next_head = head;
        next_tail = tail;
        next_counter = counter;
        next_free_list_entries = free_list_entries;
        
        for (int i = 0; i < `N; ++i) begin
            pop_packet[i].prn   = 0;
            pop_packet[i].valid = `FALSE;
        end 

        if (rat_squash) begin
            next_free_list_entries = input_free_list;
        end else begin
            // pop
            for (int i = 0; i < `N; ++i) begin
                if (pop_en[i]) begin
                    pop_packet[i].prn   = next_free_list_entries[next_head];
                    pop_packet[i].valid = `TRUE;
                    next_head++;
                    next_counter--;
                end
            end

            // push
            for (int i = 0; i < `N; ++i) begin
                if (push_packet[i].valid) begin
                    next_free_list_entries[next_tail] = push_packet[i].prn;
                    next_tail++;
                    next_counter++;
                end
            end
        end
    end
    
    assign output_free_list = free_list_entries;
    
    always_ff (@posedge clock) begin
        if (reset) begin
            counter <= 0;
            head    <= 0;
            tail    <= 0;
            for (int i = 0; i < SIZE; i++) begin
                free_list_entries[i] = i;
            end
        end else begin
            free_list_entries <= next_free_list_entries;
            counter           <= next_counter;
            head              <= next_head;
            tail              <= next_tail;
        end
    end

endmodule
