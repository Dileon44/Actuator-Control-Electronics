// Actuator control electronics
// =============================================================================
// Описание:
// Модуль SPI для проведения тестов.
// =============================================================================

`timescale 1ps / 1ps

/******************************************************************************/
/*-------------------------------- Inclusions --------------------------------*/
/******************************************************************************/
    `include "spi.vh"
    `include "data.vh"
    `include "signals.vh"

/******************************************************************************/
/*---------------------------- Module Description ----------------------------*/
/******************************************************************************/
module SPI_Slave_TB
    #(
        parameter TIME_UPDATE_PERIOD_ps = 1000,
        parameter BITS_PER_FRAME        = 8,
        parameter BITS_BUFFER_SIZE      = BITS_PER_FRAME,
        parameter FIRST_BIT             = `MSB,
        parameter FIRST_WRITE_ON_nCS    = `FALSE,
        parameter LAST_CLK_IDLE         = `FALSE,
        parameter WRITE_DELAY_ps        = 0,

        parameter CLK_STATE_READ        = `CLK_STATE_FALL,
        parameter CLK_STATE_WRITE       = `CLK_STATE_FALL
    )
    (
        // Physical interface ports
            input       nCS_i,
            input       SCLK_i,
            input       SDI_i,

            output reg  SDO_o,

        // Data ports
            input       [(BITS_BUFFER_SIZE - 1):0]  tx_data_i,

            output reg  [(BITS_BUFFER_SIZE - 1):0]  rx_data_o,
            
        // Utility ports
            input   nReset_i,
            input   Enable_i,

        // Informational ports
            output reg  busy_o,
            output reg  data_ready_o,
            output reg  abort_o,
            output reg  idle_transmition_o,

            output reg  [15:0]  bites_rd_cnt_o          = 0,
            output reg  [15:0]  bites_wr_cnt_o          = 0,

            output reg  [31:0]  ncs_time_high_ps_o      = 0,
            output reg  [31:0]  ncs_time_low_ps_o       = 0,
            output reg  [31:0]  sclk_time_period_ps_o   = 0,
            output reg  [63:0]  sclk_freq_hz_o          = 0
    );


/******************************************************************************/
/*----------------------------- Local Parameters -----------------------------*/
/******************************************************************************/
    localparam MSB_BUF_NUMBER   = BITS_BUFFER_SIZE - 1;


/******************************************************************************/
/*-------------------------- Signals and  Variables --------------------------*/
/******************************************************************************/
    /*=============== Data Buffers ================*/
        reg[MSB_BUF_NUMBER:0]   tx_data_reg     = 0;
        reg[MSB_BUF_NUMBER:0]   rx_data_reg     = 7;

    /*================= Counters ==================*/
        integer                 tx_data_count   = 0;
        integer                 rx_data_count   = 0;
        integer                 sclk_rise_count = 0;
        integer                 sclk_idle_count = 0;

    /*================== States ===================*/
        reg [2:0]   sm_state_cur, sm_state_next;
        wire[2:0]   sclk_state;

    /*================= For Loop ==================*/
        integer     i = 0;
        
    /*================= Information =================*/
        reg  [63:0] time_ncs_high               = 0;
        reg  [63:0] time_ncs_low                = 0;
        reg  [63:0] time_sclk_period            = 0;


/*******************************************************************************/
/*--------------------------------- Instances ---------------------------------*/
/*******************************************************************************/
    /*============ SCLK State Detector ============*/
        CLK_State_Detector_TB
            #(
                .TIME_UPDATE_PERIOD_ps(TIME_UPDATE_PERIOD_ps)
            )
        SCLK_Detector
            (
                .clk_i          (SCLK_i),

                .clk_state_o    (sclk_state)
            );

/******************************************************************************/
/*--------------------------------- Behavior ---------------------------------*/
/******************************************************************************/
    /*=============== State Machine ===============*/
        always #TIME_UPDATE_PERIOD_ps begin
            if (!nReset_i)
                sm_state_cur = `SPI_STATE_IDLE;
            else 
                sm_state_cur = sm_state_next;
        end

    /*==================== Main ====================*/
        always @(sm_state_cur or sclk_state or nCS_i) begin
            if (!nReset_i) begin
                busy_o                  <= 0;
                data_ready_o            <= 0;
                abort_o                 <= 0;
                idle_transmition_o      <= 0;
                SDO_o                   <= 0;

                tx_data_count           <= 0;
                rx_data_count           <= 0;
                sclk_rise_count         <= 0;
                sclk_idle_count         <= 0;

                time_ncs_high           <= 0;
                time_ncs_low            <= 0;
                time_sclk_period        <= 0;

                bites_rd_cnt_o          <= 0;
                bites_wr_cnt_o          <= 0;
                ncs_time_high_ps_o      <= 0;
                ncs_time_low_ps_o       <= 0;
                sclk_time_period_ps_o   <= 0;

                sm_state_next           <= `SPI_STATE_IDLE;

            end else begin
                case (sm_state_cur)
                
                    `SPI_STATE_IDLE: begin
                        data_ready_o        <= 0;
                        SDO_o               <= 0;

                        tx_data_count       <= 0;
                        rx_data_count       <= 0;

                        sclk_rise_count     <= 0;
                        time_sclk_period    <= 0;

                        if (!nCS_i && Enable_i) begin
                            sm_state_next       <= `SPI_STATE_TRANSMIT;
                            ncs_time_high_ps_o  <= $time - time_ncs_high;
                            time_ncs_low        <= $time;
                            busy_o              <= 1;
                            
                            if (FIRST_BIT == `MSB) begin
                                for (i = 0; i < BITS_PER_FRAME ; i = i + 1) begin
                                    tx_data_reg[i] = tx_data_i[BITS_PER_FRAME - 1 - i];
                                end
                            end else
                                tx_data_reg = tx_data_i;
                            
                            if (FIRST_WRITE_ON_nCS) begin
                                SDO_o           <= tx_data_reg[tx_data_count]; 
                                tx_data_count   <= tx_data_count + 1;

                                rx_data_reg[rx_data_count] <= SDI_i;
                                rx_data_count              <= rx_data_count + 1;
                            end

                        end else if (Enable_i) begin
                            if ((sclk_state == `CLK_STATE_FALL) || (sclk_state == `CLK_STATE_RISE)) begin
                                sclk_idle_count <= sclk_idle_count + 1;
                                if (sclk_idle_count > 1)
                                    idle_transmition_o  <= 1;
                            end
                            busy_o              <= 0;
                        end else begin
                            idle_transmition_o  <= 0;
                            sclk_idle_count     <= 0;
                            busy_o              <= 0;
                        end

                    end

                    `SPI_STATE_TRANSMIT: begin
                        busy_o  <= 1;
                        abort_o <= 0;

                        // Count SCLK period
                        if (sclk_state == `CLK_STATE_RISE) begin
                            sclk_rise_count <= sclk_rise_count + 1;
                            if (sclk_rise_count == 0)
                                time_sclk_period <= $time;
                            else
                                sclk_time_period_ps_o <= ($time - time_sclk_period) / sclk_rise_count;
                        end

                        if (sclk_state == CLK_STATE_READ) begin
                            rx_data_reg[rx_data_count] <= SDI_i;
                            rx_data_count   <= rx_data_count + 1;
                        end

                        if (sclk_state == CLK_STATE_WRITE) begin
                            #WRITE_DELAY_ps
                            SDO_o           <= tx_data_reg[tx_data_count];
                            tx_data_count   <= tx_data_count + 1;
                        end

                        if ((tx_data_count >= BITS_BUFFER_SIZE) && (rx_data_count >= BITS_BUFFER_SIZE))
                            sm_state_next   <= `SPI_STATE_SET_RESULT;
                    end

                    `SPI_STATE_SET_RESULT: begin
                        bites_rd_cnt_o      <= rx_data_count;
                        bites_wr_cnt_o      <= tx_data_count;
                        sclk_idle_count     <= 0;
                        idle_transmition_o  <= 0;

                        busy_o                  <= 0;

                        // sclk_time_period_ps_o   = time_sclk_period;
                        sclk_freq_hz_o          = 1e12 / sclk_time_period_ps_o;

                        if ((LAST_CLK_IDLE == `TRUE) & (rx_data_count > 0))
                            tx_data_count <= tx_data_count - 1;

                        if (FIRST_BIT == `MSB) begin
                            for (i = 0; i < rx_data_count ; i = i + 1) begin
                                rx_data_o[i] <= rx_data_reg[rx_data_count - 1 - i];
                            end
                        end else
                            rx_data_o   <= rx_data_reg;
                        
                        if ((tx_data_count >= BITS_BUFFER_SIZE) && (rx_data_count >= BITS_BUFFER_SIZE))
                            sm_state_next   <= `SPI_STATE_FINISH;
                        else if ((tx_data_count < BITS_BUFFER_SIZE) || (rx_data_count < BITS_BUFFER_SIZE))
                            sm_state_next   <= `SPI_STATE_ABORT;
                    end

                    `SPI_STATE_FINISH: begin
                        bites_rd_cnt_o      = rx_data_count;
                        bites_wr_cnt_o      = tx_data_count;

                        // rx_data_count   <= 0;
                        // tx_data_count   <= 0;

                        if (nCS_i) begin
                            data_ready_o        <= 1;
                            sm_state_next       <= `SPI_STATE_IDLE;
                            ncs_time_low_ps_o   <= $time - time_ncs_low;
                            time_ncs_high       <= $time;
                        end else if (LAST_CLK_IDLE == `TRUE) begin
                            if (sclk_state == CLK_STATE_READ)
                                rx_data_count   <= rx_data_count + 1;

                            if (sclk_state == CLK_STATE_WRITE)
                                tx_data_count   <= tx_data_count + 1;
                        end
                    end

                    `SPI_STATE_ABORT: begin
                        abort_o         <= 1;
                        sm_state_next   <= `SPI_STATE_FINISH;
                    end

                    default: begin
                        sm_state_next = `SPI_STATE_IDLE;

                    end
                endcase

            end
        end

endmodule
