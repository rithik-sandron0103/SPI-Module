module Master # (
    parameter CLK_DIV = 4,      // Clock division factor
    parameter CPOL = 0,         // Clock Polarity
    parameter CPHA = 0          // Clock Phase
)           (input clk,                //System clock
             input arst_n,             // Asynchronous active-low reset

             // Producer Interface
             input [7:0] tx_data,      // Data to be transmitted to the slave
             input start,              // Start signal to initiate SPI transaction
             output reg ready,         // High when the master is ready for a new transaction
             output reg [7:0] rx_data, // Data received from the slave

             // SPI interface
             input MISO,       // Master In Slave Out
             output reg nCS,   // Chip Select (Active low)
             output reg SCLK,  // Serial Clock
             output reg MOSI   // Master Out Slave In
             );

    // Local parameter calculation
    localparam CNT_WIDTH = ($clog2(CLK_DIV) > 0) ? $clog2(CLK_DIV) : 1;

    reg [CNT_WIDTH-1:0] clk_cnt;    // Prescaler counter for generation of SCLK ticks

    wire spi_tick; // Pulses at twice the SCLK frequency

    // Clock divider logic
    assign spi_tick = (clk_cnt == (CLK_DIV - 1));

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            clk_cnt <= {CNT_WIDTH{1'b0}};
        end
        else if (state == TRANSFER) begin
            if (spi_tick) begin
                clk_cnt <= {CNT_WIDTH{1'b0}};
            end
            else clk_cnt <= clk_cnt+1;
        end
        else clk_cnt <= {CNT_WIDTH{1'b0}};
    end

    reg [1:0] state, nextstate;

    // FSM state encoding
    parameter IDLE = 2'd0,
              SETUP = 2'd1,
              TRANSFER = 2'd2,
              DONE = 2'd3;

    // State machine (Sequential Update)
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            state <= IDLE;
        end
        else state <= nextstate;
    end

    reg [3:0] bit_cnt; 

    // Next state logic (Combinational logic)
    always @(*) begin
        case(state)
            IDLE: begin
                nextstate = start ? SETUP : IDLE;
            end
            SETUP: begin
                nextstate = TRANSFER;
            end
            TRANSFER: begin
                nextstate = (spi_tick && bit_cnt == 4'd8) ? DONE : TRANSFER;
            end
            DONE: nextstate = IDLE;
            default: nextstate = IDLE;
        endcase
    end

    // Shift registers
    reg [7:0] tx_shift;
    reg [7:0] rx_shift;

    // Output Control & Datapath Logic
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            SCLK <= CPOL;       // CPOL = 0 (by default)
            MOSI <= 1'b0;       
            nCS <= 1'b1;        // Deselected (active-low)
            ready <= 1'b1;
            tx_shift <= 8'h00;
            rx_shift <= 8'h00;
            rx_data <= 8'h00;
            bit_cnt <= 4'b0;
        end
        else begin
            case(state)
                IDLE: begin
                    SCLK <= CPOL;       // Serial clock is 0 when idle (default)
                    ready <= 1'b1;      
                    nCS <= 1'b1;
                    MOSI <= 1'b0;
                    bit_cnt <= 4'b0;
                    if (start) begin
                        bit_cnt <= 4'b0;
                        ready <= 1'b0;
                        nCS <= 1'b0;
                        tx_shift <= tx_data;   // Receives payload
                        rx_shift <= 8'h00;

                        // CPHA = 0: Drive first bit immediately upon CS assertion
                        if (CPHA == 0) begin
                            MOSI <= tx_data[7];
                        end
                    end
                end

                SETUP: begin
                    if (CPHA == 1) MOSI <= tx_shift[7];
                    tx_shift <= {tx_shift[6:0], 1'b0};
                end

                TRANSFER: begin
                    if (spi_tick) begin
                        SCLK <= ~SCLK;  // Toggle SCLK on every tick

                        if (CPHA == 0) begin
                            // Mode 0 & 1:
                            // Sample on leading edge, shift on trailing edge
                            if (SCLK == CPOL) begin     // Leading edge (sample MISO)
                                rx_shift <= {rx_shift[6:0] , MISO};
                                bit_cnt <= bit_cnt+1;
                            end
                            else begin      // Trailing edge (shift MOSI)
                                if (bit_cnt < 4'd8) begin
                                    MOSI <= tx_shift[7];
                                    tx_shift <= {tx_shift[6:0], 1'b0};
                                end
                            end

                        end

                        else begin
                            // Mode 2 & 3:
                            // Shift on leading edge, sample on trailing edge
                            if (SCLK == CPOL) begin     // Leading edge (shift MOSI)
                                if (bit_cnt < 4'd8) begin
                                    MOSI <= tx_shift[7];
                                    tx_shift <= {tx_shift[6:0], 1'b0};
                                end
                            end
                            else begin      // Trailing edge (sample MISO)
                                rx_shift <= {rx_shift[6:0] , MISO};
                                bit_cnt <= bit_cnt+1;
                            end

                        end
                    end
                end

                DONE: begin
                    SCLK <= CPOL;
                    ready <= 1'b1;
                    nCS <= 1'b1;               // Release chip select
                    rx_data <= rx_shift;       // Capture received payload
                end

                default: ready <= 1'b1;
            endcase
        end
    end
endmodule