function y = conv_direct(x, h)
%CONV_DIRECT 直接线性卷积基线（显式循环，B03 对照基准）。
%
% y[n] = sum_{l} x[n-l] * h[l]，输出长度 length(x) + length(h) - 1。
% 全卷积语义；输入可为复数行/列向量，输出与 x 同方向的长向量。
% 不使用任何 FFT；允许显式循环（AGENTS 规定基线可用循环实现）。
%
% 错误条件（DSPCMA:conv:*）: 非向量、空输入、非数值。

if ~isvector(x) || ~isvector(h) || isempty(x) || isempty(h)
    error('DSPCMA:conv:badShape', 'x 与 h 必须为非空向量');
end
if ~isnumeric(x) || ~isnumeric(h)
    error('DSPCMA:conv:badType', 'x 与 h 必须为数值类型');
end
if any(~isfinite(x(:))) || any(~isfinite(h(:)))
    error('DSPCMA:conv:notFinite', '输入含 NaN/Inf');
end

out_dir = 'row';
if iscolumn(x)
    out_dir = 'col';
end
x = complex(double(x(:)));
h = complex(double(h(:)));
Lx = numel(x);
Lh = numel(h);
Ly = Lx + Lh - 1;
y = zeros(Ly, 1);
for n = 1:Ly
    lo = max(1, n - Lh + 1);
    hi = min(n, Lx);
    acc = 0;
    for l = lo:hi
        acc = acc + x(l) * h(n - l + 1);
    end
    y(n) = acc;
end
if strcmp(out_dir, 'row')
    y = y.';   % 输出与 x 同方向
end
end
