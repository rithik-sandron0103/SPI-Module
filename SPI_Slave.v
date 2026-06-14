module Slave(input clk,
             input arst_n,
             input [7:0] tx_data,
             output reg [7:0] rx_data,
             output reg valid,

             //SPI interface
             input SCLK,
             input nCS,
             input MOSI,
             output MISO);

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
            SCLK_sync <= {SCLK_sync[1:0],SCLK}; // 3 stage synchronizer
            nCS_sync <= {nCS_sync[0],nCS};      // 2 stage synchronizer
            MOSI_sync <= {MOSI_sync[0],MOSI};   // 2 stage synchronizer
        end
    end

    wire SCLK_rising = (SCLK_sync[2:1] == 2'b01);
    wire SCLK_falling = (SCLK_sync[2:1] == 2'b10);
    wire active = ~nCS_sync[1];

    reg [7:0] shift_reg;
    reg [3:0] bit_cnt;

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            shift_reg <= 8'h00;
            bit_cnt <= 4'b0;
            rx_data <= 8'h00;
            valid <= 0;
        end
        else begin
            valid <= 0;
            if(!active) begin
                shift_reg <= tx_data;
                bit_cnt <= 0;
            end
            else begin
                // Sampling
                if (SCLK_rising) begin
                    shift_reg <= {shift_reg[6:0],MOSI_sync[1]};
                    bit_cnt <= bit_cnt+1;
                    if (bit_cnt == 4'd7) begin
                        rx_data <= {shift_reg[6:0],MOSI_sync[1]};
                        bit_cnt <= 0;
                        valid <= 1;
                    end
                end
            end
        end
    end

    assign MISO = (active) ? shift_reg[7] : 1'bz;
endmodule