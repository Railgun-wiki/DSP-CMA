// fft32_top: 32 点全并行 FFT 顶层 (H01/H02)。
// 总线格式 (AGENTS 5): 点 k 占 [16k +: 16]: 实部 [16k +: 8],
// 虚部 [16k+8 +: 8], 各 8 bit 二补码; 总宽 (8+8)*32 = 512 bit。
// 总延迟 L = 4*5 + 2 = 22 拍 (in_valid 到 out_valid 同拍对齐)。
module fft32_top (
    input  wire         clk,
    input  wire         rst,          // 同步高有效
    input  wire         in_valid,
    input  wire [511:0] din,
    output wire [511:0] dout,
    output wire         out_valid,
    output wire [31:0]  sat_cnt
);
    fft_radix2_core #(.N(32)) u_core (
        .clk      (clk),
        .rst      (rst),
        .in_valid (in_valid),
        .din      (din),
        .dout     (dout),
        .out_valid(out_valid),
        .sat_cnt  (sat_cnt)
    );
endmodule
