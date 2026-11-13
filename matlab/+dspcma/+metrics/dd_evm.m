function res = dd_evm(z, cal, ideal)
%DD_EVM 判决导向 DD-EVM（主指标）。
%
% 数据无已知发送符号：对校准后的接收样本判决到最近理想 4QAM 点后
% 按 evm_rms 计算误差，命名为 DD-EVM；不据此推导 BER，不写成已知
% 参考 EVM。
%
% 输入:
%   z     -- 待评估复数样本向量（原始或均衡后）。
%   cal   -- calibrate_4qam 在独立校准段上估计并冻结的参数
%            （字段 .phase, .gain）。
%   ideal -- 理想 4QAM 星座（默认 [1+1j; 1-1j; -1+1j; -1-1j]）。
% 输出:
%   res.evmm    -- RMS EVM（比率）。
%   res.evm_pct -- 百分数。
%   res.evm_db  -- dB（evm=0 时为 -Inf）。
%   res.s       -- 校准后样本。
%   res.r       -- 判决参考点（理想星座点）。
%   res.n       -- 有效样本数。

if nargin < 3
    ideal = [1+1j; 1-1j; -1+1j; -1-1j];
end
if ~isfield(cal, 'phase') || ~isfield(cal, 'gain')
    error('DSPCMA:metrics:badCal', 'cal 必须来自 calibrate_4qam（含 phase/gain）');
end
if ~isvector(z) || isempty(z)
    error('DSPCMA:metrics:badShape', 'z 必须为非空向量');
end
z = complex(double(z(:)));
if any(~isfinite(z))
    error('DSPCMA:metrics:notFinite', 'z 含 NaN/Inf');
end
s = z * exp(-1j * cal.phase) / cal.gain;
% 4QAM 判决: 最近理想点 = sign(Re) + 1j*sign(Im)（确定性，无平局歧义）
r = sign(real(s)) + 1j * sign(imag(s));
res.evmm = dspcma.metrics.evm_rms(s, r);
res.evm_pct = 100 * res.evmm;
if res.evmm == 0
    res.evm_db = -Inf;
else
    res.evm_db = 20 * log10(res.evmm);
end
res.s = s;
res.r = r;
res.n = numel(z);
end
