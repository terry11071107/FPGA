`timescale 1ns/1ps
module top_tb;
    // ====== Parameters ======
    localparam integer DATA_WIDTH   = 16;
    localparam integer SCALE_SHIFT  = 4;
    localparam integer WRITE_SHIFT  = 0;
    localparam [1023:0] INPUT_FILE  = "input_image.txt";
    localparam integer  SKIP_BLOCKS = 0;

    // ====== DUT IO ======
    reg clk, rst_n;
    reg valid_in;
    reg signed [DATA_WIDTH-1:0] pixel_in;
    reg [7:0] img_w, img_h;

    wire                         valid_conv0;
    wire signed [2*DATA_WIDTH+4:0] conv_out0;
    wire                         valid_relu0;
    wire [7:0]                   relu_out0;
    wire                         valid_pool0;
    wire signed [15:0]           pool_out0;

    wire                         valid_conv1;
    wire signed [2*DATA_WIDTH+4:0] conv_out1;
    wire                         valid_relu1;
    wire [7:0]                   relu_out1;
    wire                         valid_pool1;
    wire signed [15:0]           pool_out1;

    // ====== Instantiate DUT ======
    top #(.DATA_WIDTH(DATA_WIDTH), .SCALE_SHIFT(SCALE_SHIFT)) dut (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in),
        .pixel_in(pixel_in),
        .img_width(img_w), .img_height(img_h),

        .valid_conv0(valid_conv0), .conv_out0(conv_out0),
        .valid_relu0(valid_relu0), .relu_out0(relu_out0),
        .valid_pool0(valid_pool0), .pool_out0(pool_out0),

        .valid_conv1(valid_conv1), .conv_out1(conv_out1),
        .valid_relu1(valid_relu1), .relu_out1(relu_out1),
        .valid_pool1(valid_pool1), .pool_out1(pool_out1)
    );

    // ====== Clock ======
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ====== 內建 8x8 範例影像（找不到檔案時使用） ======
    integer i, j;
    reg signed [DATA_WIDTH-1:0] img_default [0:63];
    initial begin
        img_default[ 0]=123; img_default[ 1]= 45; img_default[ 2]= 67; img_default[ 3]= 89; img_default[ 4]=210; img_default[ 5]= 32; img_default[ 6]= 99; img_default[ 7]=150;
        img_default[ 8]= 34; img_default[ 9]=255; img_default[10]=128; img_default[11]=  0; img_default[12]= 98; img_default[13]= 76; img_default[14]=120; img_default[15]=180;
        img_default[16]= 65; img_default[17]=190; img_default[18]=200; img_default[19]= 10; img_default[20]=140; img_default[21]= 60; img_default[22]=110; img_default[23]= 50;
        img_default[24]= 75; img_default[25]= 30; img_default[26]=180; img_default[27]=250; img_default[28]=100; img_default[29]= 15; img_default[30]= 30; img_default[31]= 25;
        img_default[32]= 90; img_default[33]=110; img_default[34]=240; img_default[35]= 80; img_default[36]= 70; img_default[37]= 60; img_default[38]=180; img_default[39]=200;
        img_default[40]= 10; img_default[41]= 20; img_default[42]= 30; img_default[43]= 40; img_default[44]= 50; img_default[45]= 60; img_default[46]= 70; img_default[47]= 80;
        img_default[48]= 25; img_default[49]= 55; img_default[50]= 85; img_default[51]= 45; img_default[52]=105; img_default[53]=135; img_default[54]=170; img_default[55]=210;
        img_default[56]= 10; img_default[57]= 30; img_default[58]= 50; img_default[59]= 70; img_default[60]= 90; img_default[61]=110; img_default[62]=130; img_default[63]=150;
    end

    // ====== 檔案/暫存/統計 變數（全部放在模組頂層宣告） ======
    integer fd, code, v;
    integer blk, ii_local, jj_local;
    integer file_W, file_H;
    integer Wskip, Hskip, k1, k2;
    integer use_default;

    reg signed [DATA_WIDTH-1:0] img_mem [0:65535]; // up to 256x256

    integer f_conv1, f_relu1, f_pool1_;
    integer f_conv2, f_relu2, f_pool2_;

    integer conv_c0, conv_r0, relu_c0, relu_r0, pool_c0, pool_r0;
    integer conv_c1, conv_r1, relu_c1, relu_r1, pool_c1, pool_r1;
    integer conv_count0, relu_count0, pool_count0;
    integer conv_count1, relu_count1, pool_count1;
    integer expected_conv_count, expected_pool_count;

    // ====== 逐流寫檔（矩陣） ======
    always @(posedge clk) begin
        // K1
        if (valid_conv0) begin
            $fwrite(f_conv1, "%0d ", $signed(conv_out0) <<< WRITE_SHIFT);
            conv_c0 = conv_c0 + 1;
            if (conv_c0 == img_w) begin conv_c0=0; conv_r0=conv_r0+1; $fwrite(f_conv1,"\n"); end
            conv_count0 = conv_count0 + 1;
        end
        if (valid_relu0) begin
            $fwrite(f_relu1, "%0d ", $signed(relu_out0) <<< WRITE_SHIFT);
            relu_c0 = relu_c0 + 1;
            if (relu_c0 == img_w) begin relu_c0=0; relu_r0=relu_r0+1; $fwrite(f_relu1,"\n"); end
            relu_count0 = relu_count0 + 1;
        end
        if (valid_pool0) begin
            $fwrite(f_pool1_, "%0d ", $signed(pool_out0) <<< WRITE_SHIFT);
            pool_c0 = pool_c0 + 1;
            if (pool_c0 == (img_w-2)) begin pool_c0=0; pool_r0=pool_r0+1; $fwrite(f_pool1_,"\n"); end
            pool_count0 = pool_count0 + 1;
        end

        // K2
        if (valid_conv1) begin
            $fwrite(f_conv2, "%0d ", $signed(conv_out1) <<< WRITE_SHIFT);
            conv_c1 = conv_c1 + 1;
            if (conv_c1 == img_w) begin conv_c1=0; conv_r1=conv_r1+1; $fwrite(f_conv2,"\n"); end
            conv_count1 = conv_count1 + 1;
        end
        if (valid_relu1) begin
            $fwrite(f_relu2, "%0d ", $signed(relu_out1) <<< WRITE_SHIFT);
            relu_c1 = relu_c1 + 1;
            if (relu_c1 == img_w) begin relu_c1=0; relu_r1=relu_r1+1; $fwrite(f_relu2,"\n"); end
            relu_count1 = relu_count1 + 1;
        end
        if (valid_pool1) begin
            $fwrite(f_pool2_, "%0d ", $signed(pool_out1) <<< WRITE_SHIFT);
            pool_c1 = pool_c1 + 1;
            if (pool_c1 == (img_w-2)) begin pool_c1=0; pool_r1=pool_r1+1; $fwrite(f_pool2_,"\n"); end
            pool_count1 = pool_count1 + 1;
        end
    end

    // ====== 主流程（無 task、無區塊內宣告） ======
    initial begin
        // reset/init
        rst_n = 0; valid_in = 0; pixel_in = 0; img_w = 0; img_h = 0;
        conv_c0=0; conv_r0=0; relu_c0=0; relu_r0=0; pool_c0=0; pool_r0=0;
        conv_c1=0; conv_r1=0; relu_c1=0; relu_r1=0; pool_c1=0; pool_r1=0;
        conv_count0=0; relu_count0=0; pool_count0=0;
        conv_count1=0; relu_count1=0; pool_count1=0;
        use_default = 0;

        repeat (3) @(negedge clk);
        rst_n = 1;

        // 嘗試開檔
        fd = $fopen(INPUT_FILE, "r");
        if (fd == 0) begin
            $display("⚠️  Cannot open %0s. Use default 8x8 image.", INPUT_FILE);
            use_default = 1;
        end

        // 有檔案 → 跳過前面 N 張
        if (!use_default) begin
            for (blk = 0; blk < SKIP_BLOCKS; blk = blk + 1) begin
                k1 = $fscanf(fd, "%d %d\n", Wskip, Hskip);
                if (k1 != 2 || Wskip <= 0 || Hskip <= 0) begin
                    $display("❌ Not enough blocks to skip (SKIP_BLOCKS=%0d).", SKIP_BLOCKS);
                    use_default = 1;
                end
                if (!use_default) begin
                    for (ii_local = 0; ii_local < Hskip; ii_local = ii_local + 1) begin
                        for (jj_local = 0; jj_local < Wskip; jj_local = jj_local + 1) begin
                            k2 = $fscanf(fd, "%d", v);
                            if (k2 != 1) begin
                                $display("❌ Skip block pixel read error.");
                                use_default = 1;
                            end
                        end
                    end
                end
            end
        end

        // 讀取本次影像
        if (!use_default) begin
            code = $fscanf(fd, "%d %d\n", file_W, file_H);
            if (code != 2 || file_W <= 0 || file_H <= 0) begin
                $display("❌ Failed to read image size from %0s.", INPUT_FILE);
                use_default = 1;
            end else begin
                for (ii_local = 0; ii_local < file_H; ii_local = ii_local + 1) begin
                    for (jj_local = 0; jj_local < file_W; jj_local = jj_local + 1) begin
                        code = $fscanf(fd, "%d", v);
                        if (code != 1) begin
                            $display("❌ Not enough pixel data at (%0d,%0d).", ii_local, jj_local);
                            use_default = 1;
                        end else begin
                            img_mem[ii_local*file_W + jj_local] = v[15:0];
                        end
                    end
                end
            end
            $fclose(fd);
        end

        // 開啟輸出檔
        f_conv1 = $fopen("output_conv_k1.txt", "w");
        f_relu1 = $fopen("output_relu_k1.txt", "w");
        f_pool1_ = $fopen("output_pool_k1.txt", "w");
        f_conv2 = $fopen("output_conv_k2.txt", "w");
        f_relu2 = $fopen("output_relu_k2.txt", "w");
        f_pool2_ = $fopen("output_pool_k2.txt", "w");

        // 餵資料：檔案成功 → 用檔案影像；否則用預設 8x8
        if (!use_default) begin
            img_w = file_W[7:0];
            img_h = file_H[7:0];
            $display("✅ Loaded %0s: %0dx%0d", INPUT_FILE, file_W, file_H);

            @(negedge clk);
            for (i = 0; i < file_H; i = i + 1) begin
                for (j = 0; j < file_W; j = j + 1) begin
                    valid_in <= 1;
                    pixel_in <= img_mem[i*file_W + j];
                    @(negedge clk);
                end
            end
            valid_in <= 0;
            pixel_in <= 0;
        end else begin
            img_w = 8; img_h = 8;
            @(negedge clk);
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 8; j = j + 1) begin
                    valid_in <= 1;
                    pixel_in <= img_default[i*8 + j];
                    @(negedge clk);
                end
            end
            valid_in <= 0;
            pixel_in <= 0;
        end

        // 等 pipeline 排空
        repeat (2000) @(negedge clk);

        // 統計與總結
        expected_conv_count = img_w * img_h;
        if (img_w >= 3 && img_h >= 3)
            expected_pool_count = (img_w - 2) * (img_h - 2);
        else
            expected_pool_count = 0;

        $display("\n=== Final Summary (Kernel1) ===");
        $display("Conv: %0d / %0d,  ReLU: %0d / %0d,  Pool: %0d / %0d",
                 conv_count0, expected_conv_count,
                 relu_count0, expected_conv_count,
                 pool_count0, expected_pool_count);

        $display("\n=== Final Summary (Kernel2) ===");
        $display("Conv: %0d / %0d,  ReLU: %0d / %0d,  Pool: %0d / %0d",
                 conv_count1, expected_conv_count,
                 relu_count1, expected_conv_count,
                 pool_count1, expected_pool_count);

        // 關檔
        if (f_conv1)  $fclose(f_conv1);
        if (f_relu1)  $fclose(f_relu1);
        if (f_pool1_) $fclose(f_pool1_);
        if (f_conv2)  $fclose(f_conv2);
        if (f_relu2)  $fclose(f_relu2);
        if (f_pool2_) $fclose(f_pool2_);
        $finish;
    end
endmodule
