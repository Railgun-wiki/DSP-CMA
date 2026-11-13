// fft_radix2_core: 全并行基-2 DIT FFT 核 (N = 32/64)。
// 结构 (AGENTS 5, docs/architecture.md 定点表):
//   * 每拍一帧 (N 个复点): 输入 8 bit/分量, 内部 Q8 16 bit;
//   * 输入寄存 (1 拍, 8->Q8, 位倒序纯布线) -> S = log2(N) 级 bfly2
//     (每级 N/2 个全并行实例, 级延迟恰 4 拍) -> 末级 Q8->8bit 半偶
//     舍入 + 饱和计数 (1 拍);
//   * 每级缩放 1/2, 累计 1/N; 总延迟 L = 4*S + 2 拍 (恒定, 逐帧);
//   * 数据通路自由运行 (气泡期处理无害垃圾并自然冲刷), valid 单独
//     延迟链跟踪; 非法/空拍不产生有效输出; 复位清空全部寄存器。
module fft_radix2_core #(
    parameter integer N = 32              // 仅 32 / 64
) (
    input  wire                 clk,
    input  wire                 rst,       // 同步高有效
    input  wire                 in_valid,  // 高时 din 为一帧
    input  wire [2*N*8-1:0]     din,       // 点 k: 实部 [16k +: 8], 虚部 [16k+8 +: 8]
    output wire [2*N*8-1:0]     dout,      // 同格式, 自然序
    output wire                 out_valid,
    output reg  [31:0]          sat_cnt    // 发生饱和的帧计数
);
    localparam integer S = $clog2(N);
