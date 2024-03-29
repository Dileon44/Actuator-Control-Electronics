// Actuator control electronics
// ==============================================================================
// Описание:
// Данный модуль реализует передачу данных по интерфейсу UART.
// ==============================================================================

module uart_tx #(
    parameter SPEED    = 230_400, // bps
    parameter DATA_LEN = 8,
    parameter MSB      = DATA_LEN - 1
) (
    input         nReset_i,
    input         clk_i,
    input         start_i,
    input [MSB:0] data_i,

    output        Tx_o,
    output        busy_o
);

    localparam PRESCALE = 217; // = 50_000_000 MHz / 230_400 bps

    reg [4:0]   cnt_bit;
    reg         Tx_reg;
    reg         busy_reg;
    wire        idle;
    wire        pulse;

    assign Tx_o   = Tx_reg;
    assign busy_o = busy_reg;
    assign idle   = (cnt_bit == 4'hF);

    always @(posedge clk_i) begin
        if (nReset_i) begin
            if (start_i && idle) begin
                cnt_bit  <= 4'h0;
                busy_reg <= 1'b1;
                Tx_reg   <= 1'b0;
            end else if (pulse) begin
                case (cnt_bit)
                    4'h0: begin cnt_bit <= 4'h1; Tx_reg <= data_i[0]; end
                    4'h1: begin cnt_bit <= 4'h2; Tx_reg <= data_i[1]; end
                    4'h2: begin cnt_bit <= 4'h3; Tx_reg <= data_i[2]; end
                    4'h3: begin cnt_bit <= 4'h4; Tx_reg <= data_i[3]; end
                    4'h4: begin cnt_bit <= 4'h5; Tx_reg <= data_i[4]; end
                    4'h5: begin cnt_bit <= 4'h6; Tx_reg <= data_i[5]; end
                    4'h6: begin cnt_bit <= 4'h7; Tx_reg <= data_i[6]; end
                    4'h7: begin cnt_bit <= 4'h8; Tx_reg <= data_i[7]; end
                    4'h8: begin 
                        cnt_bit <= 4'h9; 
                        Tx_reg <= 1'h1;
                    end
                    default: begin
                        cnt_bit  <= 4'hF;
                        busy_reg <= 1'b0;
                    end
                endcase
            end
            // else begin
            //     Tx_reg <= 1'b1;
            // end
        end else begin
            Tx_reg     <= 1'b1;
            busy_reg   <= 0;
            cnt_bit    <= 0;
        end
    end

    SelectNPulse #(
		.N        (PRESCALE)
	) S1 (
		.nReset_i (nReset_i),
        .enable_i (1'b1),
		.clk_i    (clk_i),
		
		.pulse_o  (pulse)
	);

endmodule