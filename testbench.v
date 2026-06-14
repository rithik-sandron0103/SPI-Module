`timescale 1ns/1ps

module SPI_tb;

    reg clk = 0;
    reg arst_n = 0;

    // Wires connecting Producer & Master
    wire start;
    wire [7:0] tx_data;
    wire ready;

    // SPI wires
    wire SCLK;
    wire MOSI;
    wire MISO;
    wire nCS;

    // Master RX
    wire [7:0] master_rx;

    // Slave side
    wire [7:0] slave_rx;
    wire valid;

    // Responder output 
    wire [7:0] responder_shift;

    // Clock generation
    always #5 clk = ~clk;


    // Producer
    producer prod (
        .clk(clk),
        .arst_n(arst_n),
        .done(ready),
        .start(start),
        .tx_data(tx_data)
    );

    // SPI Master
    Master master (
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

    // SPI Slave
    Slave slave (
        .clk(clk),
        .arst_n(arst_n),
        .tx_data(8'hA5),   // slave transmit data
        .rx_data(slave_rx),
        .valid(valid),

        .SCLK(SCLK),
        .nCS(nCS),
        .MOSI(MOSI),
        .MISO(MISO)
    );

    // Responder
    responder resp (
        .clk(clk),
        .arst_n(arst_n),
        .SCLK(SCLK),
        .nCS(nCS),
        .shift_reg(responder_shift)
    );


    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, SPI_tb);

        // Reset
        arst_n = 0;
        #50;
        arst_n = 1;

        // Run simulation
        #200000;

        $finish;
    end


    always @(posedge clk) begin
        if (valid) begin
            $display("T=%0t | Slave Received = %h | Master Sent = %h | SCLK = %b | MISO = %b | RX = %b",
                     $time, slave_rx, tx_data, SCLK, MISO, slave_rx);
        end
    end

endmodule