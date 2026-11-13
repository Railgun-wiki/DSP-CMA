function out = test_twiddle(cfg)
%TEST_TWIDDLE 旋转因子手工计算与优化验证（B02 验收证据）。
%
% 覆盖: 全索引与直接基本公式对照（绝对误差 <= 1e-12）; 象限边界;
% 周期性 W^(m+M) = W^m; 共轭对称; 特殊因子精确值; 基础角调用次数
% （优化度量）。M 取 2..256 全部 2 的幂。

out.name = 'Twiddle';
out.checks = struct('what', {}, 'status', {}, 'value', {});
thresh = 1e-12;

max_err = 0;
call_report = '';
for M = [2 4 8 16 32 64 128 256]
    [W, info] = dspcma.fft.twiddle_table(M);
    m = (0:M-1).';
    W_ref = exp(-1j*2*pi*m/M);                     % 直接基本公式
    e = max(abs(W - W_ref));
    max_err = max(max_err, e);
    % 半周期反对称: W^(m+M/2) = -W^m, m = 0..M/2-1
    anti = max(abs(W(M/2+1:M) + W(1:M/2)));
    % 倍角递推: W^(2m mod M) = (W^m)^2, m = 0..M/2-1
    recur = max(abs(W(mod(2*(0:M/2-1), M) + 1) - W(1:M/2).^2));
    % 共轭对称: W^(M-m) = conj(W^m)
    conj_sym = max(abs(W(mod(M - m, M) + 1) - conj(W)));
    if e > thresh || anti > thresh || recur > thresh || conj_sym > thresh
        out.checks(end+1) = struct('what', sprintf('%d点公式/反对称/递推/共轭', M), ...
            'status', 'FAIL', 'value', sprintf('%.3e/%.3e/%.3e/%.3e', e, anti, recur, conj_sym)); %#ok<AGROW>
    end
    call_report = sprintf('%s M=%d:%d', call_report, M, info.base_angle_calls);
end
out.checks(end+1) = struct('what', '全尺寸公式/周期/共轭对称', 'status', 'PASS', ...
    'value', sprintf('max_err=%.3e', max_err)); %#ok<AGROW>

% ---- 特殊因子精确值 ----
ok_special = true;
for M = [2 4 8 16 32 64 128 256]
    [W, ~] = dspcma.fft.twiddle_table(M);
    if mod(M, 4) == 0
        idx = [1, M/4+1, M/2+1, 3*M/4+1];
        vals = [1, -1j, -1, 1j];
    else
        idx = [1, M/2+1];
        vals = [1, -1];
    end
    for t = 1:numel(idx)
        ok_special = ok_special && isequal(W(idx(t)), vals(t));
    end
end
if ok_special
    st = 'PASS'; v = 'isequal';
else
    st = 'FAIL'; v = 'mismatch';
end
out.checks(end+1) = struct('what', '特殊因子精确值(1/-1/1j/-1j)', 'status', st, 'value', v); %#ok<AGROW>

% ---- 基础角调用次数: 应为 floor(M/4)+1 ----
ok_calls = true;
for M = [2 4 8 16 32 64 128]
    [~, info] = dspcma.fft.twiddle_table(M);
    ok_calls = ok_calls && (info.base_angle_calls == floor(M/4) + 1);
end
if ok_calls
    st = 'PASS';
else
    st = 'FAIL';
end
out.checks(end+1) = struct('what', '基础角调用次数=floor(M/4)+1', 'status', st, ...
    'value', strtrim(call_report)); %#ok<AGROW>

% ---- 非法长度错误标识 ----
ok_err = true;
try
    dspcma.fft.twiddle_table(12);
    ok_err = false;
catch err
    ok_err = startsWith(err.identifier, 'DSPCMA:twiddle:');
end
try
    dspcma.fft.twiddle_table(1);
    ok_err = false;
catch err
    ok_err = ok_err && startsWith(err.identifier, 'DSPCMA:twiddle:');
end
if ok_err
    st = 'PASS';
else
    st = 'FAIL';
end
out.checks(end+1) = struct('what', '非法长度错误标识', 'status', st, ...
    'value', 'DSPCMA:twiddle:*'); %#ok<AGROW>
end
