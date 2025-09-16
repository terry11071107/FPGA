// pooling_buffer_3x3_stream.v
module pooling_buffer_3x3_stream #(
    parameter MAX_WIDTH = 256
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        valid_in,
    input  wire [7:0]  data_in,       // ReLU 後 8-bit

    input  wire [7:0]  img_width,
    input  wire [7:0]  img_height,

    output reg         valid_out,
    output reg signed [15:0] d0, d1, d2,
                             d3, d4, d5,
                             d6, d7, d8
);
    reg [7:0] line0 [0:MAX_WIDTH-1];
    reg [7:0] line1 [0:MAX_WIDTH-1];
    reg [7:0] line2 [0:MAX_WIDTH-1];

    reg [7:0] in_col, in_row;
    reg [7:0] out_col, out_row;
    reg       input_finished;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0;i<MAX_WIDTH;i=i+1) begin
                line0[i]<=0; line1[i]<=0; line2[i]<=0;
            end
            in_col<=0; in_row<=0; out_col<=0; out_row<=0;
            input_finished<=0; valid_out<=0;
            {d0,d1,d2,d3,d4,d5,d6,d7,d8} <= 0;
        end else begin
            valid_out <= 0;

            if (valid_in) begin
                if (in_col == 0) begin
                    for (i=0;i<MAX_WIDTH;i=i+1) begin
                        line0[i] <= line1[i];
                        line1[i] <= line2[i];
                    end
                end
                line2[in_col] <= data_in;

                if (in_col == img_width-1) begin
                    in_col <= 0;
                    if (in_row == img_height-1) input_finished <= 1;
                    else in_row <= in_row + 1;
                end else begin
                    in_col <= in_col + 1;
                end
            end

            if (!input_finished) begin
                if (in_row >= 2) begin
                    if ( (out_row < (in_row-1)) ||
                         (out_row == (in_row-1) && (out_col+2) < in_col) ) begin
                        d0 <= {8'd0, line0[out_col    ]};
                        d1 <= {8'd0, line0[out_col + 1]};
                        d2 <= {8'd0, line0[out_col + 2]};
                        d3 <= {8'd0, line1[out_col    ]};
                        d4 <= {8'd0, line1[out_col + 1]};
                        d5 <= {8'd0, line1[out_col + 2]};
                        d6 <= {8'd0, line2[out_col    ]};
                        d7 <= {8'd0, line2[out_col + 1]};
                        d8 <= {8'd0, line2[out_col + 2]};
                        valid_out <= 1;

                        if (out_col == img_width-3) begin
                            out_col <= 0; out_row <= out_row + 1;
                        end else begin
                            out_col <= out_col + 1;
                        end
                    end
                end
            end else begin
                if (out_row < (img_height-2) && out_col < (img_width-2)) begin
                    d0 <= {8'd0, line0[out_col    ]};
                    d1 <= {8'd0, line0[out_col + 1]};
                    d2 <= {8'd0, line0[out_col + 2]};
                    d3 <= {8'd0, line1[out_col    ]};
                    d4 <= {8'd0, line1[out_col + 1]};
                    d5 <= {8'd0, line1[out_col + 2]};
                    d6 <= {8'd0, line2[out_col    ]};
                    d7 <= {8'd0, line2[out_col + 1]};
                    d8 <= {8'd0, line2[out_col + 2]};
                    valid_out <= 1;

                    if (out_col == img_width-3) begin
                        out_col <= 0; out_row <= out_row + 1;
                    end else begin
                        out_col <= out_col + 1;
                    end
                end
            end
        end
    end
endmodule
