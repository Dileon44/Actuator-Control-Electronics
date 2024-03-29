// Actuator control electronics
// ==============================================================================
// Описание:
// Модуль для работы с АЦП MCP3201
// Тактовая частота: f_SCLK = 1.25 МГц
// ==============================================================================

`include "lib/inc/data.vh"

module ADC_MCP3201 #(
    parameter MCP3201_RESOLUTION = 12
) (
    input  nReset_i,
    input  clk_i,
    input  adc_enable_i,
    input  d_out_i,

    output SCLK_o,
    output nCS_o,
    output [MCP3201_RESOLUTION - 1:0] data_o,
    output finish_o
);
    localparam T_SUCS       = 100 * `TIME_ns;
    localparam DELAY_T_SUCS = T_SUCS / `PERIOD_CLK_FPGA;

    reg                            SCLK_reg;
    reg                            nCS_reg;
    reg [1:0]                      switch_reg;
    reg                            finish_reg;
    reg                            en_n_pulse_reg;
    reg [MCP3201_RESOLUTION - 1:0] data_o_reg;     // Регистр полученных значений пакета, обновляемый по окончании приема
    reg [MCP3201_RESOLUTION - 1:0] register_reg;   // Регистр полученных значений пакета, обновляемый каждый такт приема
    reg [7:0]                      delay_reg;      // Регистр, формирующий задержки
    wire                           sclk_en_reg;    // Бит, разрешающий изменение SCLK

    SelectNPulse #(
		.N(20)
    ) SelNPulse_inst (
        .nReset_i (nReset_i),
		.clk_i    (clk_i),
        .enable_i (en_n_pulse_reg),

		.pulse_o  (sclk_en_reg)
	);

    assign SCLK_o   = SCLK_reg;
    assign nCS_o    = nCS_reg;
    assign data_o   = data_o_reg;
    assign finish_o = finish_reg;

    always @(posedge clk_i) begin
        if (nReset_i) begin
            if (sclk_en_reg) begin
                SCLK_reg <= ~SCLK_reg;
            end

            case (switch_reg)
                0: begin
                    if (adc_enable_i) begin
                        switch_reg     <= 1;
                        nCS_reg        <= 1'b0;
                        en_n_pulse_reg <= 1'b1;
                        finish_reg     <= 0;
                    end
                end
                1: begin
                    if (sclk_en_reg) begin
                        delay_reg  <= delay_reg + 1'b1;
                    end

                    if (delay_reg == 6) begin
                        delay_reg  <= 0;
                        switch_reg <= 2;
                    end
                end
                2: begin
                    if (sclk_en_reg) begin
                        delay_reg  <= delay_reg + 1'b1;

                        if (~delay_reg[0]) begin
                            register_reg[11:0] <= { register_reg[10:0], d_out_i };
                        end
                    end

                    if (delay_reg == 24) begin
                        delay_reg  <= 0;
                        switch_reg <= 3;
                    end
                end
                3: begin
                    if (adc_enable_i) begin
                        data_o_reg <= register_reg;
                    end
                    
                    if (delay_reg < `DELAY_ADC_T_CSH) begin
                        nCS_reg        <= 1;
                        SCLK_reg       <= 0;
                        en_n_pulse_reg <= 0;
                        delay_reg      <= delay_reg + 1'b1;
                    end else begin
                        switch_reg     <= 0;
                        delay_reg      <= 0;
                        finish_reg     <= 1;
                    end
                end
            endcase
        end else begin
            delay_reg      <= 0;
            nCS_reg        <= 1;
            data_o_reg     <= 0;
            switch_reg     <= 0;
            SCLK_reg       <= 0;
            en_n_pulse_reg <= 0;
            finish_reg     <= 1;
            register_reg   <= 0;
        end
    end

endmodule
