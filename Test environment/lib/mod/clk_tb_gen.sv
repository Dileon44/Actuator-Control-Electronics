// Actuator control electronics
// =============================================================================
// Описание:
// Модуль генератора синхросигнала для тестового окружения.
// =============================================================================

`timescale 1ps / 1ps


/******************************************************************************/
/*-------------------------------- Inclusions --------------------------------*/
/******************************************************************************/
    `include "signals.vh"
    `include "data.vh"


/******************************************************************************/
/*---------------------------- Module Description ----------------------------*/
/******************************************************************************/
module CLK_TB_Gen
    #(
        parameter   CLK_FREQ        = 1.0,              // In CLK_FREQ_UNITS
        parameter   CLK_FREQ_UNITS  = `FREQ_MHz,        // Look for units in clk.vh
        parameter   CLK_PHASE       = 0,                // In degrees
        parameter   CLK_DUTY        = 50,               // In percentage %
        parameter   CLK_INIT_LEVEL  = 0                 // clk_o level when module not enabled
    )
    (
    // Inputs
        input       clk_en_i,     // CLK enable signal.

    // Outputs
        output reg  clk_o
    );


/******************************************************************************/
/*----------------------------- Local Parameters -----------------------------*/
/******************************************************************************/
    localparam CLK_PERIOD           = 1e12 / (CLK_FREQ * CLK_FREQ_UNITS);
    localparam CLK_PERIOD_HALF      = CLK_PERIOD / 2;
    localparam CLK_PERIOD_QUARTER   = CLK_PERIOD / 4;

    localparam CLK_START_DELAY      = CLK_PERIOD_QUARTER * CLK_PHASE / 90;

    localparam CLK_TIME_ON          = CLK_DUTY / 100.0 * CLK_PERIOD;
    localparam CLK_TIME_OFF         = (100.0 - CLK_DUTY) / 100.0 * CLK_PERIOD;


/******************************************************************************/
/*-------------------------- Signals and  Variables --------------------------*/
/******************************************************************************/
    reg clk_start   = 0;


/*******************************************************************************/
/*--------------------------------- Instances ---------------------------------*/
/*******************************************************************************/
    /*==================== Main ====================*/
        initial begin
            clk_o       <= CLK_INIT_LEVEL;
            clk_start   <= 0;
            
            forever begin
                if (clk_en_i)
                    #CLK_PERIOD_HALF    clk_o = ~clk_o;
                else
                    #CLK_PERIOD_QUARTER clk_o = CLK_INIT_LEVEL;
            end
        end


    // always @(posedge clk_en_i or negedge clk_en_i) begin
    //     #CLK_START_DELAY

    //     if (clk_en_i)
    //         clk_start = 1;
    //     else
    //         clk_start = 0;
    // end

    // always @(posedge clk_start) begin
    //     if (clk_start) begin
    //         clk_o = 1;

    //         while (clk_start) begin
    //             #CLK_TIME_ON    clk_o = 0;
    //             #CLK_TIME_OFF   clk_o = 0;
    //         end

    //         clk_o = 0;
    //     end
    // end
        
endmodule