`include "fft_twiddle_tables.vh"

    genvar gk, gs, gb, gj;

    // ---- valid 延迟链: v_shift[k] 高表示"该拍流水线中的数据来自
    //      k-1 拍前的一个有效帧" (数据通路本身自由运行) ----
    reg [4*S+2:1] v_shift;
    always @(posedge clk) begin
        if (rst) begin
            v_shift <= {(4*S+2){1'b0}};
        end else begin
            v_shift[1] <= in_valid;
            v_shift[4*S+2:2] <= v_shift[4*S+1:1];
        end
    end

    // ---- 位倒序常量函数 ----
    function integer bitrev_idx(input integer k);
        integer v, r, b;
        begin
            v = k; r = 0;
            for (b = 0; b < S; b = b + 1) begin
                r = r * 2 + (v % 2);
                v = v / 2;
            end
            bitrev_idx = r;
        end
    endfunction

    // ---- 级间扁平数组: 第 s 行 = 第 s 级输出 (s = 0..S-1) ----
    wire signed [15:0] stg_re [0:S*N-1];
    wire signed [15:0] stg_im [0:S*N-1];
    wire               sat_w [0:S*N/2-1];

    // ---- 输入寄存: 8 bit -> Q8, 位倒序布线 (门控 = in_valid) ----
    reg signed [15:0] s0_re [0:N-1];
    reg signed [15:0] s0_im [0:N-1];
    generate
        for (gk = 0; gk < N; gk = gk + 1) begin : g_in
            always @(posedge clk) begin
                if (rst) begin
                    s0_re[bitrev_idx(gk)] <= 16'sd0;
                    s0_im[bitrev_idx(gk)] <= 16'sd0;
                end else begin
                    s0_re[bitrev_idx(gk)] <= {din[16*gk +: 8], 8'b0};
                    s0_im[bitrev_idx(gk)] <= {din[16*gk + 8 +: 8], 8'b0};
                end
            end
        end
    endgenerate

    // ---- S 级蝶形 (每级 N/2 个 bfly2 全并行) ----
    generate
        for (gs = 0; gs < S; gs = gs + 1) begin : g_stage
            localparam integer HALF = (1 << gs);
            localparam integer MB = (1 << (gs + 1));
            for (gb = 0; gb < N/MB; gb = gb + 1) begin : g_blk
                for (gj = 0; gj < HALF; gj = gj + 1) begin : g_bf
                    localparam integer IP = gs*N + gb*MB + gj;        // 顶臂索引
                    localparam integer IQ = gs*N + gb*MB + gj + HALF; // 底臂索引
                    localparam integer OP = (gs == 0) ? (gb*MB + gj)        : (gs*N + gb*MB + gj);
                    localparam integer OQ = (gs == 0) ? (gb*MB + gj + HALF) : (gs*N + gb*MB + gj + HALF);
                    localparam [34:0] TW = (N == 32) ?
                        fft_tw32(gs, gj) : fft_tw64(gs, gj);
                    bfly2 #(
                        .SPEC(TW[34:32]),
                        .WRE (TW[31:16]),
                        .WIM (TW[15:0])
                    ) u_bf (
                        .clk (clk),
                        .rst (rst),
                        .en  (1'b1),
                        .a_re((gs == 0) ? s0_re[gb*MB + gj]        : stg_re[(gs-1)*N + gb*MB + gj]),
                        .a_im((gs == 0) ? s0_im[gb*MB + gj]        : stg_im[(gs-1)*N + gb*MB + gj]),
                        .b_re((gs == 0) ? s0_re[gb*MB + gj + HALF] : stg_re[(gs-1)*N + gb*MB + gj + HALF]),
                        .b_im((gs == 0) ? s0_im[gb*MB + gj + HALF] : stg_im[(gs-1)*N + gb*MB + gj + HALF]),
                        .u_re(stg_re[OP]),
                        .u_im(stg_im[OP]),
                        .v_re(stg_re[OQ]),
                        .v_im(stg_im[OQ]),
                        .sat (sat_w[gs*N/2 + gb*HALF + gj])
                    );
                end
            end
        end
    endgenerate

    // ---- 末级 Q8 -> 8 bit 半偶舍入 + 饱和 (1 拍) ----
    function signed [7:0] q8_to_s8(input signed [15:0] v, inout sat_o);
        reg signed [15:0] base;
        reg signed [15:0] q;
        begin
            base = v >>> 8;
            if (v[7:0] > 8'd128)
                q = base + 16'sd1;
            else if (v[7:0] < 8'd128)
                q = base;
            else if (base[0] == 1'b0)
                q = base;             // 恰半向偶
            else
                q = base + 16'sd1;
            if (q > 16'sd127) begin
                q = 16'sd127;
                sat_o = 1'b1;
            end else if (q < -16'sd128) begin
                q = -16'sd128;
                sat_o = 1'b1;
            end
            q8_to_s8 = q[7:0];
        end
    endfunction

    // 末级舍入: 组合部分 (每拍自由计算) + 时序部分 (非阻塞寄存);
    // 饱和计数仅统计有效帧 (v_shift[4*S+1] 门控)。
    wire en_final = v_shift[1 + 4*S];
    reg [2*N*8-1:0] dout_r;
    reg [2*N*8-1:0] dout_next;
    reg             sat_next;
    integer fk;
    reg signed [15:0] vre, vim;
    reg signed [7:0] ore, oim;
    reg any_sat;
    integer si;
    reg sat_any_stage;

    always @* begin
        vre = 16'sd0; vim = 16'sd0; ore = 8'sd0; oim = 8'sd0;
        any_sat = 1'b0; sat_any_stage = 1'b0;
        for (si = 0; si < S*N/2; si = si + 1)
            sat_any_stage = sat_any_stage | sat_w[si];
        any_sat = 1'b0;
        for (fk = 0; fk < N; fk = fk + 1) begin
            vre = stg_re[(S-1)*N + fk];
            vim = stg_im[(S-1)*N + fk];
            ore = q8_to_s8(vre, any_sat);
            oim = q8_to_s8(vim, any_sat);
            dout_next[16*fk +: 8]     = ore;
            dout_next[16*fk + 8 +: 8] = oim;
        end
        sat_next = any_sat | sat_any_stage;
    end

    always @(posedge clk) begin
        if (rst) begin
            dout_r   <= {(2*N*8){1'b0}};
            sat_cnt  <= 32'd0;
        end else begin
            dout_r   <= dout_next;
            if (en_final && sat_next)
                sat_cnt <= sat_cnt + 32'd1;
        end
    end

    assign dout      = dout_r;
    assign out_valid = v_shift[4*S+2];
endmodule
