// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл содержит код расчета sin и cos на основе заданной амплитуды и
// текущей фазы. Модуль производит расчет sin и cos с фиксированной точкой путём
// последовательного суммирования (CORDIC-алгоритм).
// ==============================================================================

module sin #(
    parameter WIDTH = 16, 							   // Ширина входных сигналов
    parameter FBITS = 7			     				   // Количество разрядов дробной части
) (
    input                    nReset_i,                 // Входной сигнал сброса
    input                    enable_i,                 // Входной сигнал начала расчета
	input                    clk_i,                    // Входной сигнал тактовой частоты
    input  [WIDTH - 1:0]     amplitude_i,              // Входной сигнал максимальной амплитуды
	input  [WIDTH - 1:0]     angle_i,                  // Входной сигнал текущего угла

	output [WIDTH - 1:0]     cos_o,                    // Выходное значение cos
	output [WIDTH - 1:0]     sin_o,                    // Выходное значение sin
	output                   finish_o                  // Выходной сигнал завершения расчета
);
	
	wire       [WIDTH - 1:0] angleConstaint_reg[14:0]; // Набор регистров постоянных значений угла
	reg signed [WIDTH - 1:0] x_reg;                    // Регистр cos, обновляемый каждый такт расчета
	reg signed [WIDTH - 1:0] y_reg;                    // Регистр sin, обновляемый каждый такт расчета
    reg signed [WIDTH - 1:0] cos_reg;                  // Регистр полученного значения cos
    reg signed [WIDTH - 1:0] sin_reg;                  // Регистр полученного значения sin
	reg        [WIDTH - 1:0] angle_reg;                // Регистр текущего угла
	reg        [3:0]         switch_reg;               // Регистр выбора конечного автомата
	reg        [4:0]         i_reg;                    // Регистр выбора постоянного значения угла
	reg        [4:0]         j_reg;                    // Регистр выбора постоянного значения угла
	reg                      fin_reg;                  // Бит окончания расчета
	reg                      en_reg;                   // Бит готовности расчета
	
	assign finish_o = fin_reg;
	assign cos_o    = cos_reg;
	assign sin_o    = sin_reg;

	assign angleConstaint_reg[0]  = 16'b0_1000_0000_0000_000; // 1.570796327                  = 90          deg	
	assign angleConstaint_reg[1]  = 16'b0_0100_0000_0000_000; // 0.785398163 = atan(2^(1-1) ) = 45          deg 
	assign angleConstaint_reg[2]  = 16'b0_0010_0101_1100_100; // 0.463647609 = atan(2^(1-2) ) = 26.56505118 deg
	assign angleConstaint_reg[3]  = 16'b0_0001_0011_1111_011; // 0.244978663 = atan(2^(1-3) ) = 14.03624347 deg
	assign angleConstaint_reg[4]  = 16'b0_0000_1010_0010_001; // 0.124354995 = atan(2^(1-4) ) = 7.125016349 deg
	assign angleConstaint_reg[5]  = 16'b0_0000_0101_0001_011; // 0.06241881  = atan(2^(1-5) ) = 3.576334375 deg
	assign angleConstaint_reg[6]  = 16'b0_0000_0010_1000_110; // 0.031239833 = atan(2^(1-6) ) = 1.789910608 deg
	assign angleConstaint_reg[7]  = 16'b0_0000_0001_0100_011; // 0.015623729 = atan(2^(1-7) ) = 0.89517371  deg
	assign angleConstaint_reg[8]  = 16'b0_0000_0000_1010_001; // 0.007812341 = atan(2^(1-8) ) = 0.447614171 deg
	assign angleConstaint_reg[9]  = 16'b0_0000_0000_0101_001; // 0.00390623  = atan(2^(1-9) ) = 0.2238105   deg
	assign angleConstaint_reg[10] = 16'b0_0000_0000_0010_100; // 0.001953123 = atan(2^(1-10)) = 0.111905677 deg
	assign angleConstaint_reg[11] = 16'b0_0000_0000_0001_010; // 0.000976562 = atan(2^(1-11)) = 0.055952892 deg
	assign angleConstaint_reg[12] = 16'b0_0000_0000_0000_101; // 0.000488281 = atan(2^(1-12)) = 0.027976453 deg
	assign angleConstaint_reg[13] = 16'b0_0000_0000_0000_011; // 0.000244141 = atan(2^(1-13)) = 0.013988227 deg
	assign angleConstaint_reg[14] = 16'b0_0000_0000_0000_001; // 0.00012207  = atan(2^(1-14)) = 0.006994114 deg
		
	always @(posedge clk_i) begin
        if (nReset_i) begin
            case (switch_reg)
                0: begin
                    if (enable_i && fin_reg) begin
                        x_reg      <= 0;
                        y_reg      <= 0;
                        angle_reg  <= 0;
                        fin_reg    <= 0;
                        i_reg      <= 1;
                        switch_reg <= switch_reg + 1;
                    end
                end
                1: begin
                    angle_reg[13:0] <= angle_i[13:0];
                    switch_reg      <= 2;
                end
                2: begin
                    x_reg      <= amplitude_i;
                    y_reg      <= 0;
                    switch_reg <= switch_reg + 1;
                end
                3: begin
                    if (i_reg < WIDTH - 1) begin
                        if (angle_reg[WIDTH - 1]) begin
                            y_reg     <= y_reg - (x_reg >>> (i_reg - 1));
                            x_reg     <= x_reg + (y_reg >>> (i_reg - 1));
                            angle_reg <= angle_reg + angleConstaint_reg[i_reg];
                        end else begin
                            y_reg     <= y_reg + (x_reg >>> (i_reg - 1));
                            x_reg     <= x_reg - (y_reg >>> (i_reg - 1));
                            angle_reg <= angle_reg - angleConstaint_reg[i_reg];
                        end
                        i_reg <= i_reg + 1;
                    end 
                    else begin
                        switch_reg <= switch_reg + 1;
                    end
                end
                4: begin
                    if (angle_i[WIDTH-1 : WIDTH-2] == 2'b01) begin // + pi/2
                        x_reg[WIDTH - 2:0] <= y_reg[WIDTH - 2:0];
                        x_reg[WIDTH - 1]   <= 1;
                        y_reg              <= x_reg;
                    end else if (angle_i[WIDTH-1 : WIDTH-2] == 2'b10) begin // + pi
                        x_reg[WIDTH - 1] <= 1;
                        y_reg[WIDTH - 1] <= 1;
                    end else if (angle_i[WIDTH-1 : WIDTH-2] == 2'b11) begin // + 3*pi/2
                        x_reg              <= y_reg;
                        y_reg[WIDTH - 2:0] <= x_reg[WIDTH - 2:0];
                        y_reg[WIDTH - 1]   <= 1;
                    end
                    switch_reg <= 5;
                end
                5: begin
                    cos_reg    <= x_reg;
                    sin_reg    <= y_reg;
                    fin_reg    <= 1;
                    switch_reg <= 0;
                end
                default:
                    switch_reg <= 0;
            endcase		
        end 
        else 
        begin
            x_reg      <= 0;
            y_reg      <= 0;
            angle_reg  <= 0;
            switch_reg <= 0;
            i_reg      <= 1;
            j_reg      <= 0;
            fin_reg    <= 1;
            en_reg     <= 0;
            cos_reg    <= 0;
            sin_reg    <= 0;
        end
    end
endmodule
