// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл содержит код вывода информации на 8-сегментные индикаторы при
// разных режимах работы стенда.
// ==============================================================================

`include "lib/inc/data.vh"

module IndicatorsHub #(
    parameter ANGLE_RESOLUTION_INT = 9,
    parameter ANGLE_MSB            = ANGLE_RESOLUTION_INT - 1,
    parameter NUM_INDICATORS       = 8,
    parameter NUM_SEGMENTS         = 8,
    parameter REFRESH_TIME_NS      = 15_000_000,
    parameter ANGLE_DEG_SHAFT_MAX  = 37,
    parameter AMP_DEG_RESOLUTION   = 6,
    parameter AMP_MSB              = AMP_DEG_RESOLUTION - 1,
    parameter FREQ_SINE_MSB        = 7
) (
    input                         nReset_i,
    input                         enable_i,
    input                         clk_i,
    input [1:0]                   mode_info_i,           // регистр режима работы стенда
    input [ANGLE_MSB:0]           angle_demanded_i,
    input [ANGLE_MSB:0]           angle_current_i,
    input [AMP_MSB:0]             ampl_sine_dem_shaft_i, // амплитуда треб. гармонического сигнала, [0 ... 37] degrees
    input [FREQ_SINE_MSB:0]       freq_sine_dem_Hz_i,    // частота треб. гармонического сигнала, [0.1, 0.5, 1, 2, 3, ...] Hz

    output [NUM_INDICATORS - 1:0] indicators_o,
    output [NUM_SEGMENTS - 1:0]   segments_o
);

    import General::BCD2ESC;
    import General::Bin2BCD;
    import General::DeleteNullBCD;
    import General::DeleteNullBCDUnsigned;
    import General::clog2;

    localparam PRESCALE                = REFRESH_TIME_NS / `PERIOD_CLK_FPGA_ns / NUM_INDICATORS;
    localparam MAX_NUMBER_DIGITS_ANGLE = 3;
    localparam SIZE_ANGLE_BCD          = 4 * MAX_NUMBER_DIGITS_ANGLE;
    localparam SIZE_SINE_BCD           = 8;

    wire                       indicator_enable;
    reg [NUM_INDICATORS - 1:0] indicators_reg;
    reg [NUM_SEGMENTS - 1:0]   segments_reg;
    reg [31:0]                 data_BCD;
    reg [15:0]                 angle_dem_BCD;
    reg [15:0]                 angle_cur_BCD;
    reg [SIZE_SINE_BCD - 1:0]  ampl_sine_BCD;
    reg [SIZE_SINE_BCD - 1:0]  freq_sine_BCD;
    reg [3:0]                  i;
    reg [2:0]                  switch_angle;
    reg [1:0]                  switch_sine;
    reg                        display_fixed_rg;
    reg [3:0]                  sign_dem;
    reg [3:0]                  sign_cur;

    assign indicators_o = indicators_reg;
    assign segments_o   = segments_reg;

    always @(posedge clk_i) begin
        if (nReset_i) begin
            if (indicator_enable) begin
                indicators_reg <= { indicators_reg[NUM_INDICATORS - 2:0], indicators_reg[NUM_INDICATORS - 1] };
            end

            for (i = 0; i < 8; i += 1) begin
                if (~indicators_reg[i]) begin
                    segments_reg <= BCD2ESC(data_BCD[4 * i +: 4]);
                end
            end

            case (mode_info_i)
                `MODE_ANGLE_DEMANDED: begin
                    case (switch_angle)
                        0: begin
                            sign_dem = (angle_demanded_i[ANGLE_MSB]) ? General::MINUS : General::EMPTY;
                            sign_cur = (angle_current_i [ANGLE_MSB]) ? General::MINUS : General::EMPTY;

                            angle_dem_BCD = Bin2BCD(angle_demanded_i[ANGLE_MSB - 1:0], SIZE_ANGLE_BCD);
                            angle_cur_BCD = Bin2BCD(angle_current_i [ANGLE_MSB - 1:0], SIZE_ANGLE_BCD);

                            switch_angle <= switch_angle + 1;
                        end
                        1: begin
                            angle_dem_BCD <= { sign_dem, angle_dem_BCD[SIZE_ANGLE_BCD - 1:0] };
                            angle_cur_BCD <= { sign_cur, angle_cur_BCD[SIZE_ANGLE_BCD - 1:0] };
                            switch_angle <= switch_angle + 1;
                        end
                        2: begin
                            angle_dem_BCD <= DeleteNullBCD(angle_dem_BCD, 4 * 4);
                            angle_cur_BCD <= DeleteNullBCD(angle_cur_BCD, 4 * 4);
                            switch_angle <= switch_angle + 1;
                        end
                        3: begin
                            data_BCD <= { angle_dem_BCD, angle_cur_BCD };
                            switch_angle <= 0;
                        end
                        default: begin
                            switch_angle <= 0;
                        end
                    endcase
                end
                `MODE_SINE: begin
                    case (switch_sine)
                        0: begin
                            ampl_sine_BCD = Bin2BCD({ 2'b00, ampl_sine_dem_shaft_i }, SIZE_SINE_BCD);
                            freq_sine_BCD = freq_sine_dem_Hz_i;

                            if (|freq_sine_dem_Hz_i[FREQ_SINE_MSB:4]) begin // проверяем, что целая часть равна нулю
                                display_fixed_rg <= 1'b0;
                            end else begin
                                display_fixed_rg <= 1'b1;
                            end

                            switch_sine <= switch_sine + 1;
                        end
                        1: begin
                            ampl_sine_BCD <= DeleteNullBCDUnsigned(ampl_sine_BCD, SIZE_SINE_BCD);
                            freq_sine_BCD <= (display_fixed_rg) ? 
                                             { General::FIXED_POINT, freq_sine_BCD[3:0] } : 
                                             { 4'hF, freq_sine_BCD[FREQ_SINE_MSB:4] };
                                             
                            switch_sine <= switch_sine + 1;
                        end
                        2: begin
                            data_BCD <= { 
                                General::AMPLITUDE, 
                                General::EMPTY,
                                ampl_sine_BCD,
                                General::FREQUENCY, 
                                General::EMPTY,
                                freq_sine_BCD
                            };
                            switch_sine <= 0;
                        end
                        default: switch_sine <= 0;
                    endcase
                end
                `MODE_K_VIS_FRIC: begin
                    data_BCD <= { 4'hD, { 7{ General::EMPTY } } };
                end
                default: begin
                    data_BCD <= { 8{ General::EMPTY } };
                end
            endcase
        end else begin
            indicators_reg <= 8'b11111110;
            segments_reg   <= 8'b11111111;
            switch_angle   <= 0;
            switch_sine    <= 0;
            sign_dem       <= 0;
            sign_cur       <= 0;
            data_BCD       <= 0;
            angle_dem_BCD  <= 0;
            angle_cur_BCD  <= 0;
            ampl_sine_BCD  <= 0;
            freq_sine_BCD  <= 0;
            i              <= 0;
        end
    end

    SelectNPulse #(
		.N        (PRESCALE)
    ) SelectNPulse_inst (
		.nReset_i (1'b1),
        .enable_i (1'b1),
		.clk_i    (clk_i),
		
		.pulse_o  (indicator_enable)
	);
endmodule
