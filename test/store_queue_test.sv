`include "sys_defs.svh"
`define CPU_DEBUG_OUT

module testbench;
    logic clock, reset, correct;

    // ID
    ID_SQ_PACKET [`N-1:0] id_sq_packet;
    logic almost_full;   // also to rs
    // RS
    RS_SQ_PACKET [`NUM_FU_STORE-1:0] rs_sq_packet;
    // ROB
    logic [`SQ_IDX_BITS-1:0] num_commit_insns;
    logic [`SQ_IDX_BITS-1:0] num_sent_insns;
    // dcache
    SQ_DCACHE_PACKET [`NUM_SQ_DCACHE-1:0] sq_dcache_packet;
    logic            [`NUM_SQ_DCACHE-1:0] dcache_accept;
    // RS for load
    logic [`SQ_IDX_BITS-1:0] head;
    logic [`SQ_IDX_BITS-1:0] tail;

    // --- combinational below
    logic [`SQ_IDX_BITS-1:0] tail_ready;
    // LQ
    ADDR     [`NUM_FU_LOAD-1:0] addr;
    SQ_IDX   [`NUM_FU_LOAD-1:0] tail_store;
    MEM_FUNC [`NUM_FU_LOAD-1:0] load_byte_info;
    DATA     [`NUM_FU_LOAD-1:0] value;
    logic    [`NUM_FU_LOAD-1:0] fwd_valid;
    SQ_ENTRY[(`SQ_LEN+1)-1:0] entries_out;
    logic    [`NUM_FU_LOAD-1:0][3:0] forwarded;


    store_queue dut(
        .clock(clock),
        .reset(reset),
        .id_sq_packet(id_sq_packet),
        .almost_full(almost_full),
        .rs_sq_packet(rs_sq_packet),
        .num_commit_insns(num_commit_insns),
        .num_sent_insns(num_sent_insns),
        .sq_dcache_packet(sq_dcache_packet),
        .dcache_accept(dcache_accept),
        .head(head),
        .tail(tail),
        .tail_ready(tail_ready),
        .addr(addr),
        .tail_store(tail_store),
        .load_byte_info(load_byte_info),
        .value(value),
        .fwd_valid(fwd_valid),
        .forwarded(forwarded),
        .entries_out(entries_out)
    );
    
    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task init;
        reset = 1;
        correct = 1;
        
        id_sq_packet = 0;
        rs_sq_packet = 0;
        num_commit_insns = 0;
        dcache_accept = 0;
        addr = 0;
        tail_store = 0;
        load_byte_info = 0;

        @(negedge clock);
        @(negedge clock);
        reset = 0;
        @(negedge clock);
        @(negedge clock);
    endtask

    task exit_on_error;
        begin
            $display("@@@ Incorrect at time %4.0f, clock %b\n", $time, clock);
            $display("@@@ Failed store queue test!");
            $finish;
        end
    endtask

    always_ff @(negedge clock) begin
        if (!correct) begin
            exit_on_error();
        end
    end

    task entering;
        for (int i = 0; i < `N; i++) begin
            id_sq_packet[i].valid = `TRUE;
            id_sq_packet[i].byte_info = MEM_BYTE;
        end
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        @(negedge clock);
        correct = almost_full;
        $display("Head: %d, Tail: %d, Tail_ready: %d\n", head, tail, tail_ready);
        @(negedge clock);
    endtask

    task lq_queryl;
        addr[0] = 32'hfeedb0ef;
        tail_store[0] = 1;
        load_byte_info[0] = MEM_WORD;
        @(negedge clock);

        $display("value:0x%8x, forwarded:%b, fwd_valid:%b", value[0], forwarded[0], fwd_valid[0]);
        // $display("num_sent_insns:%d", num_sent_insns);
        // for (int i = 0; i < `NUM_SQ_DCACHE; i++) begin
        //     $display("sq dcache valid[%2d]=%b", i, sq_dcache_packet[i].valid);
        // end
    endtask

    task fill_entry;
        for (SQ_IDX i = 0; i < `NUM_FU_STORE; i++) begin
            rs_sq_packet[i] = '{
                `TRUE,
                32'hfeedb000, // base
                12'h0ef,
                32'hdeadface, // data
                i
            };
        end
        @(negedge clock);
        rs_sq_packet = 0;
        @(negedge clock);
        @(negedge clock);
        $display("valid: %b", entries_out[0].valid);
        $display("valid: %b", entries_out[1].valid);
        $display("ready: %b", entries_out[1].ready);
        $display("Head: %d, Tail: %d, Tail_ready: %d\n", head, tail, tail_ready);
    endtask

    task commit;
        num_commit_insns = 2;
        dcache_accept = 4'b11; // lower bits are former requests
        #(`CLOCK_PERIOD/5.0);

        $display("num_sent_insns: %d", num_sent_insns);
        for (int i = 0; i < `NUM_SQ_DCACHE; i++) begin
            $display("sq_dcache_packet[%2d].valid = %b, addr = %h, data = %h\n", i, sq_dcache_packet[i].valid, sq_dcache_packet[i].addr, sq_dcache_packet[i].data);
        end
        @(negedge clock);
        $display("valid: %b", entries_out[0].valid);
        $display("valid: %b", entries_out[1].valid);
    endtask

    initial begin
        $display("store queue compiled\n");
        clock = 0;
        init; 

        entering;
        lq_queryl;
        fill_entry;
        lq_queryl;
        // commit;
        // lq_queryl;


        $finish;
    end
endmodule
