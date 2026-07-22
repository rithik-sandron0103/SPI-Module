module responder #(
    parameter CPOL = 0,      // Clock Polarity
    parameter CPHA = 0       // Clock Phase
)               (input clk,                  // System clock
                 input arst_n,               // Asynchronous active-low reset
                 input SCLK,                 // Serial clock from master
                 input nCS,                  // Chip Select (active-low) from master    
                 output reg [7:0] shift_reg  // Output data register mirroring the active byte
                 );

    reg [2:0] SCLK_sync;    // Synchronizer registers for SCLK
    reg [2:0] nCS_sync;     // Synchronizer registers for nCS

    reg [7:0] data;         // Internal data payload register

    // Synchronization
    always @(posedge clk) begin
        SCLK_sync <= {SCLK_sync[1:0],SCLK};
        nCS_sync <= {nCS_sync[1:0],nCS};
    end

    // Edge detection wires for synchronized clock and chip select signals
    wire SCLK_rising = (SCLK_sync[2:1] == 2'b01);
    wire SCLK_falling = (SCLK_sync[2:1] == 2'b10);
    wire nCS_falling = (nCS_sync[2:1] == 2'b10);
    wire nCS_rising = (nCS_sync[2:1] == 2'b01);

    // Configurable leading and trailing edge definitions based on CPOL
    wire leading_edge = (CPOL == 0) ? SCLK_rising : SCLK_falling;
    wire trailing_edge = (CPOL == 0) ? SCLK_falling : SCLK_rising;

    // Sequential logic for data payload generation and shift register loading
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            data <= 8'h55;
            shift_reg <= 8'h55;
        end
        else begin

            // Transaction end
            if (nCS_rising) begin
                data <= data+1;
            end

            // Transaction start
            else if (nCS_falling) begin
                shift_reg <= data;
            end

        end
    end
endmodule