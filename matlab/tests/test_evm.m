function out = test_evm(cfg)
%TEST_EVM EVM 与校准验证（AGENTS 第 7 节 EVM 行）。
%
% 覆盖: 公式解析值一致; 理想符号+已知扰动(增益/相位)校准后 EVM~0;
% 已知噪声的解析 EVM; 判决确定性; 零参考能量报错; 冻结校准参数跨段
% 应用的一致性。全部不涉及 BER。

rng(cfg.rng_seed, 'twister');
out.name = 'EVM';
out.checks = struct('what', {}, 'status', {}, 'value', {});

    function add(what, ok, val)
        if ok
            st = 'PASS';
        else
            st = 'FAIL';
        end
        out.checks(end+1) = struct('what', what, 'status', st, 'value', val); %#ok<AGROW>
    end

    function [sx, sy] = gen_4qam(n)
        b1 = randi([0 3], n, 1);
        sx = 2 * (bitand(b1, 2) > 0) - 1 + 1j * (2 * bitand(b1, 1) - 1);
        b2 = randi([0 3], n, 1);
        sy = 2 * (bitand(b2, 2) > 0) - 1 + 1j * (2 * bitand(b2, 1) - 1);
    end

% ---- 公式一致性: 与显式循环独立计算对照 ----
n = 500;
s = (randn(n, 1) + 1j * randn(n, 1)) * 0.3;
r = (randn(n, 1) + 1j * randn(n, 1));
e_manual = sqrt(sum(abs(s - r).^2) / sum(abs(r).^2));
e_fn = dspcma.metrics.evm_rms(s, r);
add('公式一致性', abs(e_fn - e_manual) <= 1e-12 * max(1, e_manual), ...
    sprintf('%.12f vs %.12f', e_fn, e_manual));

% ---- 零参考能量报错 ----
ok_zero = false;
try
    dspcma.metrics.evm_rms(s, zeros(n, 1));
catch err
    ok_zero = strcmp(err.identifier, 'DSPCMA:evm:zeroRef');
end
add('零参考能量报错', ok_zero, 'DSPCMA:evm:zeroRef');

% ---- 理想符号 + 已知增益/相位旋转: 校准后 DD-EVM ≈ 0 ----
sy0 = gen_4qam(n);
z = 1.7 * exp(1j * 0.3) * sy0;
cal = dspcma.metrics.calibrate_4qam(z);
res = dspcma.metrics.dd_evm(z, cal);
phase_ok = abs(angle(exp(1j * (cal.phase - 0.3)))) < 1e-9 ...
    || abs(angle(exp(1j * (cal.phase - 0.3 - pi / 2)))) < 1e-9 ...
    || abs(angle(exp(1j * (cal.phase - 0.3 - pi)))) < 1e-9 ...
    || abs(angle(exp(1j * (cal.phase - 0.3 + pi / 2)))) < 1e-9;
gain_ok = abs(cal.gain - 1.7) < 1e-9;
evm_ok = res.evmm <= 1e-12;
add('校准相位恢复(含pi/2歧义)', phase_ok, sprintf('%.3e', cal.phase));
add('校准增益恢复', gain_ok, sprintf('%.6f', cal.gain));
add('理想+扰动校准后EVM≈0', evm_ok, sprintf('%.2e', res.evmm));

% ---- 已知噪声的解析 DD-EVM: s = p + w, w 固定向量 ----
p = gen_4qam(n);
w = (randn(n, 1) + 1j * randn(n, 1)) * 0.05;
s2 = p + w;
cal_id.phase = 0;
cal_id.gain = 1;
res2 = dspcma.metrics.dd_evm(s2, cal_id);
e_analytic = sqrt(sum(abs(w).^2) / sum(abs(p).^2));
add('解析DD-EVM(小噪声判决)', abs(res2.evmm - e_analytic) <= 1e-10, ...
    sprintf('%.8f vs %.8f', res2.evmm, e_analytic));

% ---- 判决确定性: r 必为理想 4QAM 点 ----
ideal = cfg.ideal_4qam(:);
r_ok = true;
for k = 1:numel(ideal)
    r_ok = r_ok && any(res2.r == ideal(k));
end
r_ok = r_ok && all(ismember(res2.r, ideal));
add('判决点属于理想星座', r_ok, sprintf('%d样本', res2.n));

% ---- 冻结校准参数跨段应用 ----
sym_all = gen_4qam(2000);
z_all = 1.7 * exp(1j * 0.3) * sym_all;
cal_a = dspcma.metrics.calibrate_4qam(z_all(1:500));    % 独立校准段
res_a = dspcma.metrics.dd_evm(z_all(501:1000), cal_a);  % 应用段
res_b = dspcma.metrics.dd_evm(z_all(1001:1500), cal_a);
add('冻结参数跨段EVM一致', abs(res_a.evmm - res_b.evmm) <= 1e-9, ...
    sprintf('%.2e vs %.2e', res_a.evmm, res_b.evmm));

% ---- 未经校准输出必须保留（口径检查：同一输入两种处理不同） ----
res_raw = dspcma.metrics.dd_evm(z_all(1501:2000), cal_id);
add('未校准EVM不同(校准必要性)', res_raw.evmm > res_a.evmm, ...
    sprintf('%.2f > %.2e', res_raw.evmm, res_a.evmm));
end
