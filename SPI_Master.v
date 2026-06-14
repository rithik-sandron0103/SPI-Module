module Master(input clk,        //System clock
              input arst_n,

              // Producer Interface
              input [7:0] tx_data,
              input start,
              output reg ready,
              output reg [7:0] rx_data,

              //SPI interface
              input MISO,
              output reg nCS,
              output reg SCLK,
              output reg MOSI);
    
    parameter CLK_DIV = 4;
    reg [7:0] clk_cnt;
    wire spi_tick; // Pulse at twice the SCLK frequency

    // Clock divider
    assign spi_tick = (clk_cnt == (CLK_DIV - 1));
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) clk_cnt <= 0;
        else if (state == TRANSFER) begin
            if (spi_tick) clk_cnt <= 0;
            else clk_cnt <= clk_cnt+1;
        end
        else clk_cnt <= 0;
    end

    reg [1:0] state, nextstate;

    // State machine
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) state <= IDLE;
        else state <= nextstate;
    end

    parameter IDLE = 0, TRANSFER = 1, DONE = 2;

    // Next state logic
    always @(*) begin
        case(state)
            IDLE: nextstate = start ? TRANSFER : IDLE;
            TRANSFER: nextstate = (spi_tick && edge_cnt == 15) ? DONE : TRANSFER;
            DONE: nextstate = IDLE;
        endcase
    end

    reg [3:0] edge_cnt;

    // Edge counting
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) edge_cnt <= 0;
        else begin
            if (spi_tick && state == TRANSFER) edge_cnt <= edge_cnt+1;
            else if (state == IDLE) edge_cnt <= 0;
        end
    end

    reg [7:0] shift_reg;

    // Output control
    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            SCLK <= 1'b0; // CPOL = 0
            MOSI <= 1'b0;
            nCS <= 1'b1;  // Active low
            ready <= 1'b1;
            shift_reg <= 8'h00;
        end
        else begin
            case(state)
                IDLE: begin
                    ready <= 1'b1;
                    SCLK <= 1'b0;
                    nCS <= 1'b1;
                    if (start) begin // Rising edge
                        ready <= 1'b0;
                        nCS <= 1'b0;
                        shift_reg <= tx_data;
                        MOSI <= tx_data[7];
                    end
                end
                TRANSFER: begin
                    if (spi_tick) begin
                        SCLK <= ~SCLK;
                        if (SCLK == 1'b1) begin // Falling edge
                            if (edge_cnt < 4'd14) begin
                                MOSI <= shift_reg[6];
                                shift_reg <= {shift_reg[6:0],MISO};
                            end
                            else shift_reg <= {shift_reg[6:0],MISO};
                        end
                    end
                end
                DONE: begin
                    ready <= 1'b1;
                    SCLK <= 1'b0;
                    nCS <= 1'b0;
                    rx_data <= shift_reg;
                end
            endcase
        end
    end
endmodule