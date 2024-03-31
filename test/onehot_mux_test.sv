`include "sys_defs.svh"

module testbench;

    logic       clock;
    DATA  [3:0] in;
    logic [3:0] select;
    DATA        out;

    onehot_mux #(
        .SIZE  ($bits(DATA)),
        .WIDTH (4)
    ) dut (
        .in     (in),
        .select (select),
        .out    (out)
    );

    always begin
        #(`CLOCK_PERIOD/2.0);
        clock = ~clock;
    end

    task print;
        foreach (in[i]) begin
            $display("in[%0d] = 0x%08x", i, in[i]);
        end
        $display("select = %04b", select);
        $display("out = 0x%08x", out);
    endtask

    initial begin
        clock = 0;
        @(negedge clock);
        foreach (in[i]) begin
            in[i] = $random;
        end
        select = 0;
        #(`CLOCK_PERIOD/4.0);
        print;

        foreach (in[i]) begin
            @(negedge clock);
            select = 1 << i;
            #(`CLOCK_PERIOD/4.0);
            print;
            assert (out === in[i]) else begin
                $display("@@@ Incorrect");
                $finish;
            end
        end

        $finish;
    end

endmodule
