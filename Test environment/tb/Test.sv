`timescale 1ps/1ps

`define TB_NAME         "Test"

`include "src/General.sv"
`include "tb/inc/_tb.vh"

module Test;
    import General::clog2;

    initial begin
        $dumpfile(`DUMP_FILE_NAME);
        $dumpvars(1, Clock);
    end

    reg Clock = 1'b0;
    real sin;
    real cos;
    real atan;

    initial repeat (100) #(10) Clock = ~Clock;

    initial begin
        #200;
        sin = 100;
        cos = 25;
        #10;
        atan = $atan2(sin, cos);
        #20;
        $display(" atan(100, 25)  = %f", atan);
        #200;
        sin = -1;
        cos = 0;
        #10;
        atan = $atan2(sin, cos);
        #20;
        $display(" atan(-1, 0) = %f \n", atan);
        $finish();
    end

endmodule
