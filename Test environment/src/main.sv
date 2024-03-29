// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл содержит модуль верхнего уровня.
// ==============================================================================

`include "lib/inc/data.vh"

module main #(
    parameter NUM_INDICATORS = 8,
    parameter NUM_SEGMENTS   = 8
) (
    input        clk_fpga, // Тактовый сигнал 50 МГц

    input        button_mode,
    input        button_minus,
    input        button_plus,
    input        button_4,

    input        step_enable,

    input        MISO_pot,
    output       nCS_pot,
    output       SCLK_pot,
    
    output [7:0] indicators,
    output [7:0] segments,

    output       PWM,
    output       direction,

    output       uart_Tx
);

    localparam NUMBER_BUTTONS       = 4;
    localparam CLOCK_PERIOD_NS      = 20;
    localparam FILTER_PERIOD_NS     = 500_000;
    localparam PAUSE_INTERVAL_NS    = 400_000_000; // 500_000;
    localparam REPEATS_INTERVAL_NS  = 120_000_000; // 500_000;
    localparam ANGLE_RESOLUTION_INT = 9;       // 1 бит - знак, 8 бит - данные
    localparam ANGLE_RESOLUTION     = ANGLE_RESOLUTION_INT - 1; // без учёта знакового бита
    localparam ANGLE_FIXED_LEN      = 16;
    localparam ANGLE_FIXED_FBITS    = 7;
    localparam PWM_RESOLUTION       = 8;
    localparam FREQUENCY_PWM_kHz    = 20;
    localparam REFRESH_TIME_IND_NS  = 15_000_000;
    localparam UART_SPEED           = 230_400;
    localparam UART_DATA_LEN        = 8;
    localparam PRESCALE_SIN         = 763;
    localparam AMP_DEG_RESOLUTION   = 6;
    localparam CNT_FREQ_RESOLUTION  = 5;
    localparam FREQ_SINE_HZ_MSB     = 7;
    localparam ANGLE_DEG_SHAFT_MAX  = 37;
    localparam NUM_POINTS_FILTERED  = 32;
    localparam WIDTH_THETA          = 17;
    localparam WIDTH_PI             = 32;

    reg [3:0]                         cnt_init_rg;
    reg                               nReset_rg;
    reg                               drive_control_en_rg;
    reg [ANGLE_RESOLUTION_INT - 1:0]  angle_lock_rg;
    wire                              finish_adc_pot;
    wire                              filter_adc_finish;
    wire                              mult_finish;
    wire                              volt2degrees_finish;
    wire [`MCP3201_RESOLUTION - 1:0]  angle_adc;
    wire [`MCP3201_RESOLUTION - 1:0]  angle_adc_filtered;
    wire [`MSB_ANGLE_DEGREES:0]       angle_degrees;
    wire [`MSB_ANGLE_DEGREES:0]       angle_current;
    wire [ANGLE_FIXED_LEN - 1:0]      angle_demanded;
    wire [ANGLE_RESOLUTION_INT - 1:0] angle_demanded_step;
    wire                              button_mode_filtered;
    wire                              button_minus_filtered;
    wire                              button_plus_filtered;
    wire                              button_4_filtered;
    wire [1:0]                        mode_info;
    wire [7:0]                        borehole;
    reg  [ANGLE_FIXED_LEN - 1:0]      phase_rg;
    reg                               enable_sin_rg;
    wire [ANGLE_FIXED_LEN - 1:0]      sin_angle_demanded;
    wire                              finish_sin;
    wire                              pulse_sin;
    wire [AMP_DEG_RESOLUTION - 1:0]   cnt_ampl_sine_demanded;
    wire [CNT_FREQ_RESOLUTION - 1:0]  cnt_freq_sine_demanded;
    reg  [FREQ_SINE_HZ_MSB:0]         freq_sine_dem_Hz;
    reg  [ANGLE_FIXED_LEN - 1:0]      amplitude_sine_dem;
    reg  [12:0]                       prescale_sine; // 13 бит для частоты 0.1 Гц
    reg  [12:0]                       cnt_freq_sine;
    wire [ANGLE_RESOLUTION_INT:0]     theta_angle;

    initial begin
        cnt_init_rg = 0;
        nReset_rg   = 1'b0;
    end
    
    always @(posedge clk_fpga) begin
        if (cnt_init_rg == 4'hF) begin
            nReset_rg <= 1;
        end else begin
            cnt_init_rg <= cnt_init_rg + 1'b1;
            nReset_rg   <= 0;
        end

        if (nReset_rg) begin
            drive_control_en_rg <= 1'b1;

            if (step_enable) begin
                angle_lock_rg <= angle_demanded_step;
            end

            if (mode_info == `MODE_SINE) begin // генерация разных частот для задания синуса
                if (step_enable & finish_sin & pulse_sin) begin
                    phase_rg <= phase_rg + 1'b1;
                    enable_sin_rg <= 1;
                end else if (!step_enable || mode_info != `MODE_SINE) begin
                    phase_rg <= 0;
                end else begin
                    enable_sin_rg <= 0;
                end

                if (pulse_sin) begin
                    cnt_freq_sine <= 0;
                end else if (step_enable) begin
                    cnt_freq_sine <= cnt_freq_sine + 1'b1;
                end

                case (cnt_freq_sine_demanded)
                    0: begin
                        freq_sine_dem_Hz <= 8'h01; // 0.1 Hz
                        prescale_sine    <= 7_629;
                    end
                    1: begin
                        freq_sine_dem_Hz <= 8'h05; // 0.5 Hz
                        prescale_sine    <= 1_526;
                    end
                    2: begin
                        freq_sine_dem_Hz <= 8'h10; // 1  Hz
                        prescale_sine    <= 763;   // 50_000_000 / 2^16
                    end
                    3: begin
                        freq_sine_dem_Hz <= 8'h20;
                        prescale_sine    <= 381;
                    end
                    4: begin
                        freq_sine_dem_Hz <= 8'h30;
                        prescale_sine    <= 254;
                    end
                    5: begin
                        freq_sine_dem_Hz <= 8'h40;
                        prescale_sine    <= 191;
                    end
                    6: begin
                        freq_sine_dem_Hz <= 8'h50;
                        prescale_sine    <= 153;
                    end
                    7: begin
                        freq_sine_dem_Hz <= 8'h60;
                        prescale_sine    <= 127;
                    end
                    8: begin
                        freq_sine_dem_Hz <= 8'h70;
                        prescale_sine    <= 109;
                    end
                    9: begin
                        freq_sine_dem_Hz <= 8'h80;
                        prescale_sine    <= 95;
                    end
                    10: begin
                        freq_sine_dem_Hz <= 8'h90;
                        prescale_sine    <= 85;
                    end
                    11: begin
                        freq_sine_dem_Hz <= 8'hA0; // 10  Hz
                        prescale_sine    <= 76;
                    end
                    12: begin
                        freq_sine_dem_Hz <= 8'hB0; // 11  Hz
                        prescale_sine    <= 69;
                    end
                    13: begin
                        freq_sine_dem_Hz <= 8'hC0; // 12 Hz
                        prescale_sine    <= 64;
                    end
                    14: begin
                        freq_sine_dem_Hz <= 8'hD0; // 13 Hz
                        prescale_sine    <= 59;
                    end
                    15: begin
                        freq_sine_dem_Hz <= 8'hE0; // 20 Hz
                        prescale_sine    <= 38;
                    end
                    16: begin
                        freq_sine_dem_Hz <= 8'hF0; // 25 Hz
                        prescale_sine    <= 31;
                    end
                    default: begin
                        freq_sine_dem_Hz <= 8'h00;
                        prescale_sine    <= 10_000;
                    end
                endcase

                case (cnt_ampl_sine_demanded) // 0_01001100_0000000 - 126 degrees (30 degrees out actuator)
                    1:       amplitude_sine_dem <= 16'b0_00000010_1000100;
                    5:       amplitude_sine_dem <= 16'b0_00001100_1010101;
                    15:      amplitude_sine_dem <= 16'b0_00100110_0000000;
                    30:      amplitude_sine_dem <= 16'b0_01001100_0000000;
                    default: amplitude_sine_dem <= 16'b0_00000000_0000000;
                endcase
            end else begin
                phase_rg      <= 0;
                enable_sin_rg <= 0;
                cnt_freq_sine <= 0;
                prescale_sine <= 0;
            end
        end else begin
            drive_control_en_rg <= 1'b0;
            angle_lock_rg       <= 0;
            enable_sin_rg       <= 0;
            phase_rg            <= 0;
            freq_sine_dem_Hz    <= 0;
            prescale_sine       <= 0;
            cnt_freq_sine       <= 0;
            amplitude_sine_dem  <= 16'b0_01001100_0000000; // 30 degrees
        end
    end

    ADC_MCP3201 #(
        .MCP3201_RESOLUTION (`MCP3201_RESOLUTION)
    ) ADC_potentiometer (
        .nReset_i     (nReset_rg),
        .clk_i        (clk_fpga),
        .adc_enable_i (drive_control_en_rg),
        .d_out_i      (MISO_pot),

        .SCLK_o       (SCLK_pot),
        .nCS_o        (nCS_pot),
        .data_o       (angle_adc),
        .finish_o     (finish_adc_pot)
    );

    MovingAverageFilter #(
        .SIGNAL_RESOLUTION (`MCP3201_RESOLUTION),
        .NUMBER_POINTS     (NUM_POINTS_FILTERED)
    ) MovingAverageFilter_inst (
        .nReset_i          (nReset_rg),
        .clk_i             (clk_fpga),
        .enable_i          (drive_control_en_rg & finish_adc_pot),
        .signal_i          (angle_adc),

        .signal_o          (angle_adc_filtered),
        .finish_o          (filter_adc_finish)
    );

    VoltToDegrees #(
        .MCP3201_RESOLUTION (`MCP3201_RESOLUTION),
        .WIDTH              (ANGLE_FIXED_LEN),
        .FBITS              (ANGLE_FIXED_FBITS)
    ) volt2degrees_inst (
        .clk_i              (clk_fpga),
        .nReset_i           (nReset_rg),
        .enable_i           (1'b1),
        .angle_adc_i        (angle_adc_filtered),
        
        .out_o              (angle_degrees),
        .finish_o           (volt2degrees_finish)
    );

    FilterButtons #(
        .NUMBER_BUTTONS      (NUMBER_BUTTONS),
        .CLOCK_PERIOD_NS     (CLOCK_PERIOD_NS),
        .FILTER_PERIOD_NS    (FILTER_PERIOD_NS),
        .PAUSE_INTERVAL_NS   (PAUSE_INTERVAL_NS),
        .REPEATS_INTERVAL_NS (REPEATS_INTERVAL_NS)
    ) FilterButtons_inst (
        .nReset_i            (nReset_rg),
        .clk_i               (clk_fpga),

        .button_mode_i       (button_mode),
        .button_minus_i      (button_minus),
        .button_plus_i       (button_plus),
        .button_4_i          (button_4),

        .button_mode_o       (button_mode_filtered),
        .button_minus_o      (button_minus_filtered),
        .button_plus_o       (button_plus_filtered),
        .button_4_o          (button_4_filtered)
    );

    ModeHub #(
        .ANGLE_RESOLUTION_INT     (ANGLE_RESOLUTION_INT),
        .AMP_DEG_RESOLUTION       (AMP_DEG_RESOLUTION),
        .CNT_FREQ_RESOLUTION      (CNT_FREQ_RESOLUTION),
        .ANGLE_DEG_SHAFT_MAX      (ANGLE_DEG_SHAFT_MAX)
    ) ModeHub_inst (
        .nReset_i                 (nReset_rg),
        .enable_i                 (),
        .clk_i                    (clk_fpga),
        .button_mode_i            (button_mode_filtered),
        .button_minus_i           (button_minus_filtered),
        .button_plus_i            (button_plus_filtered),
        .button_4_i               (button_4_filtered),

        .mode_o                   (mode_info),
        .angle_demanded_o         (angle_demanded_step),
        .ampl_sine_demanded_o     (cnt_ampl_sine_demanded),
        .cnt_freq_sine_demanded_o (cnt_freq_sine_demanded)
    );

    DriveControl #(
        .ANGLE_FIXED_LEN   (ANGLE_FIXED_LEN),
        .FBITS             (ANGLE_FIXED_FBITS),
        .ANGLE_RESOLUTION  (ANGLE_RESOLUTION),
        .PWM_RESOLUTION    (PWM_RESOLUTION),
        .FREQUENCY_PWM_kHz (FREQUENCY_PWM_kHz),
        .WIDTH_THETA       (WIDTH_THETA),
        .WIDTH_PI          (WIDTH_PI)
    ) DriveControl_inst (
        .nReset_i          (nReset_rg),
        .enable_i          (drive_control_en_rg),
        .clk_i             (clk_fpga),
        .angle_demanded_i  (angle_demanded),
        .angle_current_i   (angle_current),

        .PWM_o             (PWM),
        .direction_o       (direction),
        .borehole_o        (borehole),
        .theta_angle_o     (theta_angle)
    );

    IndicatorsHub #(
        .ANGLE_RESOLUTION_INT  (ANGLE_RESOLUTION_INT),
        .NUM_INDICATORS        (NUM_INDICATORS),
        .NUM_SEGMENTS          (NUM_SEGMENTS),
        .REFRESH_TIME_NS       (REFRESH_TIME_IND_NS),
        .AMP_DEG_RESOLUTION    (AMP_DEG_RESOLUTION),
        .FREQ_SINE_MSB         (FREQ_SINE_HZ_MSB),
        .ANGLE_DEG_SHAFT_MAX   (ANGLE_DEG_SHAFT_MAX)
    ) IndicatorsHub_inst (
        .nReset_i              (nReset_rg),
        .enable_i              (),
        .clk_i                 (clk_fpga),
        .mode_info_i           (mode_info),
        .angle_demanded_i      (angle_demanded_step),
        .angle_current_i       (angle_degrees[`MSB_ANGLE_DEGREES -: ANGLE_RESOLUTION_INT]),
        .ampl_sine_dem_shaft_i (cnt_ampl_sine_demanded),
        .freq_sine_dem_Hz_i    (freq_sine_dem_Hz),

        .indicators_o          (indicators),
        .segments_o            (segments)
    );

    uart #(
        .SPEED            (UART_SPEED),
        .DATA_LEN         (UART_DATA_LEN),
        .ANGLE_FIXED_LEN  (ANGLE_FIXED_LEN),
        .ANGLE_FBITS      (ANGLE_FIXED_FBITS),
        .ANGLE_RESOLUTION (ANGLE_RESOLUTION)
    ) uart_inst (
        .nReset_i         (nReset_rg),
        .enable_i         (step_enable),
        .clk_i            (clk_fpga),
        .angle_current_i  (angle_current),
        .angle_demanded_i (angle_demanded),
        .borehole_i       (borehole),
        .theta_angle_i    (theta_angle),

        .Tx_o             (uart_Tx)
    );

    sin #(
        .WIDTH       (ANGLE_FIXED_LEN), 
        .FBITS       (ANGLE_FIXED_FBITS)
    ) sin_inst (
        .nReset_i    (nReset_rg),
        .enable_i    (enable_sin_rg),
        .clk_i       (clk_fpga),
        .amplitude_i (amplitude_sine_dem),
        .angle_i     (phase_rg),

        .cos_o       (),
        .sin_o       (sin_angle_demanded),
        .finish_o    (finish_sin)
    );

    assign pulse_sin = (cnt_freq_sine == prescale_sine - 1);

    assign angle_current  = angle_degrees;
    assign angle_demanded = (mode_info == `MODE_SINE && step_enable) ? sin_angle_demanded : 
                            (step_enable) ? { angle_demanded_step, 7'h00 } : { angle_lock_rg, 7'h00 };
endmodule