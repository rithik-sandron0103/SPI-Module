module producer(input clk,
                input arst_n,

                // Master interface
                input done,
                output reg start,
                output reg [7:0] tx_data);

        reg done_d;

        always @(posedge clk or negedge arst_n) begin
            if (!arst_n) begin
                start <= 0;
                tx_data <= 0;
                done_d <= 0;
            end
            else begin
                done_d <= done;

                if (done && !done_d) begin
                    start <= 1;
                    tx_data <= tx_data+1;
                end
                else start <= 0;
            end
        end
endmodule