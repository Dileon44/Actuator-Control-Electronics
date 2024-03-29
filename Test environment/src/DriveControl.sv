// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл содержит алгоритм управления электродвигателем на основе
// текущего и требуемого углов поворота вала привода.
// ==============================================================================

`include "lib/inc/data.vh"

module DriveControl #(
    parameter ANGLE_FIXED_LEN   = 16,
    parameter MSB_ANGLE         = ANGLE_FIXED_LEN - 1,
    parameter ANGLE_RESOLUTION  = 8,
    parameter PWM_RESOLUTION    = 8,
    parameter FBITS             = 7,
    parameter FREQUENCY_PWM_kHz = 20,
    parameter WIDTH_THETA       = ANGLE_FIXED_LEN + 1,
    parameter MSB_THETA         = WIDTH_THETA - 1,
    parameter WIDTH_PI          = 32,
    parameter MSB_PI            = WIDTH_PI - 1
) (
    input               nReset_i,
    input               enable_i,
    input               clk_i,
    input [MSB_ANGLE:0] angle_demanded_i,
    input [MSB_ANGLE:0] angle_current_i,

    output              PWM_o,
    output              direction_o,
    output [7:0]        borehole_o,
    output [9:0]        theta_angle_o
);

    localparam K_PROPORTIAL         = 32'h00001080;             // K_p = 33 (sign_int_fixed = 0_0...0100001_0000000)
    localparam K_INTEGRAL           = 32'h00000000;             // K_i = 1;

    // localparam PERIOD_PWM_ns     = 1e6 / FREQUENCY_PWM_kHz;  // 50_000 нс = 50 мкс
    localparam K_DEGREES_2_BOREHOLE = 17'b0_000000000_1100111;  // 0.8046875 (коэффициент масштабирования из 316 град. в 255 единиц скважности - borehole)
    localparam PRESCALE             = 10;                       // 10 для 20 кГц,39 для 5 кГц (PERIOD_PWM_ns / `PERIOD_CLK_FPGA_ns / (2 ** PWM_RESOLUTION))
    localparam ANGLE_RANGE_DEGREES  = 9'b1_0011_1100;           // 316 degrees
    localparam CNT_BOREHOLE_MAX     = 8'hFF;

    reg  [2:0]                  switch_reg;
    reg  [MSB_ANGLE:0]          angle_demanded_rg;
    reg  [MSB_ANGLE:0]          angle_current_rg;
    
    reg  [MSB_THETA:0]          theta_angle_rg;
    wire [MSB_PI:0]             theta_angle_PI;

    reg                         adder_enable_reg;
    reg                         adder_summing_reg;
    reg  [MSB_THETA:0]          adder_buf_1_reg;
    reg  [MSB_THETA:0]          adder_buf_2_reg;
    wire [MSB_THETA:0]          adder_out;
    wire                        adder_finish;

    reg                         mult_enable_reg;
    reg  [MSB_THETA:0]          mult_buf_1_reg;
    reg  [MSB_THETA:0]          mult_buf_2_reg;
    wire [MSB_THETA:0]          mult_result;
    wire                        mult_finish;

    reg  [PWM_RESOLUTION - 1:0] cnt_pwm;
    reg  [PWM_RESOLUTION - 1:0] borehole_reg;
    reg                         PWM_reg;
    reg                         direction_reg;
    wire                        pwm_enable;

    reg                         PI_enable_reg;
    wire                        PI_finish;

    assign PWM_o       = PWM_reg;
    assign direction_o = direction_reg;
    assign borehole_o  = borehole_reg;
    assign theta_angle_o = theta_angle_rg[16:7];

    always @(posedge clk_i) begin
        if (nReset_i) begin
            case (switch_reg)
                0: begin
                    if (enable_i) begin
                        adder_enable_reg  <= 1;
                        adder_summing_reg <= 0;
                        adder_buf_1_reg   <= { angle_demanded_i[MSB_ANGLE], 1'b0, angle_demanded_i[MSB_ANGLE - 1:0] };
                        adder_buf_2_reg   <= {  angle_current_i[MSB_ANGLE], 1'b0,  angle_current_i[MSB_ANGLE - 1:0] };
                        switch_reg        <= switch_reg + 1;
                    end
                end
                1: begin
                    adder_enable_reg <= 0;
                    if (~adder_enable_reg && adder_finish) begin
                        theta_angle_rg <= adder_out;
                        switch_reg     <= switch_reg + 1;
                    end
                end
                2: begin
                        switch_reg    <= switch_reg + 1;
                        PI_enable_reg <= 1;
                end
                3: begin
                    // direction_reg <= ~theta_angle_rg[MSB_ANGLE];

                    PI_enable_reg <= 0;
                    if (~PI_enable_reg && PI_finish) begin
                        direction_reg <= ~theta_angle_PI[MSB_PI];

                        if ({ 1'b0, theta_angle_PI[MSB_PI - 1:0] } >= { 1'b0, { 15'h0000, ANGLE_RANGE_DEGREES }, { FBITS{1'b0} } }) begin
                            borehole_reg <= CNT_BOREHOLE_MAX;
                            switch_reg <= 0;
                        end else begin
                            mult_enable_reg <= 1'b1;
                            mult_buf_1_reg  <= { 1'b0, theta_angle_PI[MSB_THETA - 1 : 0] };
                            mult_buf_2_reg  <= K_DEGREES_2_BOREHOLE;

                            switch_reg <= switch_reg + 1;
                        end
                    end
                end
                4: begin
                    mult_enable_reg <= 1'b0;
                    if (~mult_enable_reg & mult_finish) begin
                        if (mult_result[FBITS +: PWM_RESOLUTION] > CNT_BOREHOLE_MAX) begin
                            borehole_reg <= CNT_BOREHOLE_MAX;
                        end else begin
                            borehole_reg <= mult_result[FBITS +: PWM_RESOLUTION]; // только положительное число получается
                        end
                        switch_reg <= 0;
                    end
                end
                default: begin
                    switch_reg <= 0;
                end
            endcase

            if (pwm_enable) begin
                cnt_pwm <= cnt_pwm + 1;
            end
            PWM_reg <= (borehole_reg >= cnt_pwm);

        end else begin
            switch_reg        <= 0;
            adder_enable_reg  <= 0;
            theta_angle_rg    <= 0;
            adder_summing_reg <= 0;
            borehole_reg      <= 0;
            cnt_pwm           <= 0;
            PWM_reg           <= 0;
            PI_enable_reg     <= 0;
        end
    end

    SelectNPulse #(
		.N        (PRESCALE)
	) S1 (
		.nReset_i (nReset_i),
        .enable_i (1'b1),
		.clk_i    (clk_i),
		
		.pulse_o  (pwm_enable)
	);

    Adder #(
        .WIDTH     (WIDTH_THETA)
    ) adder_theta_inst (
        .clk_i     (clk_i),
        .nReset_i  (nReset_i),
        .enable_i  (adder_enable_reg),
        .summing_i (adder_summing_reg),
        .in1_i     (adder_buf_1_reg),
        .in2_i     (adder_buf_2_reg),

        .out_o     (adder_out),
        .finish_o  (adder_finish)
    );

    Mult #(
        .WIDTH    (MSB_THETA),
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

    PI #(
        .WIDTH       (WIDTH_PI),
        .FBITS       (FBITS)
    ) PI_inst (
        .clk_i       (clk_i), 
        .nReset_i    (nReset_i), 
        .enable_i    (PI_enable_reg), 
        .delta_i       ({ theta_angle_rg[MSB_THETA], 15'h0000, theta_angle_rg[MSB_THETA - 1:0] }), 
        .k_p_i       (K_PROPORTIAL), 
        .k_i_i       (K_INTEGRAL), 
        .pi_o        (theta_angle_PI),
        .finish_o    (PI_finish)
    );

endmodule



// `include "lib/inc/data.vh"

// module DriveControl #(
//     parameter ANGLE_FIXED_LEN   = 16,
//     parameter MSB_ANGLE         = ANGLE_FIXED_LEN - 1,
//     parameter ANGLE_RESOLUTION  = 8,
//     parameter PWM_RESOLUTION    = 8,
//     parameter FBITS             = 7,
//     parameter FREQUENCY_PWM_kHz = 5,
//     parameter WIDTH_THETA       = ANGLE_FIXED_LEN + 1,
//     parameter MSB_THETA         = WIDTH_THETA - 1,
//     parameter WIDTH_PI          = 32,               // sign + int + fixed
//     parameter MSB_PI            = WIDTH_PI - 1
// ) (
//     input               nReset_i,
//     input               enable_i,
//     input               clk_i,
//     input [MSB_ANGLE:0] angle_demanded_i,
//     input [MSB_ANGLE:0] angle_current_i,

//     output              PWM_o,
//     output              direction_o,
//     output [7:0]        borehole_o,
//     output [9:0]        theta_angle_o
// );

//     localparam K_PROPORTIAL         = 32'h00001080;                  // K_p = 17;
//     localparam K_INTEGRAL           = 32'h00000080;                  // K_i = 1;

//     // localparam PERIOD_PWM_ns        = 1e6 / FREQUENCY_PWM_kGh;  // 200_000 нс = 200 мкс
//     localparam K_DEGREES_2_BOREHOLE = 17'b0_000000000_1100111;     // 0.8046875 (316 град. to 255 borehole) // localparam K_DEGREES_2_BOREHOLE = 11'b1000_1000000; // 8.5 (15 град. to 255)
//     localparam PRESCALE             = 10;                          //10 для 20 кГц,39 для 5 кГц; // PERIOD_PWM_ns / `PERIOD_CLK_FPGA_ns / (2 ** PWM_RESOLUTION);
//     localparam ANGLE_RANGE_DEGREES  = 9'b1_0011_1100;              // 316 degrees
//     localparam CNT_BOREHOLE_MAX     = 8'hFF;                       // localparam CNT_BOREHOLE_MAX     = 8'hFF;

//     reg  [2:0]                  switch_reg;
//     reg  [MSB_ANGLE:0]          angle_demanded_rg;
//     reg  [MSB_ANGLE:0]          angle_current_rg;
    
//     reg  [MSB_THETA:0]          theta_angle_rg;
//     wire [MSB_PI:0]             theta_angle_PI;

//     reg                         adder_enable_reg;
//     reg                         adder_summing_reg;
//     reg  [MSB_THETA:0]          adder_buf_1_reg;
//     reg  [MSB_THETA:0]          adder_buf_2_reg;
//     wire [MSB_THETA:0]          adder_out;
//     wire                        adder_finish;

//     reg                         mult_enable_reg;
//     reg  [MSB_THETA:0]          mult_buf_1_reg;
//     reg  [MSB_THETA:0]          mult_buf_2_reg;
//     wire [MSB_THETA:0]          mult_result;
//     wire                        mult_finish;

//     reg  [PWM_RESOLUTION - 1:0] cnt_pwm;
//     reg  [PWM_RESOLUTION - 1:0] borehole_reg;
//     reg                         PWM_reg;
//     reg                         direction_reg;
//     wire                        pwm_enable;

//     reg                         PI_enable_reg;
//     wire                        PI_finish;
//     // reg [MSB_PI:0]              K_proportial_reg;
//     // reg [MSB_PI:0]              K_integral_reg;

//     assign PWM_o       = PWM_reg;
//     assign direction_o = direction_reg;
//     assign borehole_o  = borehole_reg;
//     assign theta_angle_o = theta_angle_rg[16:8];

//     always @(posedge clk_i) begin
//         if (nReset_i) begin
//             case (switch_reg)
//                 0: begin
//                     if (enable_i) begin
//                         adder_enable_reg  <= 1;
//                         adder_summing_reg <= 0;
//                         adder_buf_1_reg   <= { angle_demanded_i[MSB_ANGLE], 1'b0, angle_demanded_i[MSB_ANGLE - 1:0] };
//                         adder_buf_2_reg   <= {  angle_current_i[MSB_ANGLE], 1'b0,  angle_current_i[MSB_ANGLE - 1:0] };
//                         switch_reg        <= switch_reg + 1;
//                     end
//                 end
//                 1: begin
//                     adder_enable_reg  <= 0;
//                     if (~adder_enable_reg && adder_finish) begin
//                         theta_angle_rg <= adder_out;
//                         switch_reg     <= switch_reg + 1;
//                     end
//                 end
//                 2: begin
//                         switch_reg       <= switch_reg + 1;
//                         PI_enable_reg    <= 1;
//                         // K_proportial_reg <= 17'h00200; // K_p = 4;
//                         // K_integral_reg   <= 17'h00080; // K_i = 1;
//                 end
//                 3: begin
//                     // direction_reg <= ~theta_angle_rg[MSB_THETA];

//                     PI_enable_reg <= 0;
//                     if (~PI_enable_reg && PI_finish) begin
//                         direction_reg <= ~theta_angle_PI[MSB_PI];

//                         if ({ 1'b0, theta_angle_PI[MSB_PI - 1:0] } >= { 1'b0, { 15'b0000, ANGLE_RANGE_DEGREES }, { FBITS{1'b0} } }) begin
//                             borehole_reg <= CNT_BOREHOLE_MAX;
//                             switch_reg <= 0;
//                         end else begin
//                             mult_enable_reg <= 1'b1;
//                             mult_buf_1_reg  <= { 1'b0, theta_angle_PI[MSB_THETA - 1 : 0] };
//                             mult_buf_2_reg  <= K_DEGREES_2_BOREHOLE;

//                             switch_reg <= switch_reg + 1;
//                         end
//                     end
//                 end
//                 4: begin
//                     mult_enable_reg <= 1'b0;
//                     if (~mult_enable_reg & mult_finish) begin
//                         if (mult_result[FBITS +: PWM_RESOLUTION] > CNT_BOREHOLE_MAX) begin
//                             borehole_reg <= CNT_BOREHOLE_MAX;
//                         end else begin
//                             borehole_reg <= mult_result[FBITS +: PWM_RESOLUTION]; // только положительное число получается
//                         end
//                         switch_reg <= 0;
//                     end
//                 end
//                 default: begin
//                     switch_reg <= 0;
//                 end
//             endcase

//             if (pwm_enable) begin
//                 cnt_pwm <= cnt_pwm + 1;
//             end

//             PWM_reg <= (borehole_reg >= cnt_pwm);
//         end else begin
//             switch_reg        <= 0;
//             adder_enable_reg  <= 0;
//             theta_angle_rg    <= 0;
//             adder_summing_reg <= 0;
//             borehole_reg      <= 0;
//             cnt_pwm           <= 0;
//             PWM_reg           <= 0;
//             PI_enable_reg     <= 0;
//             // K_proportial_reg  <= 0;
//             // K_integral_reg    <= 0;
//         end
//     end

//     SelectNPulse #(
// 		.N        (PRESCALE)
// 	) S1 (
// 		.nReset_i (nReset_i),
//         .enable_i (1'b1),
// 		.clk_i    (clk_i),
		
// 		.pulse_o  (pwm_enable)
// 	);

//     Adder #(
//         .WIDTH     (WIDTH_THETA)
//     ) adder_theta_inst 
//     (
//         .clk_i     (clk_i),
//         .nReset_i  (nReset_i),
//         .enable_i  (adder_enable_reg),
//         .summing_i (adder_summing_reg),
//         .in1_i     (adder_buf_1_reg),
//         .in2_i     (adder_buf_2_reg),

//         .out_o     (adder_out),
//         .finish_o  (adder_finish)
//     );

//     Mult #(
//         .WIDTH    (MSB_THETA),
//         .FBITS    (FBITS)
//     ) mult_inst (
//         .clk_i    (clk_i),
//         .nReset_i (nReset_i),
//         .enable_i (mult_enable_reg),
//         .in1_i    (mult_buf_1_reg),
//         .in2_i    (mult_buf_2_reg),
//         .out_o    (mult_result),
//         .finish_o (mult_finish)
//     );

//     PI #(
//         .WIDTH       (WIDTH_PI),
//         .FBITS       (FBITS)
//     ) PI_inst (
//         .clk_i       (clk_i), 
//         .nReset_i    (nReset_i), 
//         .enable_i    (PI_enable_reg), 
//         .delta_i       ({ theta_angle_rg[MSB_THETA], 15'b0000, theta_angle_rg[MSB_THETA - 1:0] }), 
//         .k_p_i       (K_PROPORTIAL), 
//         .k_i_i       (K_INTEGRAL), 
//         .pi_o        (theta_angle_PI),
//         .finish_o    (PI_finish)
//     );

// endmodule
