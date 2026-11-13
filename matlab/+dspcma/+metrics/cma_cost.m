function res = cma_cost(errx, erry, seg_len, par_num)
%CMA_COST 每时钟 CMA 代价（模误差平方均值），用于收敛曲线。
%
% 输入 errx/erry 为逐样本误差 e = R - |z|^2（长度 = seg_num*seg_len）。
% 输出 res.cost_x/res.cost_y: 1×clk_num 向量，第 c 个元素为第 c 个
% 时钟（par_num 段）内该偏振 e^2 的均值；res.cost_total 为两偏振之和。

errx = double(errx(:));
erry = double(erry(:));
if numel(errx) ~= numel(erry)
    error('DSPCMA:metrics:shapeMismatch', 'errx 与 erry 长度不同');
end
samples_per_clk = seg_len * par_num;
n_clk = floor(numel(errx) / samples_per_clk);
if n_clk == 0
    error('DSPCMA:metrics:tooShort', '样本不足一个时钟周期');
end
cx = zeros(1, n_clk);
cy = zeros(1, n_clk);
for c = 1:n_clk
    r0 = (c - 1) * samples_per_clk + 1;
    r1 = r0 + samples_per_clk - 1;
    cx(c) = mean(errx(r0:r1).^2);
    cy(c) = mean(erry(r0:r1).^2);
end
res.cost_x = cx;
res.cost_y = cy;
res.cost_total = cx + cy;
res.n_clk = n_clk;
end
