// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл содержит код расчета ПИ-регулятора.
// ==============================================================================

module PI #(
    parameter WIDTH = 16,       // sign + int + fixed
    parameter FBITS = 7,
    parameter MSB   = WIDTH - 1
) (
    input           clk_i,	    // Тактовый сигнал 50 МГц
    input           nReset_i,   // Сигнал сброса
    input           enable_i,   // Сигнал начала расчета
    input[MSB:0]    delta_i,	// Входной сигнал ПИ-регулятора
    input[MSB:0]    k_p_i,		// Коэффициент P ПИ-регулятора
    input[MSB:0]    k_i_i,	    // Коэффициент I ПИ-регулятора
    output[MSB:0]   pi_o,	    // Выходной сигнал расчета ПИ-регулятора
    output          finish_o    // Индикатор завершения расчета
);

    localparam DELTA_T_INTEGRAL = { { MSB{ 1'b0 } }, 1'b1 }; // 21'h000001;
    localparam MAX_INTEGRAL     = 32'h00000040;
    localparam MIN_INTEGRAL     = 32'h80000040;

    wire [MSB:0] mult_out;
    wire         mult_finish;
    wire [MSB:0] adder_out;
    wire         adder_finish;
    
    reg  [3:0]   switch_reg;
    reg  [MSB:0] pi_out_reg;
    reg  [MSB:0] delta_reg;
    reg  [MSB:0] P_reg;
    reg  [MSB:0] I_reg;
    reg          finish_reg;
    reg          mult_enable_reg;
    reg  [MSB:0] mult_buf_1_reg;
    reg  [MSB:0] mult_buf_2_reg;
    reg          adder_enable_reg;
    reg          adder_summing_reg;
    reg  [MSB:0] adder_buf_1_reg;
    reg  [MSB:0] adder_buf_2_reg;
            
    assign finish_o = finish_reg;
    assign pi_o     = pi_out_reg;
    
    always @(posedge clk_i) begin
        if (nReset_i) begin
            case (switch_reg)
                0: begin
                    if (enable_i) begin
                        switch_reg <= switch_reg + 1;
                        delta_reg  <= delta_i;
                        finish_reg <= 0;
                    end
                end
                1: begin
                    switch_reg      <= switch_reg + 1;
                    mult_enable_reg <= 1;
                    mult_buf_1_reg  <= delta_reg;
                    mult_buf_2_reg  <= k_p_i;
                end
                2: begin
                    mult_enable_reg <= 0;
                    if (~mult_enable_reg && mult_finish) begin
                        switch_reg     <= switch_reg + 1;
                        P_reg          <= mult_out;
                        mult_buf_1_reg <= 0;
                        mult_buf_2_reg <= 0;
                    end
                end
                3: begin
                    switch_reg <= switch_reg + 1;
                    mult_enable_reg <= 1;
                    mult_buf_1_reg <= delta_reg;
                    mult_buf_2_reg <= DELTA_T_INTEGRAL; // delta_t = 0.0078125
                end
                4: begin
                    mult_enable_reg <= 0;
                    if (~mult_enable_reg && mult_finish) begin
                        switch_reg        <= switch_reg + 1;
                        mult_buf_1_reg    <= 0;
                        mult_buf_2_reg    <= 0;
                        adder_enable_reg  <= 1;
                        adder_summing_reg <= 1;
                        adder_buf_1_reg   <= I_reg;
                        adder_buf_2_reg   <= mult_out;
                    end
                end
                5: begin
                    adder_enable_reg <= 0;
                    if (~adder_enable_reg && adder_finish) begin
                        switch_reg      <= switch_reg + 1;
                        I_reg           <= adder_out;
                        adder_buf_1_reg <= 0;
                        adder_buf_2_reg <= 0;
                    end
                end
                6: begin
                    switch_reg <= switch_reg + 1;
                    if ({ 1'b0, I_reg[MSB - 1:0] } > MAX_INTEGRAL) begin
                        if (I_reg[MSB]) begin
                            I_reg <= MIN_INTEGRAL;
                        end else begin
                            I_reg <= MAX_INTEGRAL;
                        end
                    end
                end
                7: begin
                    switch_reg      <= switch_reg + 1;
                    mult_enable_reg <= 1;
                    mult_buf_1_reg  <= k_i_i;
                    mult_buf_2_reg  <= I_reg;
                end
                8: begin
                    mult_enable_reg <= 0;
                    if (~mult_enable_reg && mult_finish) begin
                        switch_reg        <= switch_reg + 1;
                        adder_enable_reg  <= 1;
                        adder_summing_reg <= 1;
                        adder_buf_1_reg   <= P_reg;
                        adder_buf_2_reg   <= mult_out;
                    end
                end
                9: begin
                    adder_enable_reg <= 0;
                    if (~adder_enable_reg && adder_finish) begin
                        switch_reg      <= 0;
                        pi_out_reg      <= adder_out;
                        adder_buf_1_reg <= 0;
                        adder_buf_2_reg <= 0;
                        finish_reg      <= 1;
                    end
                end
                default:
                    switch_reg <= 0;
            endcase
        end
        else begin
            switch_reg        <= 0;
            delta_reg         <= 0;
            P_reg             <= 0;
            I_reg             <= 0;
            pi_out_reg        <= 0;
            finish_reg        <= 0;
            mult_enable_reg   <= 0;
            mult_buf_1_reg    <= 0;
            mult_buf_2_reg    <= 0;
            adder_enable_reg  <= 0;
            adder_summing_reg <= 0;
            adder_buf_1_reg   <= 0;
            adder_buf_2_reg   <= 0;
        end
    end

    Mult #(
        .WIDTH    (MSB),
        .FBITS    (FBITS)
    ) PIMult_inst 
    (
        .clk_i    (clk_i),
        .nReset_i (nReset_i),
        .enable_i (mult_enable_reg),
        .in1_i    (mult_buf_1_reg),
        .in2_i    (mult_buf_2_reg),
        .out_o    (mult_out),
        .finish_o (mult_finish)
    );

    Adder #(
        .WIDTH     (WIDTH)
    ) PIAdder_inst (
        .clk_i     (clk_i),
        .nReset_i  (nReset_i),
        .enable_i  (adder_enable_reg),
        .summing_i (adder_summing_reg),
        .in1_i     (adder_buf_1_reg),
        .in2_i     (adder_buf_2_reg),
        .out_o     (adder_out),
        .finish_o  (adder_finish)
    );
endmodule
