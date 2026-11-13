function rho = pol_degeneracy(sx, sy)
%POL_DEGENERACY 两偏振输出退化检查：复相关系数幅值。
%
% rho = |sum(sx .* conj(sy))| / sqrt(sum(|sx|^2) * sum(|sy|^2))。
% rho ≈ 1 表示两路输出退化为同一路（未能分别解复用）；
% 独立双偏振解调时 rho 应明显小于 1。零能量报错。

sx = double(sx(:));
sy = double(sy(:));
if isempty(sx) || numel(sx) ~= numel(sy)
    error('DSPCMA:metrics:shapeMismatch', 'sx 与 sy 必须为同长非空向量');
end
nx = sum(abs(sx).^2);
ny = sum(abs(sy).^2);
if nx == 0 || ny == 0
    error('DSPCMA:metrics:zeroEnergy', '输入能量为零');
end
rho = abs(sum(sx .* conj(sy))) / sqrt(nx * ny);
end
