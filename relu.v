module relu #(parameter WIDTH_IN = 16, WIDTH_OUT = 8) (
    input  wire                      clk,
    input  wire                      rst_n,
    input  wire                      valid_in,
    input  wire signed [WIDTH_IN-1:0] data_in,
    output reg  [WIDTH_OUT-1:0]      data_out,
    output reg                       valid_out
);
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out <= 0; valid_out <= 0;
    end else begin
      if (valid_in) begin
        if (data_in > 0) begin
          if (data_in > 127) data_out <= 8'd127;
          else               data_out <= data_in[7:0];
        end else begin
          data_out <= 8'd0;
        end
        valid_out <= 1;
      end else begin
        valid_out <= 0;
      end
    end
  end
endmodule