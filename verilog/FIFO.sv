module FIFO #(
    parameter SIZE = 16,
    parameter WIDTH = 32,
    parameter ALERT_DEPTH = 3
) (
    input                    clock, reset,
    input                    wr_en,
    input                    rd_en,
    input        [WIDTH-1:0] wr_data,
    output logic             wr_valid,
    output logic             rd_valid,
    output logic [WIDTH-1:0] rd_data,
    output logic             almost_full,
    output logic             full
);

    // LAB5 TODO: Make the FIFO, see other TODOs below
    // Some things you will need to do:
    // - Define the sizes for your head (read) and tail (write) pointer
    // - Increment the pointers if needed (hint: try using the modulo operator: '%')
    // - Write to the tail when wr_en == 1 and the fifo isn't full
    // - Read from the head when rd_en == 1 and the fifo isn't empty

    parameter PTR_WIDTH = $clog2(SIZE + 1);

    logic next_full, next_almost_full, empty, next_empty;
    // logic next_wr_valid, next_rd_valid;

    logic [SIZE-1:0] [WIDTH-1:0] buffer;


    logic [PTR_WIDTH-1:0] head, next_head;
    logic [PTR_WIDTH-1:0] tail, next_tail;


    always_comb begin
        wr_valid = 1'b0;
        rd_valid = 1'b0;
        next_head = head;
        next_tail = tail;

        next_full = 1'b0;
        next_almost_full = 1'b0;
        next_empty = 1'b0;

        if (!empty) begin
            if (rd_en) begin
                rd_valid = 1'b1;
                next_head = (head + 1) % SIZE;
            end
            if (wr_en && (!full || rd_en)) begin
                wr_valid = 1'b1;
                next_tail = (tail + 1) % SIZE;
            end
        end else begin
            if (wr_en && (!full)) begin
                wr_valid = 1'b1;
                next_tail = (tail + 1) % SIZE;
            end
        end

        if (next_head == next_tail) begin
            if (!rd_valid && wr_valid) begin
                next_full = 1'b1;
                if (ALERT_DEPTH == 0) begin
                    next_almost_full = 1'b1;
                end
            end else if (rd_valid && !wr_valid) begin
                next_full = 1'b0;
                next_empty = 1'b1;
                if (ALERT_DEPTH == SIZE) begin
                    next_almost_full = 1'b1;
                end
            end else begin
                next_empty = empty;
                next_full = full;
                next_almost_full = almost_full;
            end
        end else begin
            if (next_head > next_tail) begin
                if (ALERT_DEPTH == next_head - next_tail) begin
                    next_almost_full = 1'b1;
                end
            end else begin
                if (ALERT_DEPTH == SIZE - next_tail + next_head) begin
                    next_almost_full = 1'b1;
                end
            end
        end
    end

    assign rd_data = rd_en ? buffer[head] : 0;

    always_ff @(posedge clock) begin
        if (reset) begin
            empty <= 1'b1;
            full <= (SIZE == 0);
            almost_full <= (SIZE == ALERT_DEPTH) ? 1'b1 : 1'b0;
            head <= 0;
            tail <= 0;
            // rd_valid <= 1'b0;
            // wr_valid <= 1'b0;

        end else begin
            empty <= next_empty;
            full <= next_full;
            almost_full <= next_almost_full;
            head <= next_head;
            tail <= next_tail;
            // rd_valid <= next_rd_valid;
            // wr_valid <= next_wr_valid;
            buffer[tail] <= wr_valid ? wr_data : buffer[tail];
        end
    end

endmodule
