function out = export_all(cfg, out_dir)
%EXPORT_ALL 定点模型总导出（run_all 第 4 步）。
%
% 1) 生成 RTL 测试向量（32/64 点全部用例）与 manifest;
% 2) 生成 RTL 旋转因子表 include;
% 3) 浮点对照: 各用例 Y_fixed vs my_fft(X)/N 的逐点最大误差;
% 4) 返回摘要（供 run_all 汇总与 docs/validation.md 引用）。

if nargin < 2
    out_dir = cfg.results_root;
end
cases = dspcma.fixedpoint.gen_fft_vectors(cfg, cfg.rtl_vectors_dir);
tbl = dspcma.fixedpoint.gen_rtl_tables(cfg);

% 浮点对照
rng(cfg.rng_seed, 'twister');
cmp = struct('name', {}, 'max_abs_err', {}, 'max_rel_err', {});
for k = 1:numel(cases)
    [Nstr, name] = parse_case(cases(k).name);   % fft32_random -> 32, random
    N = Nstr;
    X = read_frames(cases(k).file_in, N);
    Yexp = read_frames(cases(k).file_exp, N);
    err_max = 0;
    rel_max = 0;
    for f = 1:size(X, 2)
        Xf = double(X(:, f));
        Yf = dspcma.fft.my_fft(Xf) / N;
        Ye = double(Yexp(:, f));
        e = max(abs(Ye - Yf));
        err_max = max(err_max, e);
        ny = max(abs(Yf));
        if ny > 0
            rel_max = max(rel_max, e / ny);
        end
    end
    cmp(end+1) = struct('name', cases(k).name, ...
        'max_abs_err', err_max, 'max_rel_err', rel_max); %#ok<AGROW>
end

out.cases = cases;
out.twiddle_table = tbl;
out.float_compare = cmp;
max_abs = max([cmp.max_abs_err]);
out.max_abs_err_all = max_abs;
dspcma.io.save_json(fullfile(out_dir, 'metrics_fixedpoint.json'), out);
fprintf('定点导出: %d 用例, 向量目录 %s, 旋转因子表 %s\n', ...
    numel(cases), cfg.rtl_vectors_dir, tbl.file);
fprintf('定点 vs 浮点最大绝对误差: %.3f LSB\n', max_abs);
end

function [N, name] = parse_case(cname)
% fft32_random -> N=32, name='random'
tok = regexp(cname, '^fft(\d+)_(.+)$', 'tokens', 'once');
N = str2double(tok{1});
name = tok{2};
end

function X = read_frames(path, N)
% 读 .mem（每行一帧, 2N 字节域, 实/虚交替, 二补码）
fid = fopen(path, 'r');
if fid == -1
    error('DSPCMA:fixedpoint:cannotOpen', '无法打开 %s', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
rows = {};
while true
    ln = fgetl(fid);
    if ~ischar(ln)
        break;
    end
    rows{end+1} = ln; %#ok<AGROW>
end
nf = numel(rows);
X = zeros(N, nf);
for f = 1:nf
    toks = regexp(rows{f}, '[0-9a-f]{2}', 'match');
    if numel(toks) ~= 2*N
        error('DSPCMA:fixedpoint:badVector', '%s 第 %d 帧域数 %d != %d', path, f, numel(toks), 2*N);
    end
    for k = 0:N-1
        bre = uint8(hex2dec(toks{2*k+1}));
        bim = uint8(hex2dec(toks{2*k+2}));
        X(k+1, f) = double(typecast(bre, 'int8')) + 1j * double(typecast(bim, 'int8'));
    end
end
end
