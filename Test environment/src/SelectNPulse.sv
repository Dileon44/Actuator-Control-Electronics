// Actuator control electronics
// ==============================================================================
// Описание:
// Данный модуль выделяет N-ый импульс из входного сигнала.
// ==============================================================================

`include "src/General.sv"

module SelectNPulse #(
		parameter N = 10
	) (
		input 		 nReset_i,
		input  bit   clk_i,
		input 		 enable_i,

		output logic pulse_o
	);

	import General::clog2;

	logic [clog2(N) - 1:0] counter = 0;
	
	always_ff @(posedge clk_i) begin
		if (!nReset_i) begin
			counter <= 0;
		end else if (enable_i) begin 
			if (pulse_o) begin
				counter <= 0;
			end else begin
				counter <= counter + 1'b1;
			end
		end else begin
			counter <= 0;
		end
	end

	assign pulse_o = (counter == N - 1);

endmodule
