function cal = calibrate_4qam(z, ideal)
%CALIBRATE_4QAM 4QAM 盲均衡输出的标量增益/公共相位校准。
%
% 仅处理盲均衡固有的歧义: 一个标量增益与一个公共相位（4QAM 的 pi/2
% 旋转歧义对星座与 EVM 无影响，不额外消除）。流程固定:
%   1) 相位: 四次方估计 theta = (angle(mean(z.^4)) - pi) / 4。
%      理想 4QAM 点 (±1±1j) 满足 p^4 = -4，故 z = g*e^{jθ}p 给出
%      mean(z^4) = -4*g^4*e^{j4θ}。
%   2) 增益: g = mean(|z*e^{-jθ}|) / mean(|ideal|)。
%   3) 校准输出 s = z * e^{-jθ} / g。
%
% 校准参数必须由调用方在独立校准段上估计并冻结后应用于评估窗
% （见 run_tap_sweep / run_all），本函数只做估计+应用。
%
% 输入:
%   z     -- 校准段复数样本向量。
%   ideal -- 理想 4QAM 星座向量（默认 [1+1j; 1-1j; -1+1j; -1-1j]）。
% 输出: cal.phase, cal.gain, cal.s（校准段已校准样本，便于检查）。

if nargin < 2
    ideal = [1+1j; 1-1j; -1+1j; -1-1j];
end
if ~isvector(z) || isempty(z)
    error('DSPCMA:metrics:badShape', 'z 必须为非空向量');
end
z = complex(double(z(:)));
if any(~isfinite(z))
    error('DSPCMA:metrics:notFinite', 'z 含 NaN/Inf');
end
if mean(abs(z)) == 0
    error('DSPCMA:metrics:zeroInput', '校准段能量为零，无法估计');
end
c4 = mean(z .^ 4);
theta = (angle(c4) - pi) / 4;
zc = z * exp(-1j * theta);
g = mean(abs(zc)) / mean(abs(ideal(:)));
if g == 0 || ~isfinite(g)
    error('DSPCMA:metrics:badGain', '增益估计无效: %g', g);
end
cal.phase = theta;
cal.gain = g;
cal.s = z * exp(-1j * theta) / g;
end
