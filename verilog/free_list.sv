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
    `ifdef DEBUG_OUT
    , output logic [`FREE_LIST_PTR_WIDTH-1:0] head_out
    , output logic [`FREE_LIST_PTR_WIDTH-1:0] tail_out
    , output logic [`FREE_LIST_CTR_WIDTH-1:0] counter_out
    `endif
);


    PRN   [SIZE-1:0] free_list_entries, next_free_list_entries;
    logic [`FREE_LIST_CTR_WIDTH-1:0] counter, next_counter;
    logic [`FREE_LIST_PTR_WIDTH-1:0] head, next_head, tail, next_tail;
    FREE_LIST_PACKET        [`N-1:0] next_pop_packet;

    
    
    always_comb begin
        next_head              = head;
        next_tail              = tail;
        next_counter           = counter;
        next_free_list_entries = free_list_entries;
        
        for (int i = 0; i < `N; ++i) begin
            next_pop_packet[i].prn   = 0;
            next_pop_packet[i].valid = `FALSE;
        end 

        if (rat_squash) begin
            next_free_list_entries = input_free_list;
        end else begin
            // pop
            for (int i = 0; i < `N; ++i) begin
                if (pop_en[i]) begin
                    next_pop_packet[i].prn   = free_list_entries[next_head];
                    next_pop_packet[i].valid = `TRUE;
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

    `ifdef DEBUG_OUT
        assign head_out    = head;
        assign tail_out    = tail;
        assign counter_out = counter;
    `endif
    
    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= SIZE;
            head    <= 0;
            tail    <= 0;
            for (int i = 0; i < SIZE; i++) begin
                free_list_entries[i] = i;
            end
            for (int i = 0; i< `N; ++i) begin
                pop_packet[i].valid = `FALSE;
                pop_packet[i].prn   = 0;
            end
        end else begin
            free_list_entries <= next_free_list_entries;
            counter           <= next_counter;
            head              <= next_head;
            tail              <= next_tail;
            pop_packet        <= next_pop_packet;
        end
    end

endmodule

module rat_free_list #(
    parameter SIZE = `PHYS_REG_SZ_R10K
)(
    input  clock, reset,
    
    input  FREE_LIST_PACKET [`N-1:0]           push_packet,
    input  logic            [`N-1:0]           pop_en,
    input  PRN              [SIZE-1:0]         input_free_list,
    input  logic                               rat_squash,

    output FREE_LIST_PACKET [`N-1:0]           pop_packet
    `ifdef DEBUG_OUT
    , output PRN              [SIZE-1:0]       output_free_list
    `endif
);
    
    free_list #(.SIZE(SIZE)) free_l (
        .clock(clock),
        .reset(reset),
        .push_packet(push_packet),
        .pop_en(pop_en),
        .input_free_list(input_free_list),
        .rat_squash(rat_squash),
        .pop_packet(pop_packet)
        `ifdef DEBUG_OUT
        , .output_free_list()
        `else
        , .output_free_list(output_free_list)
        `endif
    );

endmodule

module rrat_free_list #(
    parameter SIZE = `PHYS_REG_SZ_R10K
)(
    input  clock, reset,
    
    input  FREE_LIST_PACKET [`N-1:0]           push_packet,
    input  logic            [`N-1:0]           pop_en,

    output FREE_LIST_PACKET [`N-1:0]           pop_packet,
    output PRN              [SIZE-1:0]         output_free_list
);
    
    // PRN [SIZE-1: 0] input_free_list;
    // assign input_free_list = 0;

    free_list #(.SIZE(SIZE)) free_l (
        .clock(clock),
        .reset(reset),
        .push_packet(push_packet),
        .pop_en(pop_en),
        .input_free_list(0),
        .rat_squash(`FALSE),
        .pop_packet(pop_packet),
        .output_free_list(output_free_list)
    );

endmodule