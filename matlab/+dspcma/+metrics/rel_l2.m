function e = rel_l2(a, b)
%REL_L2 相对 L2 误差 ||a-b||_2 / ||b||_2。
%
% 参考范数 ||b||_2 为 0 时返回绝对误差 ||a-b||_2（AGENTS 规定的零参考口径），
% 此时结果通过 info 字段无法区分，调用方需自行判读；输入必须同形状向量。

if ~isequal(size(a), size(b))
    error('DSPCMA:metrics:shapeMismatch', 'a 与 b 形状不同');
end
a = double(a(:));
b = double(b(:));
if any(~isfinite(a)) || any(~isfinite(b))
    error('DSPCMA:metrics:notFinite', '输入含 NaN/Inf');
end
d = norm(a - b);
nb = norm(b);
if nb == 0
    e = d;   % 零参考: 退化为绝对误差
else
    e = d / nb;
end
end
