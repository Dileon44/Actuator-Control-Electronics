// Actuator control electronics
// ==============================================================================
// Описание:
// Данный модуль реализует перевод оцифрованных данных (напряжение потенциометра) 
// в градусную меру поворота вала потенциометра. Полученный угол представляет 
// собой знаковое число с фиксированной частью.
// ==============================================================================

`include "lib/inc/data.vh"

module VoltToDegrees #(
    parameter MCP3201_RESOLUTION = `MCP3201_RESOLUTION,
    parameter WIDTH              = 16,
    parameter FBITS              = 7
) (
    input                             clk_i,        // Входной сигнал входной частоты
    input                             nReset_i,     // Входной сигнал сброса
    input                             enable_i,     // Входной сигнал начала приема пакета данных
    input  [MCP3201_RESOLUTION - 1:0] angle_adc_i,  // Входной сигнал с АЦП, подключённому к потенциометру

    output [WIDTH - 1:0]              out_o,        // Выходной сигнал результата перевода
    output                            finish_o      // Выходной сигнал завершения расчета
);

    reg  [1:0]                      switch_reg;     // Бит состояния расчета
    reg                             enable_reg;     // Бит готовности к началу расчета
    reg                             sign_angle_reg;
    reg  [MCP3201_RESOLUTION - 1:0] angle_adc_reg;
    reg  [MCP3201_RESOLUTION - 1:0] ampl_volt_reg;
    reg  [WIDTH - 2:0]              out_reg;        // 8 - для целой части, 7 - для дробной
    
    reg  [MCP3201_RESOLUTION + FBITS - 1:0] mult_buf_1_reg;
    reg  [MCP3201_RESOLUTION + FBITS - 1:0] mult_buf_2_reg;
    wire [MCP3201_RESOLUTION + FBITS - 1:0] mult_result;
    reg                                     mult_enable_reg;
    wire                                    mult_finish;

    assign out_o[WIDTH - 1:0] = { sign_angle_reg, out_reg };
    assign finish_o           = ~enable_reg;
    
    always@ (posedge clk_i) begin
        if (nReset_i) begin
            case (switch_reg)
                0: begin
                    if (enable_i) begin
                        enable_reg    <= 1;
                        switch_reg    <= switch_reg + 1;
                        angle_adc_reg <= angle_adc_i;
                    end
                end
                1: begin
                    if (angle_adc_reg[MCP3201_RESOLUTION - 1]) begin
                        ampl_volt_reg <= angle_adc_reg - 12'h800;
                    end else begin
                        ampl_volt_reg <= 12'h800 - angle_adc_reg;
                    end
                    sign_angle_reg <= ~angle_adc_reg[MCP3201_RESOLUTION - 1];
                    switch_reg     <= switch_reg + 1;
                end
                2: begin
                    mult_enable_reg <= 1'b1;
                    mult_buf_1_reg  <= { ampl_volt_reg, { FBITS{ 1'b0 } } };      // [12'h000; 12'h800]
                    mult_buf_2_reg  <= { { MCP3201_RESOLUTION{ 1'b0 } }, 7'h0B }; // 0.0879120879120879 = 0.0001011
                    switch_reg      <= switch_reg + 1;
                end
                3: begin
                    mult_enable_reg <= 1'b0;
                    if (~mult_enable_reg & mult_finish) begin
                        out_reg    <= mult_result[WIDTH - 2:0];
                        switch_reg <= 0;
                        enable_reg <= 0;
                    end
                end
            endcase
        end else begin
            out_reg         <= 0;
            mult_enable_reg <= 0;
            sign_angle_reg  <= 0;
            enable_reg      <= 0;
            switch_reg      <= 0;
        end 
    end

    Mult #(
        .WIDTH    (MCP3201_RESOLUTION + FBITS - 1),
        .FBITS    (FBITS)
    ) mult_inst (
        .clk_i    (clk_i),
        .nReset_i (nReset_i),
        .enable_i (mult_enable_reg),
        .in1_i    (mult_buf_1_reg),
        .in2_i    (mult_buf_2_reg),
        .out_o    (mult_result),
        .finish_o (mult_finish)
    );

endmodule
