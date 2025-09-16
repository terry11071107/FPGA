module top #(
    parameter DATA_WIDTH   = 16,
    parameter SCALE_SHIFT  = 4    // conv 36-bit 算術右移到 16-bit 再丟 ReLU
)(
    input  wire                         clk,
    input  wire                         rst_n,

    // 影像串流輸入
    input  wire                         valid_in,
    input  wire signed [DATA_WIDTH-1:0] pixel_in,
    input  wire [7:0]                   img_width,
    input  wire [7:0]                   img_height,

    // debug outputs（可接 testbench）
    output wire                         valid_conv0,
    output wire signed [2*DATA_WIDTH+4:0] conv_out0,
    output wire                         valid_relu0,
    output wire [7:0]                   relu_out0,
    output wire                         valid_pool0,
    output wire signed [15:0]           pool_out0,

    output wire                         valid_conv1,
    output wire signed [2*DATA_WIDTH+4:0] conv_out1,
    output wire                         valid_relu1,
    output wire [7:0]                   relu_out1,
    output wire                         valid_pool1,
    output wire signed [15:0]           pool_out1
);
    // ---------------- Window Buffer（共用一顆，conv 用 zero padding） ----------------
    wire signed [DATA_WIDTH-1:0] wb0,wb1,wb2,wb3,wb4,wb5,wb6,wb7,wb8;
    wire wb_valid;

    window_buffer_3x3_2d_with_padding u_wb (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in),
        .data_in(pixel_in),
        .img_width(img_width),
        .img_height(img_height),
        .padding_mode(2'b01), // conv 用 zero padding
        .data_out0(wb0), .data_out1(wb1), .data_out2(wb2),
        .data_out3(wb3), .data_out4(wb4), .data_out5(wb5),
        .data_out6(wb6), .data_out7(wb7), .data_out8(wb8),
        .valid_out(wb_valid)
    );

    // ---------------- 兩套 feeder（各自送 window + 權重 → conv） ----------------
    // Kernel0 = [[1,0,-1],[1,0,-1],[1,0,-1]]
    wire signed [DATA_WIDTH-1:0] k0 [0:8];
    assign k0[0]=16'sd1; assign k0[1]=16'sd0; assign k0[2]=-16'sd1;
    assign k0[3]=16'sd1; assign k0[4]=16'sd0; assign k0[5]=-16'sd1;
    assign k0[6]=16'sd1; assign k0[7]=16'sd0; assign k0[8]=-16'sd1;

    // Kernel1 = [[1,1,1],[0,0,0],[-1,-1,-1]]
    wire signed [DATA_WIDTH-1:0] k1 [0:8];
    assign k1[0]=16'sd1; assign k1[1]=16'sd1; assign k1[2]=16'sd1;
    assign k1[3]=16'sd0; assign k1[4]=16'sd0; assign k1[5]=16'sd0;
    assign k1[6]=-16'sd1; assign k1[7]=-16'sd1; assign k1[8]=-16'sd1;

    // feeder 0
    reg [5:0] step0; reg running0;
    reg signed [DATA_WIDTH-1:0] win0 [0:8];
    reg        conv_vi0; reg [4:0] conv_idx0; reg signed [DATA_WIDTH-1:0] conv_di0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step0<=0; running0<=0; conv_vi0<=0; conv_idx0<=0; conv_di0<=0;
        end else begin
            conv_vi0 <= 0;
            if (wb_valid && !running0) begin
                {win0[0],win0[1],win0[2],win0[3],win0[4],win0[5],win0[6],win0[7],win0[8]} <=
                {wb0,wb1,wb2,wb3,wb4,wb5,wb6,wb7,wb8};
                running0 <= 1; step0 <= 0;
            end else if (running0) begin
                if (step0 < 9) begin
                    conv_vi0 <= 1; conv_idx0 <= step0[4:0]; conv_di0 <= win0[step0];
                    step0 <= step0 + 1;
                end else if (step0 < 18) begin
                    conv_vi0 <= 1; conv_idx0 <= step0[4:0];
                    conv_di0 <= k0[step0-9];
                    step0 <= step0 + 1;
                end else if (step0 == 18) begin
                    conv_vi0 <= 1; conv_idx0 <= 9; conv_di0 <= 0; // trigger
                    step0 <= 19;
                end else begin
                    running0 <= 0;
                end
            end
        end
    end

    // feeder 1
    reg [5:0] step1; reg running1;
    reg signed [DATA_WIDTH-1:0] win1 [0:8];
    reg        conv_vi1; reg [4:0] conv_idx1; reg signed [DATA_WIDTH-1:0] conv_di1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            step1<=0; running1<=0; conv_vi1<=0; conv_idx1<=0; conv_di1<=0;
        end else begin
            conv_vi1 <= 0;
            if (wb_valid && !running1) begin
                {win1[0],win1[1],win1[2],win1[3],win1[4],win1[5],win1[6],win1[7],win1[8]} <=
                {wb0,wb1,wb2,wb3,wb4,wb5,wb6,wb7,wb8};
                running1 <= 1; step1 <= 0;
            end else if (running1) begin
                if (step1 < 9) begin
                    conv_vi1 <= 1; conv_idx1 <= step1[4:0]; conv_di1 <= win1[step1];
                    step1 <= step1 + 1;
                end else if (step1 < 18) begin
                    conv_vi1 <= 1; conv_idx1 <= step1[4:0];
                    conv_di1 <= k1[step1-9];
                    step1 <= step1 + 1;
                end else if (step1 == 18) begin
                    conv_vi1 <= 1; conv_idx1 <= 9; conv_di1 <= 0; // trigger
                    step1 <= 19;
                end else begin
                    running1 <= 0;
                end
            end
        end
    end

    // ---------------- Convolution → 縮位 → ReLU ----------------
    wire signed [2*DATA_WIDTH+4:0] conv_res0, conv_res1;

    conv_pipelined #(.DATA_WIDTH(DATA_WIDTH)) u_conv0 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(conv_vi0), .index(conv_idx0), .data_in(conv_di0),
        .result(conv_res0), .valid_out(valid_conv0)
    );
    conv_pipelined #(.DATA_WIDTH(DATA_WIDTH)) u_conv1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(conv_vi1), .index(conv_idx1), .data_in(conv_di1),
        .result(conv_res1), .valid_out(valid_conv1)
    );

    // 將 36-bit 轉 16-bit（算術右移對齊，方便 ReLU）
    wire signed [15:0] conv_res0_s16 = conv_res0 >>> SCALE_SHIFT;
    wire signed [15:0] conv_res1_s16 = conv_res1 >>> SCALE_SHIFT;

    relu #(.WIDTH_IN(16), .WIDTH_OUT(8)) u_relu0 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_conv0),
        .data_in(conv_res0_s16),
        .data_out(relu_out0),
        .valid_out(valid_relu0)
    );
    relu #(.WIDTH_IN(16), .WIDTH_OUT(8)) u_relu1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_conv1),
        .data_in(conv_res1_s16),
        .data_out(relu_out1),
        .valid_out(valid_relu1)
    );

    // ---------------- ReLU 串流 → 3×3 → pooling ----------------
    wire pb0_valid;
    wire signed [15:0] pb0_d0,pb0_d1,pb0_d2,pb0_d3,pb0_d4,pb0_d5,pb0_d6,pb0_d7,pb0_d8;

    pooling_buffer_3x3_stream u_pb0 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_relu0),
        .data_in(relu_out0),
        .img_width(img_width), .img_height(img_height),
        .valid_out(pb0_valid),
        .d0(pb0_d0), .d1(pb0_d1), .d2(pb0_d2),
        .d3(pb0_d3), .d4(pb0_d4), .d5(pb0_d5),
        .d6(pb0_d6), .d7(pb0_d7), .d8(pb0_d8)
    );

    pooling u_pool0 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(pb0_valid),
        .data_in0(pb0_d0), .data_in1(pb0_d1), .data_in2(pb0_d2),
        .data_in3(pb0_d3), .data_in4(pb0_d4), .data_in5(pb0_d5),
        .data_in6(pb0_d6), .data_in7(pb0_d7), .data_in8(pb0_d8),
        .max_out(pool_out0), .valid_out(valid_pool0)
    );

    wire pb1_valid;
    wire signed [15:0] pb1_d0,pb1_d1,pb1_d2,pb1_d3,pb1_d4,pb1_d5,pb1_d6,pb1_d7,pb1_d8;

    pooling_buffer_3x3_stream u_pb1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_relu1),
        .data_in(relu_out1),
        .img_width(img_width), .img_height(img_height),
        .valid_out(pb1_valid),
        .d0(pb1_d0), .d1(pb1_d1), .d2(pb1_d2),
        .d3(pb1_d3), .d4(pb1_d4), .d5(pb1_d5),
        .d6(pb1_d6), .d7(pb1_d7), .d8(pb1_d8)
    );

    pooling u_pool1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(pb1_valid),
        .data_in0(pb1_d0), .data_in1(pb1_d1), .data_in2(pb1_d2),
        .data_in3(pb1_d3), .data_in4(pb1_d4), .data_in5(pb1_d5),
        .data_in6(pb1_d6), .data_in7(pb1_d7), .data_in8(pb1_d8),
        .max_out(pool_out1), .valid_out(valid_pool1)
    );

    assign conv_out0 = conv_res0;
    assign conv_out1 = conv_res1;

    // ===== 內嵌小模組：ReLU 串流 → 3×3 （stride=1，無 padding）=====
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
endmodule