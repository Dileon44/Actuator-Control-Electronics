// Actuator control electronics
// ==============================================================================
// Описание:
// Данный модуль задаёт требуемые параметры входных сигналов при разных режимах 
// работы стенда.
// ==============================================================================

`include "lib/inc/data.vh"

module ModeHub #(
    parameter ANGLE_RESOLUTION_INT   = 9,
    parameter AMP_DEG_RESOLUTION     = 6,
    parameter CNT_FREQ_RESOLUTION    = 4,
    parameter ANGLE_DEG_SHAFT_MAX    = 37
) (
    input                               nReset_i,
    input                               enable_i,
    input                               clk_i,

    input                               button_mode_i,
    input                               button_minus_i,
    input                               button_plus_i,
    input                               button_4_i,

    output [1:0]                        mode_o,
    output [ANGLE_RESOLUTION_INT - 1:0] angle_demanded_o,
    output [AMP_DEG_RESOLUTION - 1:0]   ampl_sine_demanded_o, // amplitude_sine_o = [0 ... 37] degrees - out actuator
    output [CNT_FREQ_RESOLUTION - 1:0]  cnt_freq_sine_demanded_o
);

    localparam EDIT_AMPLITUDE = 1'b0;
    localparam EDIT_FREQUENCY = 1'b1;

    reg [1:0]                        mode;
    reg                              state_edit_sine;
    reg [ANGLE_RESOLUTION_INT - 1:0] angle_rg;
    reg [AMP_DEG_RESOLUTION - 1:0]   ampl_sine_dem_rg;
    reg [CNT_FREQ_RESOLUTION - 1:0]  freq_sine_dem_rg;

    assign mode_o                   = mode;
    assign angle_demanded_o         = angle_rg;
    assign ampl_sine_demanded_o     = ampl_sine_dem_rg;
    assign cnt_freq_sine_demanded_o = freq_sine_dem_rg;

    always @(posedge clk_i) begin
        if (nReset_i) begin
            if (button_mode_i) begin
                if (mode < `MODE_K_VIS_FRIC) begin
                    mode <= mode + 1'b1;
                end else if (mode == `MODE_K_VIS_FRIC) begin
                    mode <= `MODE_ANGLE_DEMANDED;
                end
            end

            if (button_4_i) begin
                state_edit_sine <= ~state_edit_sine;
            end

            case (mode)
                `MODE_ANGLE_DEMANDED: begin
                    if (button_plus_i) begin
                        if (angle_rg < ({ 1'b0, 9'((1 << (ANGLE_RESOLUTION_INT - 1)) - 1) }) && angle_rg >= 0) begin
                            angle_rg <= angle_rg + 1'b1;
                        end else if (angle_rg <= ((1 << ANGLE_RESOLUTION_INT) - 1) && angle_rg > { 1'b0, 9'((1 << (ANGLE_RESOLUTION_INT - 1)) + 1)}) begin
                            angle_rg <= angle_rg - 1'b1;
                        end else if (angle_rg == { 1'b0, 9'((1 << (ANGLE_RESOLUTION_INT - 1)) + 1) }) begin
                            angle_rg <= 0;
                        end else if (angle_rg == { 1'b0, 9'((1 << (ANGLE_RESOLUTION_INT - 1)) - 1) }) begin
                            angle_rg <= (1 << ANGLE_RESOLUTION_INT) - 1;
                        end
                    end else if (button_minus_i) begin 
                        if (angle_rg < { 1'b0, 9'(1 << (ANGLE_RESOLUTION_INT - 1)) } && angle_rg > 0) begin
                            angle_rg <= angle_rg - 1'b1;
                        end else if (angle_rg > { 1'b0, 9'(1 << (ANGLE_RESOLUTION_INT - 1)) } && angle_rg < ((1 << ANGLE_RESOLUTION_INT) - 1)) begin
                            angle_rg <= angle_rg + 1'b1;
                        end else if (angle_rg == ((1 << ANGLE_RESOLUTION_INT) - 1)) begin
                            angle_rg <= { 1'b0, 9'((1 << (ANGLE_RESOLUTION_INT - 1)) - 1) };
                        end else if (angle_rg == 0) begin
                            angle_rg <= ({ 1'b0, 9'(1 << (ANGLE_RESOLUTION_INT - 1))}) + 1;
                        end
                    end
                end
                `MODE_SINE: begin
                    case (state_edit_sine)
                        EDIT_AMPLITUDE: begin
                            if (button_plus_i) begin
                                if (ampl_sine_dem_rg < ANGLE_DEG_SHAFT_MAX) begin
                                    ampl_sine_dem_rg <= ampl_sine_dem_rg + 1'b1;
                                end else begin
                                    ampl_sine_dem_rg <= 0;
                                end
                            end else if (button_minus_i) begin 
                                if (ampl_sine_dem_rg > 0) begin
                                    ampl_sine_dem_rg <= ampl_sine_dem_rg - 1'b1;
                                end else begin
                                    ampl_sine_dem_rg <= ANGLE_DEG_SHAFT_MAX;
                                end
                            end
                        end
                        EDIT_FREQUENCY: begin
                            if (button_plus_i) begin
                                freq_sine_dem_rg <= freq_sine_dem_rg + 1'b1;
                            end else if (button_minus_i) begin 
                                freq_sine_dem_rg <= freq_sine_dem_rg - 1'b1;
                            end
                        end
                        default: state_edit_sine <= 0;
                    endcase
                end
                `MODE_K_VIS_FRIC: begin
                end
                default: begin
                    mode <= 0;
                end
            endcase 
        end else begin
            mode             <= 0;
            angle_rg         <= 0;
            state_edit_sine  <= 0;
            ampl_sine_dem_rg <= 0;
            freq_sine_dem_rg <= 3'b010;
        end 
    end
endmodule
