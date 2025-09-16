module window_buffer_3x3_2d_with_padding (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         valid_in,
    input  wire signed [15:0] data_in,
    input  wire [7:0]   img_width,
    input  wire [7:0]   img_height,
    input  wire [1:0]   padding_mode, // 00: no padding, 01: zero padding

    output reg  signed [15:0] data_out0, data_out1, data_out2,
                              data_out3, data_out4, data_out5,
                              data_out6, data_out7, data_out8,
    output reg          valid_out
);
  parameter MAX_WIDTH = 256;

  reg signed [15:0] line0 [0:MAX_WIDTH-1];
  reg signed [15:0] line1 [0:MAX_WIDTH-1];
  reg signed [15:0] line2 [0:MAX_WIDTH-1];

  reg [7:0] input_col, input_row;
  reg [7:0] output_col, output_row;
  reg [17:0] total_inputs; // up to 256*256
  reg input_finished;

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      input_col <= 0; input_row <= 0;
      output_col <= 0; output_row <= 0;
      total_inputs <= 0; valid_out <= 0; input_finished <= 0;
      for (i=0;i<MAX_WIDTH;i=i+1) begin
        line0[i] <= 0; line1[i] <= 0; line2[i] <= 0;
      end
      {data_out0,data_out1,data_out2,
       data_out3,data_out4,data_out5,
       data_out6,data_out7,data_out8} <= 0;
    end else begin
      valid_out <= 0;

      // 收資料：每列起點先做 line shift
      if (valid_in) begin
        if (input_col == 0) begin
          for (i=0;i<MAX_WIDTH;i=i+1) begin
            line0[i] <= line1[i];
            line1[i] <= line2[i];
          end
        end
        line2[input_col] <= data_in;

        if (input_col == img_width - 1) begin
          input_col <= 0;
          input_row <= input_row + 1;
        end else begin
          input_col <= input_col + 1;
        end
        total_inputs <= total_inputs + 1;
      end else if (!input_finished && total_inputs == img_width * img_height) begin
        // 補最後一次 shift，讓 line0/1/2 對齊最後三行
        for (i=0;i<MAX_WIDTH;i=i+1) begin
          line0[i] <= line1[i];
          line1[i] <= line2[i];
        end
        input_finished <= 1;
      end

      // 產生輸出 window
      if (padding_mode == 2'b01) begin
        // zero padding：任何時刻都可輸出，超界處補 0
        if (output_row < img_height && output_col < img_width) begin
          // 上排
          if (output_row == 0) begin
            data_out0 <= 16'd0;
            data_out1 <= 16'd0;
            data_out2 <= 16'd0;
          end else begin
            data_out0 <= (output_col==0) ? 16'd0 : line0[output_col-1];
            data_out1 <= line0[output_col];
            data_out2 <= (output_col==img_width-1)?16'd0: line0[output_col+1];
          end
          // 中排
          data_out3 <= (output_col==0) ? 16'd0 : line1[output_col-1];
          data_out4 <= line1[output_col];
          data_out5 <= (output_col==img_width-1)?16'd0: line1[output_col+1];
          // 下排
          if (output_row == img_height-1) begin
            data_out6 <= 16'd0;
            data_out7 <= 16'd0;
            data_out8 <= 16'd0;
          end else begin
            data_out6 <= (output_col==0) ? 16'd0 : line2[output_col-1];
            data_out7 <= line2[output_col];
            data_out8 <= (output_col==img_width-1)?16'd0: line2[output_col+1];
          end

          valid_out <= 1;
          if (output_col == img_width-1) begin
            output_col <= 0; output_row <= output_row + 1;
          end else begin
            output_col <= output_col + 1;
          end
        end
      end else begin
        // no padding：只有在三行與三列都具備時才輸出
        if (!input_finished) begin
          if (input_row >= 2) begin
            if ( (output_row < (input_row - 1)) ||
                 (output_row == (input_row - 1) && (output_col + 2) < input_col) ) begin
              data_out0 <= line0[output_col    ];
              data_out1 <= line0[output_col + 1];
              data_out2 <= line0[output_col + 2];
              data_out3 <= line1[output_col    ];
              data_out4 <= line1[output_col + 1];
              data_out5 <= line1[output_col + 2];
              data_out6 <= line2[output_col    ];
              data_out7 <= line2[output_col + 1];
              data_out8 <= line2[output_col + 2];
              valid_out <= 1;
              if (output_col == img_width-3) begin
                output_col <= 0; output_row <= output_row + 1;
              end else begin
                output_col <= output_col + 1;
              end
            end
          end
        end else begin
          if (output_row < (img_height-2) && output_col < (img_width-2)) begin
            data_out0 <= line0[output_col    ];
            data_out1 <= line0[output_col + 1];
            data_out2 <= line0[output_col + 2];
            data_out3 <= line1[output_col    ];
            data_out4 <= line1[output_col + 1];
            data_out5 <= line1[output_col + 2];
            data_out6 <= line2[output_col    ];
            data_out7 <= line2[output_col + 1];
            data_out8 <= line2[output_col + 2];
            valid_out <= 1;
            if (output_col == img_width-3) begin
              output_col <= 0; output_row <= output_row + 1;
            end else begin
              output_col <= output_col + 1;
            end
          end
        end
      end
    end
  end
endmodule