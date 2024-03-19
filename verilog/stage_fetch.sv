`include "sys_defs.svh"

module branch_predictor #(

)(
    input clock, reset,

    input  PC_ENTRY       [`N-1:0] pc_entry,

    input  ROB_IF_PACKET  rob_if_packet,
    // output
    output ADDR           [`N-1:0] target_pc
);

    always_comb begin
        // modify BTB
        for (int i = 0; i < `N; ++i) begin
            if (rob_if_packet.entries[i].success) begin
            // TODO: predict success
            end else begin
            // TODO: predict fail
            end
        end

        // read BTB
        for (int i = 0; i < `N; ++i) begin
            if (pc_entry[i].is_branch && pc_entry[i].valid) begin
                target_pc[i] = pc_entry[i].pc + 4;
            end
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            // TODO
        end else begin
            // TODO
        end
    end

endmodule


module stage_fetch (
    input clock, reset,
    input ROB_IF_PACKET rob_if_packet,

    output IF_ID_PACKET [`N-1:0] if_id_packet
);
    ADDR pc_start, next_pc_start;
    
    PC_ENTRY [`N:0]   pc; // pc[`N] equals to pc[0] in the next cycle
    PC_ENTRY [`N-1:0] target_pc;
    
    
    // TODO
    branch_predictor bp (
        .clock(clock),
        .reset(reset),
        .pc(pc[`N-1:0]),
        .rrat_if_packet(rrat_if_packet),
        // output
        .target(target_pc)
    );

    icache ic (
        // TODO
    );

    always_comb begin
        pc[0] = pc_start;
        for (int i = 0; i < `N; ++i) begin
            if (!rob_if_packet.entries[i].success) begin
                pc[0] = rob_if_packet.resolve_target;
            end
        end

        for (int i = 0; i < `N; ++i) begin
            if () begin // TODO: if the instruction is a branch instruction
                pc[i+1] = target_pc[i+1];
            end else begin
                pc[i+1] = pc[i] + 4;
            end
        end
    end

    assign next_pc_start = pc[`N];

    always_ff @(posedge clock) begin
        if (reset) begin
            pc_start <= 0;
        end else begin
            pc_start <= next_pc_start;
        end
    end

endmodule