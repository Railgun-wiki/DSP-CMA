// fft64_top: 64 点全并行 FFT 顶层 (H01/H02)。
// 总线格式同 fft32_top: 总宽 (8+8)*64 = 1024 bit。
// 总延迟 L = 4*6 + 2 = 26 拍。
module fft64_top (
    input  wire          clk,
    input  wire          rst,          // 同步高有效
    input  wire          in_valid,
    input  wire [1023:0] din,
    output wire [1023:0] dout,
    output wire          out_valid,
    output wire [31:0]   sat_cnt
);
    fft_radix2_core #(.N(64)) u_core (
        .clk      (clk),
        .rst      (rst),
        .in_valid (in_valid),
        .din      (din),
        .dout     (dout),
        .out_valid(out_valid),
        .sat_cnt  (sat_cnt)
    );
endmodule
