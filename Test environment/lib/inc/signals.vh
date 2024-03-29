// Actuator control electronics
// ==============================================================================
// Описание:
// Файл с данными для работы с сигналами.
// ==============================================================================

`ifndef _sig_gen_vh_
    `define _sig_gen_vh_

/*******************************************************************************/
/*-------------------------------- Definitions --------------------------------*/
/*******************************************************************************/
    /*================ Clock State =================*/
        `define PEAK_DETECT_LOCAL               0
        `define PEAK_DETECT_ZERO_CROSS_EXTREMUM 1
        `define PEAK_DETECT_ZERO_CROSS_MIDDLE   2

    /*================ Clock State =================*/
        `define CLK_STATE_LOW       0
        `define CLK_STATE_HIGH      1
        `define CLK_STATE_RISE      2
        `define CLK_STATE_FALL      3
        `define CLK_STATE_UNDIFINED 4


`endif