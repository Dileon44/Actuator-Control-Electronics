// Actuator control electronics
// ==============================================================================
// Описание:
// Данный модуль генерирует строб при нажатии или удержании кнопки.
// Строб возникает либо при единичном нажатии кнопки, либо возникает с
// определённой паузой при удержании кнопки.
// ==============================================================================

`include "src/General.sv"

module PulseGenerator #(
	parameter CLOCK_PERIOD_NS 	  = 20,
	parameter PAUSE_INTERVAL_NS	  = 250_000_000, // 250 ms
	parameter REPEATS_INTERVAL_NS = 150_000_000  // 150 ms
) (
	input		 nReset_i,
	input  bit   clk_i,

	input  logic mode_i,
	input  logic plus_i,
	input  logic minus_i,
	input  logic button_4_i,

	output logic mode_o 	= 1,
	output logic plus_o     = 1,
	output logic minus_o    = 1,
	output logic button_4_o = 1
);

	import General::clog2;

	localparam MAX_PAUSE    = PAUSE_INTERVAL_NS / CLOCK_PERIOD_NS;
	localparam MAX_REPEATS  = REPEATS_INTERVAL_NS / CLOCK_PERIOD_NS;
	localparam MAX_INTERVAL = (MAX_PAUSE > MAX_REPEATS) ? MAX_PAUSE : MAX_REPEATS;
	localparam SIZE 	    = clog2(MAX_INTERVAL);

	logic [SIZE - 1:0] counter = 0;
	logic 			   pulse   = 0;
	logic 			   pressed;

	enum logic [1:0] {
		IDLE, 
		PAUSE, 
		REPEATS
	} state = IDLE;

	assign pressed = (~(plus_i & minus_i)) | (mode_i) | (button_4_i);

	always_comb begin
		mode_o	   = pulse & ~mode_i;
		plus_o 	   = pulse & ~plus_i;
		minus_o    = pulse & ~minus_i;
		button_4_o = pulse & ~button_4_i;
	end

	always_ff @(posedge clk_i) begin
		if (nReset_i) begin
			if (pressed) begin
				case (state)
					IDLE: begin
						state <= PAUSE; 
						pulse <= 1; 
					end
					PAUSE: begin
						if (counter == MAX_PAUSE) begin
							state   <= REPEATS;
							pulse   <= 1;
							counter <= 0;
						end else begin
							pulse   <= 0; 
							counter <= counter + 1;
						end
					end
					REPEATS: begin
						if (counter == MAX_REPEATS) begin
							pulse   <= 1;
							counter <= 0;
						end else begin
							pulse   <= 0;
							counter <= counter + 1;
						end
					end
				endcase
			end else begin
				state   <= IDLE;
				counter <= 0;
			end
		end else begin
			state   <= IDLE;
			counter <= 0;
			pulse   <= 0;
		end
	end

endmodule
