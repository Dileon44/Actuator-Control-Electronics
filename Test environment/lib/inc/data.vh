// Actuator control electronics
// =============================================================================
// Описание:
// Заголовочный файл с макросами.
// =============================================================================

`ifndef _data_vh_
    `define _data_vh_

    /*================== Binary ===================*/
        `define FALSE               0
        `define TRUE                1

    /*================= First Bit =================*/
        `define LSB                 0
        `define MSB                 1

    /*=========== Value Representation ============*/
        `define DATA_REPRESENT_UNSIGNED   0
        `define DATA_REPRESENT_SIGN_MAG   1
        `define DATA_REPRESENT_ONEs_COMPL 2
        `define DATA_REPRESENT_TWOs_COMPL 3
        `define DATA_REPRESENT_OFFSET_BIN 4
        `define DATA_REPRESENT_BASE_n_2   5

    /*==================== Time ====================*/
        `define TIME_ps             1e0
        `define TIME_ns             1e3
        `define TIME_mus            1e6
        `define TIME_ms             1e9
        `define TIME_s              1e12

        `define PERIOD_CLK_FPGA     20 * `TIME_ns
        `define PERIOD_CLK_FPGA_ns  20

    /*================= Frequency ==================*/
        `define FREQ_Hz             1
        `define FREQ_kHz            1e3
        `define FREQ_MHz            1e6
        `define FREQ_GHz            1e9

        `define FPGA_FREQ_MHz       50
        `define FPGA_FREQ           `FPGA_FREQ_MHz * `FREQ_MHz

    /*================== MCP3201 ===================*/
        `define MCP3201_RESOLUTION  12
        `define DELAY_ADC_T_CSH     35 // 700 * `TIME_ns / `PERIOD_CLK_FPGA

    /*================= Mode ACE ===================*/
        `define MSB_ANGLE_DEGREES   15
        
        `define MODE_ANGLE_DEMANDED 2'b00
        `define MODE_SINE           2'b01
        `define MODE_K_VIS_FRIC     2'b10
    
    /*=================== Math =====================*/
        `define PI                  3.14159265
        `define _2PI                6.283185307

`endif