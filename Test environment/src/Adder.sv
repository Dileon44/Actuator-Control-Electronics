// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл содержит код расчета суммы и разности двух чисел.
// Входные числа и результат представлены в прямом коде.
// ==============================================================================

module Adder 
#(
    parameter WIDTH = 16,      // Параметр величины разрядов выходного out_o и других внутренних сигналов
    parameter MSB   = WIDTH - 1
) 
(
    input          clk_i,      // Входной сигнал тактовой частоты 
    input          nReset_i,   // Входной сигнал сброса
    input          enable_i,   // Входной сигнал начала расчета
    input          summing_i,  // Входной сигнал суммы/разности
    input  [MSB:0] in1_i,      // Входное число 1
    input  [MSB:0] in2_i,      // Входное число 2
    output [MSB:0] out_o,      // Выходное значение результата
    output         finish_o    // Выходной сигнал завершения расчета
);

    reg [3:0]   switch_reg;    // Регистр конечного автомата
    reg [MSB:0] in_1_rev_reg;  // Регистр числа 1 в обратном коде
    reg [MSB:0] in_2_rev_reg;  // Регистр числа 2 в обратном коде
    reg [MSB:0] in_1_comp_reg; // Регистр числа 1 в дополнительном коде
    reg [MSB:0] in_2_comp_reg; // Регистр числа 2 в дополнительном коде
    reg [MSB:0] result_reg;    // Регистр результата расчета
    reg         finish_reg;    // Бит завершения расчета
    integer     i_reg;
    integer     j_reg;
    
    assign out_o    = result_reg;
    assign finish_o = finish_reg;
    
    always @(posedge clk_i) begin
        if (nReset_i) begin
            if (enable_i) begin
                finish_reg <= 0;
                result_reg <= 0;
            end

            case (switch_reg)
                0: begin
                    if (summing_i) begin
                        in_2_rev_reg[MSB] <=  in2_i[MSB];
                    end else begin
                        in_2_rev_reg[MSB] <= ~in2_i[MSB];
                    end

                    if (enable_i) begin
                        switch_reg <= 1;
                        finish_reg <= 0;
                        in_1_rev_reg <= 0;
                        in_2_rev_reg[WIDTH - 2:0] <= 0;
                        in_1_comp_reg <= 0;
                        in_2_comp_reg <= 0;
                    end
                end
                1: begin
                    in_1_rev_reg[MSB] <= in1_i[MSB];

                    for (i_reg = 0; i_reg < MSB; i_reg = i_reg + 1) begin
                        if (in1_i[MSB] == 1) begin
                            in_1_rev_reg[i_reg]     <= ~in1_i[i_reg];
                        end else begin
                            in_1_rev_reg[i_reg] <= in1_i[i_reg];
                        end

                        if (in_2_rev_reg[MSB] == 1) begin
                            in_2_rev_reg[i_reg] <= ~in2_i[i_reg];
                        end else begin
                            in_2_rev_reg[i_reg] <=  in2_i[i_reg];
                        end
                    end
                    switch_reg <= 2;
                end
                2: begin
                    if (in1_i[MSB] == 1) begin
                        in_1_comp_reg <= in_1_rev_reg + 1;
                    end else begin
                        in_1_comp_reg <= in_1_rev_reg;
                    end

                    if (in_2_rev_reg[MSB] == 1) begin
                        in_2_comp_reg <= in_2_rev_reg + 1;
                    end else begin
                        in_2_comp_reg <= in_2_rev_reg;
                    end
                    switch_reg <= 3;
                end
                3: begin
                    result_reg <= in_1_comp_reg + in_2_comp_reg;
                    switch_reg <= 4;
                end
                4: begin
                    if (result_reg[WIDTH-1] == 1) begin
                        result_reg <= result_reg - 1;
                    end
                    switch_reg <= 5;
                end
                5: begin
                    if (result_reg[WIDTH-1] == 1) begin
                        for (j_reg = 0; j_reg < MSB; j_reg = j_reg + 1) begin
                            result_reg[j_reg] <= ~result_reg[j_reg];
                        end
                    end
                    switch_reg <= 0;
                    finish_reg <= 1;
                end
                default: 
                    switch_reg <= 0;
            endcase
        end
        else 
        begin
            switch_reg    <= 0;
            in_1_rev_reg  <= 0;
            in_2_rev_reg  <= 0;
            in_1_comp_reg <= 0;
            in_2_comp_reg <= 0;
            result_reg    <= 0;
            finish_reg    <= 1;
        end            
    end
endmodule
