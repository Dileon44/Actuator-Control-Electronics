// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл содержит код расчета умножения чисел с фиксированной точкой.
// Модуль производит расчет умножения двух чисел с фиксированной точкой 
// путём последовательного суммирования.
// ==============================================================================

module Mult #(
    parameter               WIDTH = 15,       // Параметр количества разрядов
    parameter               FBITS = 10        // Параметр количества разрядов для дробной части
) (
    input                   clk_i,            // Входной сигнал входной частоты
    input                   nReset_i,         // Входной сигнал сброса
    input                   enable_i,         // Входной сигнал начала приема пакета данных
    input  [WIDTH:0]        in1_i,            // Входной сигнал множителя 1
    input  [WIDTH:0]        in2_i,            // Входной сигнал множителя 2
    output [WIDTH:0]        out_o,            // Выходной сигнал результата умножения
    output                  finish_o          // Выходной сигнал завершения расчета
);

    reg[(WIDTH+WIDTH-1):0]  register_reg;     // Регистр, обновляемый каждый такт расчета
    reg[(WIDTH+WIDTH-1):0]  register_out_reg; // Регистр, обновляемый по окончании расчета
    reg[31:0]               i_reg;            // Регистр количества итераций расчета
    reg[31:0]               j_reg;            // Регистр количества итераций расчета
    reg                     enable_reg;       // Бит готовности к началу расчета
    reg                     switch_reg;       // Бит состояния расчета

    assign out_o[WIDTH-1:0] = register_out_reg[WIDTH-1:0];
    assign out_o[WIDTH]     = in1_i[WIDTH] ^ in2_i[WIDTH];
    assign finish_o         = ~enable_reg;
    
    always@ (posedge clk_i) begin
        if (nReset_i) begin
            case (switch_reg)
                0: begin
                    if (enable_i) begin
                        register_reg <= 0;
                        register_out_reg <= 0;
                        i_reg <= 0;
                        j_reg <= 0;
                        enable_reg <= 1;
                        switch_reg <= 1;
                    end
                end                
                1: begin    
                    if ((i_reg < (WIDTH)) & (enable_reg)) begin
                        if (in2_i[i_reg]) begin
                            register_reg <= (in1_i[WIDTH-1:0] << i_reg) + register_reg;// << 1;
                            j_reg <= j_reg + 1;
                            i_reg <= i_reg + 1;
                        end else begin
                            i_reg <= i_reg + 1;
                        end
                    end else begin
                        i_reg <= 0;
                        register_out_reg <= register_reg >> FBITS;
                        switch_reg <= 0;
                        enable_reg <= 0;
                    end
                end
            endcase
        end else begin
            register_reg     <= 0;
            register_out_reg <= 0;
            i_reg            <= 0;
            j_reg            <= 0;
            enable_reg       <= 0;
            switch_reg       <= 1'b0;
        end 
    end

endmodule
