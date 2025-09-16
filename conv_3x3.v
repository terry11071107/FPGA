`timescale 1ns/1ps
module conv_3x3(
    input clk,
    input rst_n,
    input valid_in,
    input signed [7:0] data_in0,
    input signed [7:0] data_in1,
    input signed [7:0] data_in2,
    input signed [7:0] data_in3,
    input signed [7:0] data_in4,
    input signed [7:0] data_in5,
    input signed [7:0] data_in6,
    input signed [7:0] data_in7,
    input signed [7:0] data_in8,
    input signed [7:0] weight0,
    input signed [7:0] weight1,
    input signed [7:0] weight2,
    input signed [7:0] weight3,
    input signed [7:0] weight4,
    input signed [7:0] weight5,
    input signed [7:0] weight6,
    input signed [7:0] weight7,
    input signed [7:0] weight8,
    output reg signed [15:0] data_out,
    output reg valid_out
);

    // Stage1: 前 5 組乘法
    reg signed [15:0] mult_stage1[0:4];
    reg valid_stage1;

    // Stage2: 後4組乘法 + 加法
    reg signed [15:0] mult_stage2[0:3];
    reg signed [15:0] sum_stage2;
    reg valid_stage2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_stage1[0] <= 0; mult_stage1[1] <= 0; mult_stage1[2] <= 0;
            mult_stage1[3] <= 0; mult_stage1[4] <= 0;
            valid_stage1 <= 0;
        end else begin
            if (valid_in) begin
                mult_stage1[0] <= data_in0 * weight0;
                mult_stage1[1] <= data_in1 * weight1;
                mult_stage1[2] <= data_in2 * weight2;
                mult_stage1[3] <= data_in3 * weight3;
                mult_stage1[4] <= data_in4 * weight4;
                valid_stage1 <= 1;
            end else begin
                valid_stage1 <= 0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mult_stage2[0] <= 0; mult_stage2[1] <= 0;
            mult_stage2[2] <= 0; mult_stage2[3] <= 0;
            sum_stage2 <= 0;
            valid_stage2 <= 0;
            data_out <= 0;
            valid_out <= 0;
        end else begin
            if (valid_stage1) begin
                // Stage2: 後4組乘法
                mult_stage2[0] <= data_in5 * weight5;
                mult_stage2[1] <= data_in6 * weight6;
                mult_stage2[2] <= data_in7 * weight7;
                mult_stage2[3] <= data_in8 * weight8;

                // 全部加法
                sum_stage2 <= mult_stage1[0] + mult_stage1[1] + mult_stage1[2] + mult_stage1[3] + mult_stage1[4]
                              + mult_stage2[0] + mult_stage2[1] + mult_stage2[2] + mult_stage2[3];

                valid_stage2 <= 1;
            end else begin
                valid_stage2 <= 0;
            end

            // 輸出
            if (valid_stage2) begin
                data_out <= sum_stage2;
                valid_out <= 1;
            end else begin
                valid_out <= 0;
            end
        end
    end

endmodule