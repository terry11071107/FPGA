module pooling (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         valid_in,
    input  wire signed [15:0] data_in0,
    input  wire signed [15:0] data_in1,
    input  wire signed [15:0] data_in2,
    input  wire signed [15:0] data_in3,
    input  wire signed [15:0] data_in4,
    input  wire signed [15:0] data_in5,
    input  wire signed [15:0] data_in6,
    input  wire signed [15:0] data_in7,
    input  wire signed [15:0] data_in8,
    output reg  signed [15:0] max_out,
    output reg          valid_out
);
  reg signed [15:0] max_val;
  always @* begin
    max_val = data_in0;
    if (data_in1 > max_val) max_val = data_in1;
    if (data_in2 > max_val) max_val = data_in2;
    if (data_in3 > max_val) max_val = data_in3;
    if (data_in4 > max_val) max_val = data_in4;
    if (data_in5 > max_val) max_val = data_in5;
    if (data_in6 > max_val) max_val = data_in6;
    if (data_in7 > max_val) max_val = data_in7;
    if (data_in8 > max_val) max_val = data_in8;
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_out <= 0; valid_out <= 0;
    end else begin
      if (valid_in) begin
        max_out  <= max_val;
        valid_out <= 1;
      end else begin
        valid_out <= 0;
      end
    end
  end
endmodule