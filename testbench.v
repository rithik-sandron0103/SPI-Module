`timescale 1ns/1ps

module SPI_tb;
    // Parameters
    parameter CLK_DIV = 4;
    parameter CPOL = 0;
    parameter CPHA = 0;

    reg clk;        // System clock
    reg arst_n;     // Asynchronous active-low reset

    // Wires connecting Producer & Master
    wire start;
    wire [7:0] tx_data;
    wire ready;

    // SPI wires
    wire SCLK;
    wire MOSI;
    wire MISO;
    wire nCS;

    // Master receiver interface wire
    wire [7:0] master_rx;

    // Slave receiver interface wires
    wire [7:0] slave_rx;
    wire valid;

    // Responder shift register output feeding the slave transmission payload
    wire [7:0] responder_shift;

    // System clock generation
    initial begin
        clk = 0;
    end
    always #5 clk = ~clk;

    // Producer Instantiation
    producer prod (
        .clk(clk),
        .arst_n(arst_n),
        .done(ready),
        .start(start),
        .tx_data(tx_data)
    );

    // SPI Master controller Instantiation
    Master #(
        .CLK_DIV(CLK_DIV),
        .CPOL(CPOL),
        .CPHA(CPHA)
    )  master(
        .clk(clk),
        .arst_n(arst_n),
        .tx_data(tx_data),
        .start(start),
        .ready(ready),
        .rx_data(master_rx),

        .MISO(MISO),
        .nCS(nCS),
        .SCLK(SCLK),
        .MOSI(MOSI)
    );

    // SPI Slave peripheral Instantiation
    Slave #(
        .CPOL(CPOL),
        .CPHA(CPHA)
    )  slave(
        .clk(clk),
        .arst_n(arst_n),
        .tx_data(responder_shift),
        .rx_data(slave_rx),
        .rx_valid(valid),

        .SCLK(SCLK),
        .nCS(nCS),
        .MOSI(MOSI),
        .MISO(MISO)
    );

    // Responder Instantiation
    responder #(
        .CPOL(CPOL),
        .CPHA(CPHA)
    )  resp( 
        .clk(clk),
        .arst_n(arst_n),
        .SCLK(SCLK),
        .nCS(nCS),
        .shift_reg(responder_shift)
    );


    initial begin
        $dumpfile("spi.vcd");
        $dumpvars(0, SPI_tb);

        // Reset stimulus
        arst_n = 0;
        #50;
        arst_n = 1;

        // Run simulation
        #8000;

        $finish;
    end


    always @(posedge clk) begin
        if (!nCS) begin
            $strobe("T=%0t | nCS=%b SCLK=%b MOSI=%b MISO=%b | TX=%h RX=%h SHIFT=%h",
                    $time, nCS, SCLK, MOSI, MISO, tx_data, master_rx, responder_shift);
        end
    end

endmodule