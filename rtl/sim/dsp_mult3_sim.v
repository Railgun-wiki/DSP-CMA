// dsp_mult3: 仿真专用行为模型 (与 rtl/common/dsp_mult3.v 同名同端口)。
// 仅加入仿真文件清单, 不进入综合源清单 (AGENTS 6.3);
// 行为乘法 '*' 只存在于本隔离文件中。
// 时序: en 有效拍计数 3 拍后输出; en 低冻结; rst 同步清零。
module dsp_mult3 (
    input  wire               clk,
    input  wire               rst,
    input  wire               en,
    input  wire signed [15:0] a,
    input  wire signed [15:0] b,
    output reg  signed [30:0] p
);
    reg signed [31:0] d1, d2;

    always @(posedge clk) begin
        if (rst) begin
            d1 <= 32'sd0;
            d2 <= 32'sd0;
            p  <= 31'sd0;
        end else if (en) begin
            d1 <= a * b;
            d2 <= d1;
            p  <= d2[30:0];
        end
    end
endmodule
