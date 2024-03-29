// Actuator control electronics
// ==============================================================================
// Описание:
// Данный модуль формирует пакет данных для передачи по интерфейсу UART.
// ==============================================================================

`include "lib/inc/data.vh"

module uart #(
    parameter SPEED            = 230_400,
    parameter DATA_LEN         = 8,
    parameter ANGLE_FIXED_LEN  = 16,
    parameter ANGLE_MSB        = ANGLE_FIXED_LEN - 1,
    parameter ANGLE_FBITS      = 7,
    parameter ANGLE_RESOLUTION = 8
) (
    input               nReset_i,
    input               enable_i,
    input               clk_i,
    input [ANGLE_MSB:0] angle_current_i,
    input [ANGLE_MSB:0] angle_demanded_i,
    input [7:0]         borehole_i,
    input [9:0]         theta_angle_i,

    output              Tx_o
);

    import General::BCD2ASCII;
    import General::Bin2BCD;
    import General::Binary2Fixed;
    import General::DeleteNullBCD;
    import General::MINUS;
    import General::EMPTY;

    localparam NUMBER_SIMBOLS        = 25;
    localparam BYTE                  = 8;
    localparam POINT_ASCII           = 8'h2E;
    localparam NULL_ASCII            = 8'h00;
    localparam MINUS_ASCII           = 8'h2D;
    localparam LINE_FEED_ASCII       = 8'h0A;
    localparam CARRIAGE_RETURN_ASCII = 8'h0D;
    localparam COMMA_ASCII           = 8'h2C;

    // localparam CONST_100M_tact        = 100_000_000;
    // localparam CONST_50M_tact         = 50_000_000;
    // localparam CONST_5M_tact          = 5_000_000;
    // localparam CONST_500k_tact        = 500_000;
    // localparam CONST_50k_tact         = 50_000;

    localparam CONST_500M_tact        = 500_000_000;
    localparam CONST_100M_tact        = 27'b101_1111_0101_1110_0001_0000_0000;
    localparam CONST_50M_tact         = 26'b10_1111_1010_1111_0000_1000_0000;
    localparam CONST_40M_tact         = 40_000_000;
    // localparam CONST_5M_tact          = 23'b100_1100_0100_1011_0100_0000;
    localparam CONST_500k_tact        = 19'b111_1010_0001_0010_0000;
    localparam CONST_50k_tact         = 16'b1100_0011_0101_0000;

    wire                                    busy_tx;
    reg [2:0]                               state_reg;
    reg                                     start_tx;
    reg [4:0]                               cnt_byte;
    reg [3:0]                               angle_cur_sign_BCD;
    reg [11:0]                              angle_cur_int_BCD;
    reg [15:0]                              angle_cur_int_BCD_filt;
    reg [3:0]                               angle_cur_fixed_BCD;
    reg [BYTE - 1:0]                        angle_cur_fixed_ASCII;
    reg [(BYTE * 4) - 1:0]                  angle_cur_int_ASCII;

    reg [3:0]                               angle_dem_sign_BCD;
    reg [11:0]                              angle_dem_int_BCD;
    reg [15:0]                              angle_dem_int_BCD_filt;
    reg [3:0]                               angle_dem_fixed_BCD;
    reg [BYTE - 1:0]                        angle_dem_fixed_ASCII;
    reg [(BYTE * 4) - 1:0]                  angle_dem_int_ASCII;

    reg [(BYTE * 3) - 1:0]                  borehole_ASCII;
    reg [11:0]                              borehole_BCD;

    reg [15:0]                              time_BCD;
    reg [BYTE - 1:0]                        time_int_ASCII;
    reg [(BYTE * 3) - 1:0]                  time_fixed_ASCII;

    reg [DATA_LEN - 1:0]                    data_tx;
    reg [(NUMBER_SIMBOLS * DATA_LEN - 1):0] data;

    reg [28:0]                              cnt_step;
    reg [28:0]                              cnt_time;
    reg [3:0]                               cnt_s;
    reg [3:0]                               cnt_100_ms;
    reg [3:0]                               cnt_10_ms;
    reg [3:0]                               cnt_ms;
    reg [15:0]                              cnt_all_ms;
    reg                                     cnt_s_en;
    reg                                     cnt_100_ms_en;
    reg                                     cnt_10_ms_en;

    // reg [3:0]                               theta_angle_sign_BCD;
    // reg [11:0]                              theta_angle_BCD;
    // reg [15:0]                              theta_angle_BCD_filt;
    // reg [(BYTE * 4) - 1:0]                  theta_angle_ASCII;

    always @(posedge clk_i) begin
        if (nReset_i) begin
            if (enable_i && cnt_step < CONST_40M_tact) begin
                cnt_step <= cnt_step + 1'b1;
            end else if (!enable_i) begin
                cnt_step <= 0;
            end

            if (enable_i && cnt_step < CONST_40M_tact) begin
                if (cnt_time > CONST_40M_tact) begin
                    cnt_time <= 0;
                end else begin
                    cnt_time <= cnt_time + 1'b1;
                end

                if ((cnt_time > 0) && cnt_s_en) begin
                    if (cnt_s == 4'h9) begin
                        cnt_s <= 4'h0;
                    end else begin
                        cnt_s <= cnt_s + 1'b1;
                    end
                end

                if ((cnt_time > 0) && cnt_100_ms_en) begin
                    if (cnt_100_ms == 4'h9) begin
                        cnt_100_ms <= 4'h0;
                        cnt_s_en <= 1;
                    end else begin
                        cnt_100_ms <= cnt_100_ms + 1'b1;
                    end
                end else begin
                    cnt_s_en <= 0;
                end

                if ((cnt_time > 0) && cnt_10_ms_en) begin
                    if (cnt_10_ms == 4'h9) begin
                        cnt_10_ms <= 4'h0;
                        cnt_100_ms_en <= 1;
                    end else begin
                        cnt_10_ms <= cnt_10_ms + 1'b1;
                    end
                end else begin
                    cnt_100_ms_en <= 0;
                end

                if ((cnt_time > 0) && cnt_time[15:0] == cnt_all_ms) begin
                    if (cnt_ms == 4'h9) begin
                        cnt_ms <= 4'h0;
                        cnt_10_ms_en <= 1;
                    end else begin
                        cnt_ms <= cnt_ms + 1'b1;
                    end

                    if (cnt_all_ms == CONST_500k_tact) begin
                        cnt_all_ms <= CONST_50k_tact;
                    end else begin
                        cnt_all_ms <= cnt_all_ms + CONST_50k_tact;
                    end
                end else begin
                    cnt_10_ms_en <= 0;
                end

                case (state_reg)
                    0: begin
                        angle_cur_sign_BCD  <= (angle_current_i[ANGLE_MSB]) ? MINUS : EMPTY;
                        angle_cur_int_BCD   <= Bin2BCD(angle_current_i[ANGLE_FBITS +: ANGLE_RESOLUTION], 12);
                        angle_cur_fixed_BCD <= Binary2Fixed(angle_current_i[ANGLE_FBITS - 1 -: 4]);

                        angle_dem_sign_BCD  <= (angle_demanded_i[ANGLE_MSB]) ? MINUS : EMPTY;
                        angle_dem_int_BCD   <= Bin2BCD(angle_demanded_i[ANGLE_FBITS +: ANGLE_RESOLUTION], 12);
                        angle_dem_fixed_BCD <= Binary2Fixed(angle_demanded_i[ANGLE_FBITS - 1 -: 4]);

                        time_BCD        <= { cnt_s, cnt_100_ms, cnt_10_ms, cnt_ms };
                        borehole_BCD    <= Bin2BCD(borehole_i, 12);

                        // theta_angle_sign_BCD <= (theta_angle_i[9]) ? MINUS : EMPTY;
                        // theta_angle_BCD      <= Bin2BCD(theta_angle_i[8:0], 12);
                        
                        state_reg       <= state_reg + 1'b1;
                    end
                    1: begin
                        angle_cur_int_BCD_filt <= DeleteNullBCD({ angle_cur_sign_BCD, angle_cur_int_BCD }, 16);
                        angle_dem_int_BCD_filt <= DeleteNullBCD({ angle_dem_sign_BCD, angle_dem_int_BCD }, 16);

                        // theta_angle_BCD_filt <= { theta_angle_sign_BCD, theta_angle_BCD };// DeleteNullBCD({ theta_angle_sign_BCD, theta_angle_BCD }, 16);
                        state_reg <= state_reg + 1'b1;
                    end
                    2: begin
                        angle_cur_fixed_ASCII <= BCD2ASCII(angle_cur_fixed_BCD);
                        angle_dem_fixed_ASCII <= BCD2ASCII(angle_dem_fixed_BCD);
                        for (int i = 0; i < 4; i += 1) begin
                            angle_cur_int_ASCII[BYTE * i +: DATA_LEN] <= BCD2ASCII(angle_cur_int_BCD_filt[4 * i +: 4]);
                            angle_dem_int_ASCII[BYTE * i +: DATA_LEN] <= BCD2ASCII(angle_dem_int_BCD_filt[4 * i +: 4]);

                            // theta_angle_ASCII[BYTE * i +: DATA_LEN] <= BCD2ASCII(theta_angle_BCD_filt[4 * i +: 4]);
                        end

                        time_int_ASCII <= BCD2ASCII(time_BCD[15:12]);
                        for (int j = 0; j < 3; j += 1) begin
                            time_fixed_ASCII[BYTE * j +: DATA_LEN] <= BCD2ASCII(time_BCD[4 * j +: 4]);
                            borehole_ASCII[BYTE * j +: DATA_LEN]   <= BCD2ASCII(borehole_BCD[4 * j +: 4]);
                        end

                        state_reg <= state_reg + 1'b1;
                    end
                    3: begin
                        data <= {
                            angle_cur_int_ASCII, POINT_ASCII, angle_cur_fixed_ASCII, // угол текущий
                            COMMA_ASCII,                                             // запятая
                            time_int_ASCII, POINT_ASCII, time_fixed_ASCII,           // время
                            COMMA_ASCII,                                        
                            borehole_ASCII,                                          // скважность
                            COMMA_ASCII,
                            angle_dem_int_ASCII, POINT_ASCII, angle_dem_fixed_ASCII, // угол требуемый,
                            // COMMA_ASCII,
                            // theta_angle_ASCII,                                       // ошибка
                            CARRIAGE_RETURN_ASCII, LINE_FEED_ASCII                   // новая строка и перевод каретки
                        };
                        start_tx  <= 1'b1;
                        state_reg <= state_reg + 1'b1;
                    end
                    4: begin
                        if (!busy_tx && cnt_byte > 3'h0) begin
                            data_tx <= data[(cnt_byte * DATA_LEN - 1) -: DATA_LEN];
                            cnt_byte <= cnt_byte - 1'b1;
                        end else if (cnt_byte == 3'h0) begin
                            cnt_byte  <= 5'h19; // 5'h12 for 18 (time, cur, borehole) // 5'hE for 14 (time, cur)
                            state_reg <= 0;
                            start_tx  <= 1'b0;
                        end
                    end
                    default: begin
                        state_reg <= 0;
                    end
                endcase
            end else begin
                start_tx      <= 0;
                time_BCD      <= 0;
                cnt_time      <= 0;
                cnt_s         <= 0;
                cnt_100_ms    <= 0;
                cnt_10_ms     <= 0;
                cnt_ms        <= 0;
                cnt_100_ms_en <= 0;
                cnt_10_ms_en  <= 0;
                cnt_s_en      <= 0;
                cnt_all_ms    <= CONST_50k_tact;
            end
        end else begin
            state_reg              <= 0;
            angle_cur_sign_BCD     <= 0;
            angle_cur_int_BCD      <= 0;
            angle_cur_int_BCD_filt <= 0;
            angle_cur_fixed_BCD    <= 0;
            angle_cur_fixed_ASCII  <= 0;
            angle_cur_int_ASCII    <= 0;
            time_BCD               <= 0;
            time_int_ASCII         <= 0;
            time_fixed_ASCII       <= 0;
            data                   <= 0;
            data_tx                <= 0;
            start_tx               <= 0;
            cnt_byte               <= 5'h19;
            cnt_step               <= 0;
            cnt_time               <= 0;
            cnt_s                  <= 0;
            cnt_100_ms             <= 0;
            cnt_10_ms              <= 0;
            cnt_ms                 <= 0;
            cnt_100_ms_en          <= 0;
            cnt_10_ms_en           <= 0;
            cnt_s_en               <= 0;
            cnt_all_ms             <= CONST_50k_tact;
            // theta_angle_sign_BCD <= 0;
            // theta_angle_BCD <= 0;
            // theta_angle_BCD_filt <= 0;
            // theta_angle_ASCII <= 0;
        end
    end

    uart_tx #(
        .SPEED    (SPEED),
        .DATA_LEN (DATA_LEN)
    ) uart_tx_inst (
        .nReset_i (nReset_i),
        .clk_i    (clk_i),
        .start_i  (start_tx),
        .data_i   (data_tx),

        .Tx_o     (Tx_o),
        .busy_o   (busy_tx)
    );
endmodule