// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл выполняет фильтрацию входных сигналов от дребезга и
// формирует импульсы, которые соответствуют нажатию кнопки.
// ==============================================================================

module FilterButtons #(
    parameter NUMBER_BUTTONS 	  = 4,
    parameter CLOCK_PERIOD_NS 	  = 20,
    parameter FILTER_PERIOD_NS 	  = 1_000_000,
    parameter PAUSE_INTERVAL_NS   = 400_000_000,
    parameter REPEATS_INTERVAL_NS = 150_000_000
) (
    input  nReset_i,
    input  clk_i,
         
    input  button_mode_i,
    input  button_minus_i,
    input  button_plus_i,
    input  button_4_i,

    output button_mode_o,
    output button_minus_o,
    output button_plus_o,
    output button_4_o
);

    wire mode_filtered;
    wire minus_filtered;
    wire plus_filtered;
    wire button_4_filtered;

	Filter #(
		.NUMBER_SIGNALS   (NUMBER_BUTTONS),
		.CLOCK_PERIOD_NS  (CLOCK_PERIOD_NS),
		.FILTER_PERIOD_NS (FILTER_PERIOD_NS)
    ) Filter_inst (
		.clk_i     (clk_i),
	    .signals_i ( { button_mode_i, button_minus_i, button_plus_i, button_4_i } ),
	    .signals_o ( { mode_filtered, minus_filtered, plus_filtered, button_4_filtered } )
	);

	PulseGenerator #(
		.CLOCK_PERIOD_NS     (CLOCK_PERIOD_NS),
		.PAUSE_INTERVAL_NS   (PAUSE_INTERVAL_NS),
		.REPEATS_INTERVAL_NS (REPEATS_INTERVAL_NS)
    ) PulseGenerator_inst (
        .nReset_i   (nReset_i),
		.clk_i      (clk_i),

        .mode_i     (mode_filtered),
        .plus_i     (plus_filtered),
        .minus_i    (minus_filtered),
        .button_4_i (button_4_filtered),

        .mode_o     (button_mode_o),
        .plus_o     (button_plus_o),
        .minus_o    (button_minus_o),
        .button_4_o (button_4_o)
	);

    endmodule