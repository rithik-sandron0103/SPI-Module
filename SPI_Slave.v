module Slave #(
    parameter CPOL = 0,     // Clock Polarity
    parameter CPHA = 0      // Clock Phase
)           (input clk,                 // System clock
             input arst_n,              // Asynchronous active-low reset

             // Responder Interface
             input [7:0] tx_data,       // Data to be transmitted back to the master
             output reg [7:0] rx_data,  // Data received from the master
             output reg rx_valid,       // Pulsed high for one cycle when rx_data is ready

             // SPI interface
             input SCLK,                // Serial clock
             input nCS,                 // Chip Select (Active-low)
             input MOSI,                // Master Out Slave In
             output reg MISO            // Master In Slave Out
             );

    // Asynchronous signal synchronization registers to prevent metastability
    reg [2:0] SCLK_sync;
    reg [1:0] nCS_sync;
    reg [1:0] MOSI_sync;

    // Synchronization
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            SCLK_sync <= 3'b000;
            nCS_sync <= 2'b11;
            MOSI_sync <= 2'b00;
        end
        else begin
            SCLK_sync <= {SCLK_sync[1:0] , SCLK}; // 3 stage SCLK synchronizer
            nCS_sync <= {nCS_sync[0] , nCS};      // 2 stage nCS synchronizer
            MOSI_sync <= {MOSI_sync[0] , MOSI};   // 2 stage MOSI synchronizer
        end
    end

    // Edge and level detection wires derived from synchronizers
    wire SCLK_rising = (SCLK_sync[2:1] == 2'b01);
    wire SCLK_falling = (SCLK_sync[2:1] == 2'b10);
    wire nCS_falling = (nCS_sync == 2'b10);
    wire nCS_rising = (nCS_sync == 2'b01);
    wire active = (nCS_sync[1] == 1'b0);

    reg [7:0] tx_shift;
    reg [7:0] rx_shift;
    reg [3:0] bit_cnt;

    // Configurable clock edge mapping based on CPOL configuration
    wire leading_edge = (CPOL == 0) ? SCLK_rising : SCLK_falling;
    wire trailing_edge = (CPOL == 0) ? SCLK_falling : SCLK_rising;

    // Sequential block handling serial-to-parallel and parallel-to-serial logic
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            tx_shift <= 8'h00;
            rx_shift <= 8'h00;
            bit_cnt <= 4'b0;
            rx_data <= 8'h00;
            rx_valid <= 1'b0;
            MISO <= 1'b0;
        end
        else begin
            rx_valid <= 1'b0;       // Default pulse signal to low

            // Transaction start
            if (nCS_falling) begin
                tx_shift <= {tx_data[6:0] , 1'b0};  // Pre-shift transmit data register
                rx_shift <= 8'h00;
                bit_cnt <= 4'b0;
                if (CPHA == 0) begin
                    MISO <= tx_data[7];             // Drive MSB immediately for CPHA = 0
                end
            end

            // Transaction complete
            else if (nCS_rising) begin
                rx_data <= rx_shift;
                rx_valid <= 1'b1;       // Indicate valid data ready
                bit_cnt <= 4'b0;
            end

            // Active transaction window
            else if (active) begin

                if (CPHA == 0) begin
                    // Mode 0 & 1:
                    // Sample on leading edge, shift on trailing edge
                    if (leading_edge) begin
                        rx_shift <= {rx_shift[6:0] , MOSI_sync[1]};
                        bit_cnt <= bit_cnt+1;
                    end
                    else if (trailing_edge) begin
                        if (bit_cnt < 4'd8) begin
                            MISO <= tx_shift[7];
                            tx_shift <= {tx_shift[6:0] , 1'b0};
                        end
                    end
                end

                else begin
                    // Mode 2 & 3:
                    // Shift on leading edge, sample on trailing edge
                    if (leading_edge) begin
                        if (bit_cnt < 4'd8) begin
                            MISO <= tx_shift[7];
                            tx_shift <= {tx_shift[6:0] , 1'b0};
                        end
                    end
                    else if (trailing_edge) begin
                        rx_shift <= {rx_shift[6:0] , MOSI_sync[1]};
                        bit_cnt <= bit_cnt+1;
                    end
                end

            end
        end
    end
endmodule