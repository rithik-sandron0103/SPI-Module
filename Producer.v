module producer(input clk,                  // System clock
                input arst_n,               // Asynchronous active-low reset

                // Master interface
                input done,                 // Transaction completion signal from master
                output reg start,           // Pulse signal to initiate next SPI transaction
                output reg [7:0] tx_data    // Parallel data payload to transmit
                );

        reg done_d;     // Delayed completion signal used for edge detection
        reg first;      // Flag to trigger the initial transaction on startup

        always @(posedge clk or negedge arst_n) begin
            if (!arst_n) begin
                start <= 1'b0;
                tx_data <= 8'b0;
                done_d <= 1'b0;
                first <= 1'b1;
            end
            else begin
                done_d <= done;     // Registering done signal to detect rising edge

                if (first) begin
                    start <= 1'b1;  // Automatically initiate first transaction on startup
                    first <= 1'b0;
                end
                else if (done && !done_d) begin
                    start <= 1;             // Trigger subsequent transaction on rising edge of done
                    tx_data <= tx_data+1;   // Increment outgoing payload data value
                end
                else start <= 0;
            end
        end
endmodule