// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл предназначен для тестирования системы управления приводом.
// ==============================================================================

`define TB_NAME "ACE_tb"

`include "tb/inc/_tb.vh"
`include "lib/inc/data.vh"
`include "lib/inc/spi.vh"

`timescale 1ps/1ps

module ACE_tb;

    wire      clk_fpga;
    reg       clk_fpga_en;
    reg       nReset;
    reg       Enable;
    reg       test_finish;
    reg       button_mode;
    reg       button_minus;
    reg       button_plus;
    reg       button_4;
    reg       step_enable;
    reg       transfer_uart_en;
    reg [7:0] indicators;
    reg [7:0] segments;

    wire      MISO_pot;
    wire      nCS_pot;
    wire      SCLK_pot;

    reg                                  spi_enable;
    reg  [(`SPI_ADC_DATA_LEN + 3 - 1):0] spi_data_tx_reg;
    wire [(`SPI_ADC_DATA_LEN + 3 - 1):0] spi_data_rx;
    wire [(`SPI_ADC_DATA_LEN + 3 - 1):0] spi_data_tx;
    wire                                 spi_nReset;
    wire                                 spi_data_ready;
    wire                                 spi_busy;
    wire                                 spi_abort;
    wire                                 spi_idle_transmition;
    wire [15:0]                          spi_bits_cnt_rd;
    wire [15:0]                          spi_bits_cnt_wr;
    wire [31:0]                          spi_ncs_time_high_ps;
    wire [31:0]                          spi_ncs_time_low_ps;
    wire [63:0]                          spi_sclk_freq_hz; // было [39:0]
    
    integer i_vcd;

    initial begin
        $dumpfile(`DUMP_FILE_NAME);
        $dumpvars(
            1, 
            clk_fpga, 
            ACE_tb,
            SPI_ADC_potentiometr,
            main_inst, 
            main_inst.ADC_potentiometer,
            main_inst.volt2degrees_inst,
            main_inst.ModeHub_inst,
            main_inst.DriveControl_inst,
            main_inst.DriveControl_inst.PI_inst,
            main_inst.uart_inst,
            main_inst.uart_inst.uart_tx_inst,
            main_inst.MovingAverageFilter_inst
        );

        for (i_vcd = 0; i_vcd < 32; i_vcd += 1) begin
            $dumpvars(1, main_inst.MovingAverageFilter_inst.signals_buf_rg[i_vcd]);
        end
    end

    CLK_TB_Gen #(
        .CLK_FREQ  (`FPGA_FREQ_MHz)
    ) clk_fpga_inst (
		 .clk_en_i (clk_fpga_en),
		 .clk_o    (clk_fpga)
	);

    main #(
        .NUM_INDICATORS (8),
        .NUM_SEGMENTS   (8)
    ) main_inst (
        .clk_fpga      (clk_fpga),

        .button_mode   (button_mode),
        .button_minus  (button_minus),
        .button_plus   (button_plus),
        .button_4      (button_4),

        .step_enable   (step_enable),
        
        .MISO_pot      (MISO_pot),
        .nCS_pot       (nCS_pot),
        .SCLK_pot      (SCLK_pot),
        
        .indicators    (indicators),
        .segments      (segments),

        .direction     (PWM),
        .PWM           (direction),
        .uart_Tx       ()
    );

    SPI_Slave_TB #(
        .TIME_UPDATE_PERIOD_ps (`SPI_UPDATE_PERIOD_ps),
        .BITS_PER_FRAME        (`SPI_ADC_DATA_LEN + 3),
        .FIRST_BIT             (`MSB),
        .FIRST_WRITE_ON_nCS    (`TRUE),
        .LAST_CLK_IDLE         (0),
        .WRITE_DELAY_ps        (0)
    ) SPI_ADC_potentiometr (
        // Physical interface ports
        .nCS_i                 (nCS_pot), 
        .SCLK_i           	   (SCLK_pot), 
        .SDI_i                 (1'b1),
        .SDO_o                 (MISO_pot), 
        // Data ports
        .tx_data_i             (spi_data_tx),
        .rx_data_o             (),
        // Utility ports
        .nReset_i              (nReset),
        .Enable_i              (1'b1),
        .busy_o                (spi_busy),
        .data_ready_o          (spi_data_ready),
        .abort_o               (spi_abort),
        .idle_transmition_o    (spi_idle_transmition),
        // Information ports
        .bites_rd_cnt_o        (spi_bits_cnt_rd),
        .bites_wr_cnt_o        (spi_bits_cnt_wr),
        .ncs_time_high_ps_o    (spi_ncs_time_high_ps),
        .ncs_time_low_ps_o     (spi_ncs_time_low_ps),
        .sclk_freq_hz_o        (spi_sclk_freq_hz)
    );

    Sig_Gen_TB_Sin #(
        .BITS_RESOLUTION       (12),
        .FS_p_VOLTAGE_mV       (5_000),
        .FS_m_VOLTAGE_mV       (0),
        .OVERDRIVE_BITS_ADD    (8)
    ) Gen_Sin (
        // Control
        .Start_i               (1),
        .nReset_i              (1),

        // Sin Parameters
        .Ampl_mV_i             (1_050),
        .Freq_Hz_i             (25),
        .Phase_Deg_i           (0),
        .Offset_muV_i          (0),

        // Outputs
        .Val_o                 (spi_data_tx)
    );

    initial begin
        nReset           = 1'b1;
        Enable           = 1'b1;
        test_finish      = 0;
        clk_fpga_en      = 1;

        step_enable      = 0;
        transfer_uart_en = 0;

        button_minus     = 1;
        button_mode      = 1;
        button_plus      = 1;
        button_4         = 1;

        spi_data_tx_reg  = { 3'b000, 12'h800 }; // 2.5 В - 0 градусов
    end

    initial #0 begin: Main
        #(2 * `TIME_mus);
        @(posedge clk_fpga);

        if (!test_finish) begin
            @(posedge test_finish);
        end

        $finish;
    end

    initial begin: TestBench
        step_enable = 0;
        #(1 * `TIME_ms);
        transfer_uart_en = 1;
        // Разрешение ступенчатого воздействия
        step_enable = 1;
        // Задание требуемого угла
        // button_minus = 0;
        // #(5 * `TIME_ms);
        // button_minus = 1;
        // Задаём сигнал с потенциометра
        // spi_data_tx_reg = { 3'b000, 12'h8AC }; // 15 degrees
        // spi_data_tx_reg = { 3'b000, 12'h754 }; // -15 degrees                            
        // spi_data_tx_reg = { 3'b000, 12'h999 }; // 3 В, 12'hA14 - 3.15 В
        // spi_data_tx_reg = { 3'b000, 12'hCCC }; // 3 В, 12'hA14 - 4 В
        // spi_data_tx_reg = { 3'b000, 12'h148 }; // 150 degrees
        // spi_data_tx_reg = { 3'b000, 12'hEB8 }; // -150 degrees
        // #(5 * `TIME_ms);
        // button_mode = 0;
        // button_mode = 1;
        #(100 * `TIME_ms);
        test_finish <= 1;
    end

    // assign spi_data_tx = spi_data_tx_reg;
endmodule
