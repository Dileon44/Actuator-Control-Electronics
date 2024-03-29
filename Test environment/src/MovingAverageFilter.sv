// Actuator control electronics
// ==============================================================================
// Описание:
// Данный модуль реализует фильтрацию сигнала методом простого скользящего
// среднего.
// ==============================================================================

`include "src/General.sv"

module MovingAverageFilter #(
    parameter SIGNAL_RESOLUTION = 12,
    parameter MSB               = SIGNAL_RESOLUTION - 1,
    parameter NUMBER_POINTS     = 32
) (
    input          nReset_i,
    input          clk_i,
    input          enable_i,
    input  [MSB:0] signal_i,

    output [MSB:0] signal_o,
    output         finish_o
);

    import General::clog2;

    localparam SHIFT   = clog2(NUMBER_POINTS) - 1;
    localparam MSB_SUM = 17;    // для 32 значений - 4_096 * 32 = 131_072 (18 бит)
    // localparam MSB_SUM = 16; // для 16 значений - 4_096 * 16 = 65_536  (17 бит)
    // localparam MSB_SUM = 15; // для  8 значений - 4_096 *  8 = 32_768  (16 бит)

    reg [1:0]       switch_rg;
    reg [MSB:0]     signal_rg;
    reg [MSB:0]     finish_rg;
    reg [MSB:0]     signals_buf_rg [NUMBER_POINTS - 1:0];
    reg [MSB_SUM:0] sum_rg;

    assign signal_o = signal_rg;
    assign finish_o = finish_rg;

    always @(posedge clk_i) begin
        if (nReset_i) begin
            case (switch_rg)
                0: begin
                    if (enable_i) begin
                        finish_rg         <= 0;
                        signals_buf_rg[0] <= signal_i;

                        for (int i = 1; i <= NUMBER_POINTS - 1; i += 1) begin
                            signals_buf_rg[i] <= signals_buf_rg[i - 1];
                        end

                        switch_rg <= switch_rg + 1;
                    end
                end
                1: begin
                    sum_rg <= 
                        signals_buf_rg[0]  + 
                        signals_buf_rg[1]  + 
                        signals_buf_rg[2]  +
                        signals_buf_rg[3]  + 
                        signals_buf_rg[4]  + 
                        signals_buf_rg[5]  + 
                        signals_buf_rg[6]  + 
                        signals_buf_rg[7]  + 
                        signals_buf_rg[8]  +
                        signals_buf_rg[9]  + 
                        signals_buf_rg[10] +
                        signals_buf_rg[11] + 
                        signals_buf_rg[12] + 
                        signals_buf_rg[13] + 
                        signals_buf_rg[14] + 
                        signals_buf_rg[15] +
                        signals_buf_rg[16] + 
                        signals_buf_rg[17] + 
                        signals_buf_rg[18] +
                        signals_buf_rg[19] + 
                        signals_buf_rg[20] + 
                        signals_buf_rg[21] + 
                        signals_buf_rg[22] + 
                        signals_buf_rg[23] +
                        signals_buf_rg[24] + 
                        signals_buf_rg[25] + 
                        signals_buf_rg[26] +
                        signals_buf_rg[27] + 
                        signals_buf_rg[28] + 
                        signals_buf_rg[29] + 
                        signals_buf_rg[30] + 
                        signals_buf_rg[31];
                    switch_rg <= switch_rg + 1;
                end
                2: begin
                    signal_rg <= sum_rg >> SHIFT;
                    finish_rg <= 1;
                    switch_rg <= 0;
                end
                default: switch_rg <= 0;
            endcase
        end else begin
            for (int i = 0; i <= NUMBER_POINTS - 1; i += 1) begin
                signals_buf_rg[i] <= 12'h800;
            end
            switch_rg      <= 0;
            finish_rg      <= 1;
            signal_rg      <= 0;
            sum_rg         <= 17'h10000; // for 32 points
            // sum_rg      <= 16'h8000;  // for 16 points
            // sum_rg      <= 16'h4000;  // for  8 points
        end
    end
endmodule