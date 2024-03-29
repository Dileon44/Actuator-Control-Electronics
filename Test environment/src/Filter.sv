// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл содержит код фильтрации сигналов от дребезга.
// ==============================================================================

module Filter #(
	parameter NUMBER_SIGNALS   = 4, 
	parameter CLOCK_PERIOD_NS  = 20,
	parameter FILTER_PERIOD_NS = 500_000
) (
	input  bit 						  clk_i, 
	input  logic [NUMBER_SIGNALS-1:0] signals_i,

	output logic [NUMBER_SIGNALS-1:0] signals_o = '1
);

	localparam Prescale = FILTER_PERIOD_NS / CLOCK_PERIOD_NS / (NUMBER_SIGNALS - 1);

	logic 			   Enable;
	logic [NUMBER_SIGNALS-1:0] Register [NUMBER_SIGNALS-1:0];

	initial begin
		for (int index = 0; index < NUMBER_SIGNALS; index++) begin
			Register[index] <= '1;
		end
	end

	generate
		if (Prescale > 1) begin
			SelectNPulse #(
				.N		  (Prescale)
			) S1 (
				.nReset_i (1'b1),
				.clk_i    (clk_i),
				.enable_i (1'b1),
				.pulse_o  (Enable)
			);
		end else begin
			assign Enable = 1;
		end
	endgenerate

	always_ff @(posedge clk_i) begin: shift_registers
		if (Enable) begin
			for (integer k = 0; k < NUMBER_SIGNALS; k++) begin
				Register[k] <= { Register[k][NUMBER_SIGNALS - 2:0], signals_i[k] };
			end
		end
	end: shift_registers

	always_ff @(posedge clk_i) begin: outputs
		if (Enable) begin
			for (int i = 0; i < NUMBER_SIGNALS; i++) begin
				if ((Register[i] == '0 && signals_o[i] == 1'b1) || (Register[i] == '1 && signals_o[i] == 1'b0)) begin
					signals_o[i] <= ~signals_o[i];
				end
			end
		end
	end: outputs
endmodule: Filter