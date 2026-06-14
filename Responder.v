module responder(input clk,
                 input arst_n,
                 input SCLK,
                 input nCS,
                 output reg [7:0] shift_reg);

    reg [2:0] SCLK_sync;
    reg [2:0] nCS_sync;

    reg [7:0] data;

    always @(posedge clk) begin
        SCLK_sync <= {SCLK_sync[1:0],SCLK};
        nCS_sync <= {nCS_sync[1:0],nCS};
    end

    wire SCLK_rising = (SCLK_sync[2:1] == 2'b01);
    wire nCS_rising = (nCS_sync[2:1] == 2'b01);

    always @(posedge clk or negedge arst_n) begin
        if (!arst_n) begin
            data <= 8'h55;
            shift_reg <= 8'h55;
        end
        else begin
            if (nCS_rising) begin
                data <= data+1;
                shift_reg <= data;
            end
            else begin
                if (SCLK_rising) shift_reg <= {shift_reg[6:0], 1'b0};
            end
        end
    end
endmodule