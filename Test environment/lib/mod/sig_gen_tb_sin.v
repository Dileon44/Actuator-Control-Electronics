// Actuator control electronics
// =============================================================================
// Описание:
// Модуль генератора синусоидального сигнала для тестового окружения.
// =============================================================================

`timescale 1ps / 1ps

/******************************************************************************/
/*-------------------------------- Inclusions --------------------------------*/
/******************************************************************************/
    `include "signals.vh"
    // `include "const.vh"
    `include "data.vh"

/******************************************************************************/
/*---------------------------- Module Description ----------------------------*/
/******************************************************************************/
module Sig_Gen_TB_Sin #(
        parameter BITS_RESOLUTION       = 24,
        parameter TIME_UPDATE_PERIOD_ps = 1000,
        parameter FS_p_VOLTAGE_mV       = 10_000,
        parameter FS_m_VOLTAGE_mV       = -FS_p_VOLTAGE_mV,
        parameter CODE_REPRESENT        = `DATA_REPRESENT_UNSIGNED,
        parameter OVERDRIVE_BITS_ADD    = 8, // Additional bits for inner usage to handle out of range overdrive.
        parameter VAL_MSB               = BITS_RESOLUTION - 1
    ) (
        // Control
        input                   Start_i,
        input                   nReset_i,

        // Sin Parameters
        input[31:0]             Ampl_mV_i,
        input[31:0]             Freq_Hz_i,
        input[31:0]             Phase_Deg_i,
        input[31:0]             Offset_muV_i,

        // Outputs
        output reg[VAL_MSB:0]   Val_o
    );


/******************************************************************************/
/*----------------------------- Local Parameters -----------------------------*/
/******************************************************************************/
    //localparam VAL_MSB          = BITS_RESOLUTION - 1;
    localparam SIN_VAL_MAX          = 2 ** BITS_RESOLUTION;
    localparam SIN_VAL_MIN          = 0;
    localparam SIN_VAL_FS           = SIN_VAL_MAX - 1;
    localparam SIN_VAL_MIDLE        = SIN_VAL_MAX / 2;
    localparam SIN_VAL_AMPL         = SIN_VAL_MAX / 2;
    localparam SIN_VAL_RANGE        = FS_p_VOLTAGE_mV - FS_m_VOLTAGE_mV;

    localparam SIN_VAL_OD_MSB       = VAL_MSB + OVERDRIVE_BITS_ADD;
    localparam SIN_VAL_OD_RES       = SIN_VAL_OD_MSB + 1;
    localparam SIN_VAL_OD_MAX       = 2 ** SIN_VAL_OD_RES;
    localparam SIN_VAL_OD_FS        = SIN_VAL_OD_MAX - 1;
    localparam SIN_VAL_OD_MIDLE     = SIN_VAL_OD_MAX / 2;

    localparam SIN_VAL_OD_FS_p      = SIN_VAL_OD_MIDLE + SIN_VAL_AMPL - 1;
    localparam SIN_VAL_OD_FS_m      = SIN_VAL_OD_MIDLE - SIN_VAL_AMPL;

    localparam SIN_VAL_MIDLE_CONV   = SIN_VAL_OD_MIDLE - SIN_VAL_MIDLE;


/******************************************************************************/
/*-------------------------- Signals and  Variables --------------------------*/
/******************************************************************************/
    /*=================== Time ====================*/
        realtime    time_start;

    /*=================== Flags ====================*/
        reg     flag_start;

    /*================== Buffers ===================*/
        reg[SIN_VAL_OD_MSB:0]   sin_val_od, sin_val_buf;    // More bits for handling overdrive
        reg[VAL_MSB:0]          sin_val_final;              // Final value before code convertion


/*******************************************************************************/
/*--------------------------------- Functions ---------------------------------*/
/*******************************************************************************/
    function automatic signed [SIN_VAL_OD_MSB:0] Sin_Val_Code_Calculate
        (
            input[31:0] ampl, freq, phase, offset,
            input [63:0] time_cur
        );
            Sin_Val_Code_Calculate = SIN_VAL_OD_MIDLE + (1.0 * offset / 1e3 / SIN_VAL_RANGE) * SIN_VAL_MAX + ampl * (SIN_VAL_MAX *
                                $sin(`_2PI * (phase / 360.0 + 1.0 * time_cur * freq / 1e12)) / SIN_VAL_RANGE );

            // Sin_Val_Code_Calculate = $sin(time_cur);
            // $sin(`_2PI * (phase / 360.0 + 1.0 * time_cur * freq / 1e12))
    endfunction

/******************************************************************************/
/*--------------------------------- Behavior ---------------------------------*/
/******************************************************************************/
    /*=============== Initialization ===============*/
        initial begin
            sin_val_od  <= Sin_Val_Code_Calculate(Ampl_mV_i, Freq_Hz_i, Phase_Deg_i, Offset_muV_i, 0);
            flag_start  <= 0;
            time_start  <= 0;
        end
    
    /*==================== Main ====================*/
        
        always #TIME_UPDATE_PERIOD_ps begin
            if (!nReset_i) begin
                flag_start  <= 0;
                sin_val_od  <= Sin_Val_Code_Calculate(Ampl_mV_i, Freq_Hz_i, Phase_Deg_i, Offset_muV_i, 0);
            end else if (Start_i) begin
                flag_start  <= 1;
                sin_val_od <= Sin_Val_Code_Calculate(Ampl_mV_i, Freq_Hz_i, Phase_Deg_i, Offset_muV_i, $realtime - time_start);
            end else begin
                flag_start <= 0;
            end
        end

    /*============= Start Time Update =============*/
        always @(posedge flag_start)
            time_start <= $time;

    /*============= Overdrive Handler =============*/
        always @(sin_val_od) begin
            if (sin_val_od > SIN_VAL_OD_FS_p)
                sin_val_final <= SIN_VAL_FS;
            else if (sin_val_od < SIN_VAL_OD_FS_m)
                sin_val_final <= SIN_VAL_MIN;
            else
                sin_val_final <= sin_val_od - SIN_VAL_MIDLE_CONV;
        end
    
    /*============= Out Code Converter =============*/
        always @(sin_val_final) begin
            case (CODE_REPRESENT)

                `DATA_REPRESENT_UNSIGNED: begin
                    Val_o <= sin_val_final;
                end

                `DATA_REPRESENT_SIGN_MAG: begin
                    if (sin_val_final >= SIN_VAL_MIDLE)
                        Val_o <= sin_val_final - SIN_VAL_MIDLE;
                    else
                        Val_o <= {1'b1, sin_val_final[(VAL_MSB - 1):0]};
                end

                `DATA_REPRESENT_ONEs_COMPL: begin
                    if (sin_val_final >= SIN_VAL_MIDLE)
                        Val_o <= sin_val_final - SIN_VAL_MIDLE;
                    else
                        Val_o <= {1'b1, ~sin_val_final[(VAL_MSB - 1):0]};
                end
                
                `DATA_REPRESENT_TWOs_COMPL: begin
                    Val_o <= sin_val_final + SIN_VAL_MIDLE;
                end

                default:
                    Val_o <= sin_val_final;
            endcase
        end
endmodule
