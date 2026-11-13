function cases = gen_fft_vectors(cfg, out_dir)
%GEN_FFT_VECTORS 生成 RTL 测试向量（输入帧 + 期望输出帧）与清单。
%
% 对 N ∈ {32, 64} 生成用例: 冲激(首位/末位)、常数、1/4 频点整数音、
% 随机(种子固定)、极值。期望输出由定点整数模型 fft_fixed_model 逐位
% 计算（RTL 验收口径）。输出文件: rtl/tb/vectors/ 下
%   fft<N>_in_<case>.mem / fft<N>_exp_<case>.mem（每行一帧 16 进制，
%   点 k 实部 [8k+:8]、虚部 [8k+8+:8]，二补码）
% 与 manifest.json（用例说明 + SHA-256）。

if nargin < 2
    out_dir = cfg.rtl_vectors_dir;
end
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
rng(cfg.rng_seed, 'twister');
cases = struct('name', {}, 'desc', {}, 'file_in', {}, 'file_exp', {}, ...
    'sha_in', {}, 'sha_exp', {}, 'n_frames', {}, 'saturations', {});
rng_seed_backup = cfg.rng_seed;

for N = [32, 64]
    % ---- 用例定义 ----
    defs = {
        'impulse0',  '冲激 e0',                       @() case_impulse(N, 1)
        'impulsel',  '末位冲激',                       @() case_impulse(N, N)
        'constant',  '常数 100(1+1j)',                 @() (100 * ones(N,1) + 1j * 100 * ones(N,1))
        'toneq',     '1/4 频点音 幅90',                @() case_tone(N)
        'random',    '均匀随机整数',                    @() case_random(N, 2)
        'extreme',   '极值 +127/-128',                 @() case_extreme(N)
    };
    frames_per_case = 8;   % 每用例 8 帧（连续帧测试用），random/extreme 每帧不同
    for c = 1:size(defs, 1)
        name = defs{c, 1};
        base = defs{c, 3}();
        Xin = zeros(N, frames_per_case);
        for f = 1:frames_per_case
            if strcmp(name, 'random') || strcmp(name, 'extreme')
                switch name
                    case 'random'
                        Xin(:, f) = randi([-100 100], N, 1) + 1j*randi([-100 100], N, 1);
                    case 'extreme'
                        x0 = 127 * (2 * (randi([0 1], N, 1) > 0.5) - 1);
                        x0(randi([1 N], 1)) = -128;
                        Xin(:, f) = x0;
                end
            else
                Xin(:, f) = base;
            end
        end
        Xin = int_complex(round(Xin));
        % 期望输出（逐帧定点模型）
        Xexp = zeros(N, frames_per_case);
        sat_total = 0;
        for f = 1:frames_per_case
            [Xexp(:, f), st] = dspcma.fixedpoint.fft_fixed_model(Xin(:, f), N);
            sat_total = sat_total + sum(st.stage_saturate) + st.final_saturate;
        end
        f_in = fullfile(out_dir, sprintf('fft%d_in_%s.mem', N, name));
        f_exp = fullfile(out_dir, sprintf('fft%d_exp_%s.mem', N, name));
        write_frames(f_in, Xin, N);
        write_frames(f_exp, Xexp, N);
        cases(end+1) = struct('name', sprintf('fft%d_%s', N, name), ...
            'desc', sprintf('N=%d %s', N, defs{c, 2}), ...
            'file_in', f_in, 'file_exp', f_exp, ...
            'sha_in', file_sha(f_in), 'sha_exp', file_sha(f_exp), ...
            'n_frames', frames_per_case, 'saturations', sat_total); %#ok<AGROW>
        fprintf('  fft%d_%s: %d 帧, 饱和 %d 次\n', N, name, frames_per_case, sat_total);
    end
end

manifestPath = fullfile(out_dir, 'manifest.json');
man = struct('generator', 'matlab/+dspcma/+fixedpoint/gen_fft_vectors.m', ...
    'rng_seed', rng_seed_backup, 'model', 'fft_fixed_model (RTL 逐位口径)', ...
    'format', '每行一帧, 点k: 实部[8k+:8] 虚部[8k+8+:8] 二补码 hex', ...
    'cases', cases);
dspcma.io.save_json(manifestPath, man);
fprintf('向量清单: %s\n', manifestPath);
end

function x = int_complex(v)
% 整数化并限幅到 8 bit
re = round(real(v)); im = round(imag(v));
re = min(max(re, -128), 127);
im = min(max(im, -128), 127);
x = re + 1j * im;
end

function x = case_impulse(N, pos)
x = zeros(N, 1); x(pos) = 127;
end

function x = case_tone(N)
k = (0:N-1).';
x = round(90 * exp(1j * 2 * pi * k * (N/4) / N));
end

function x = case_random(N, seed_mult) %#ok<INUSD>
x = randi([-100 100], N, 1) + 1j * randi([-100 100], N, 1);
end

function x = case_extreme(N)
x = 127 * ones(N, 1);
x(1) = -128;
x(floor(N/2)) = -128;
end

function write_frames(path, X, N)
% 写 .mem: 每行一帧, 2N 个字节域 (实部/虚部交替), 二补码 hex
fid = fopen(path, 'w');
if fid == -1
    error('DSPCMA:fixedpoint:cannotOpen', '无法打开 %s', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
for f = 1:size(X, 2)
    parts = cell(N * 2, 1);
    for k = 0:N-1
        re = round(real(X(k+1, f)));
        im = round(imag(X(k+1, f)));
        parts{2*k+1} = sprintf('%02x', bitand(uint8(typecast(int8(re), 'uint8')), 255));
        parts{2*k+2} = sprintf('%02x', bitand(uint8(typecast(int8(im), 'uint8')), 255));
    end
    fprintf(fid, '%s\n', strjoin(parts, ''));
end
end

function h = file_sha(path)
java_sha = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(path, 'rb');
if fid == -1
    error('DSPCMA:fixedpoint:cannotOpen', '无法打开 %s', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
while true
    b = fread(fid, 2^20, 'uint8=>uint8');
    if isempty(b)
        break;
    end
    java_sha.update(b);
end
d = typecast(java_sha.digest(), 'uint8');
h = sprintf('%02x', d);
end
