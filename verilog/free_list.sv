`include "sys_defs.svh"

module free_list #(
    parameter SIZE = `PHYS_REG_SZ_R10K
)(
    input  clock, reset,
    
    input  FREE_LIST_PACKET [`N-1:0]                   push_packet,
    input  logic            [`N-1:0]                   pop_en,
    input  PRN              [SIZE-1:0]                 input_free_list,
    input  logic            [`FREE_LIST_PTR_WIDTH-1:0] head_in,
    input  logic            [`FREE_LIST_PTR_WIDTH-1:0] tail_in,
    input  logic            [`FREE_LIST_CTR_WIDTH-1:0] counter_in,
    input  logic                                       rat_squash,

    output FREE_LIST_PACKET [`N-1:0]           pop_packet,
    output PRN              [SIZE-1:0]         output_free_list,
    output logic [`FREE_LIST_PTR_WIDTH-1:0]    head_out,
    output logic [`FREE_LIST_PTR_WIDTH-1:0]    tail_out,
    output logic [`FREE_LIST_CTR_WIDTH-1:0]    counter_out
);


    PRN   [SIZE-1:0] free_list_entries, next_free_list_entries;
    logic [`FREE_LIST_CTR_WIDTH-1:0] counter, next_counter;
    logic [`FREE_LIST_PTR_WIDTH-1:0] head, next_head, tail, next_tail;
    // FREE_LIST_PACKET        [`N-1:0] next_pop_packet;

    
    
    // always_comb begin
    always_comb begin
        next_head              = head;
        next_tail              = tail;
        next_counter           = counter;
        next_free_list_entries = free_list_entries;

        if (rat_squash) begin
            next_free_list_entries = input_free_list;
            next_head              = head_in;
            next_tail              = tail_in;
            next_counter           = counter_in;
        end else begin
            // pop
            for (int i = 0; i < `N; ++i) begin
                if (pop_en[i] && next_counter > 0) begin
                    pop_packet[i].prn   = free_list_entries[next_head];
                    pop_packet[i].valid = `TRUE;
                    next_head = (next_head + 1) % SIZE;
                    next_counter--;
                end else begin
                    pop_packet[i].prn   = 0;
                    pop_packet[i].valid = `FALSE;
                end
            end

            // push
            for (int i = 0; i < `N; ++i) begin
                if (push_packet[i].valid && next_counter < SIZE) begin
                    next_free_list_entries[next_tail] = push_packet[i].prn;
                    next_tail = (next_tail + 1) % SIZE;
                    next_counter++;
                end
            end
        end
    end

    assign output_free_list = free_list_entries;
    assign head_out    = head;
    assign tail_out    = tail;
    assign counter_out = counter;


    always_ff @(posedge clock) begin
        if (reset) begin
            counter <= SIZE - `ARCH_REG_SZ;
            head    <= `ARCH_REG_SZ;
            tail    <= 0;
            for (int i = 0; i < SIZE; i++) begin
                free_list_entries[i] <= i;
            end
        end else begin
            free_list_entries <= next_free_list_entries;
            counter           <= next_counter;
            head              <= next_head;
            tail              <= next_tail;
        end
    end

endmodule

module rat_free_list #(
    parameter SIZE = `PHYS_REG_SZ_R10K
)(
    input  clock, reset,
    
    input  FREE_LIST_PACKET        [`N-1:0] push_packet,
    input  logic                   [`N-1:0] pop_en,
    input  PRN                   [SIZE-1:0] input_free_list,
    input  logic [`FREE_LIST_PTR_WIDTH-1:0] head_in,
    input  logic [`FREE_LIST_PTR_WIDTH-1:0] tail_in,
    input  logic [`FREE_LIST_CTR_WIDTH-1:0] counter_in,
    input  logic                            rat_squash,

    output FREE_LIST_PACKET   [`N-1:0] pop_packet
    `ifdef DEBUG_OUT
    , output PRN                              head, tail
    , output logic [`FREE_LIST_CTR_WIDTH-1:0] counter
    , output PRN                   [SIZE-1:0] free_list
    `endif
);
    
    free_list #(.SIZE(SIZE)) free_l (
        .clock(clock),
        .reset(reset),
        .push_packet(push_packet),
        .pop_en(pop_en),
        .input_free_list(input_free_list),
        .head_in(head_in),
        .tail_in(tail_in),
        .counter_in(counter_in),
        .rat_squash(rat_squash),
        .pop_packet(pop_packet)
        `ifdef DEBUG_OUT
        , .output_free_list(free_list)
        , .head_out(head)
        , .tail_out(tail)
        , .counter_out(counter)
        `endif
    );

endmodule

module rrat_free_list #(
    parameter SIZE = `PHYS_REG_SZ_R10K
)(
    input  clock, reset,
    
    input  FREE_LIST_PACKET [`N-1:0]           push_packet,
    input  logic            [`N-1:0]           pop_en,

    output FREE_LIST_PACKET        [`N-1:0]    pop_packet,
    output PRN                   [SIZE-1:0]    output_free_list,
    output logic [`FREE_LIST_PTR_WIDTH-1:0]    head_out,
    output logic [`FREE_LIST_PTR_WIDTH-1:0]    tail_out,
    output logic [`FREE_LIST_CTR_WIDTH-1:0]    counter_out
);
    
    // PRN [SIZE-1: 0] input_free_list;
    // assign input_free_list = 0;

    free_list #(.SIZE(SIZE)) free_l (
        .clock(clock),
        .reset(reset),
        .push_packet(push_packet),
        .pop_en(pop_en),
        .input_free_list({`PHYS_REG_SZ_R10K{1'b0}}),
        .head_in({`FREE_LIST_PTR_WIDTH{1'b0}}),
        .tail_in({`FREE_LIST_PTR_WIDTH{1'b0}}),
        .counter_in({`FREE_LIST_PTR_WIDTH{1'b0}}),
        .rat_squash(`FALSE),
        .pop_packet(pop_packet),
        .output_free_list(output_free_list),
        .head_out(head_out),
        .tail_out(tail_out),
        .counter_out(counter_out)
    );

endmodule