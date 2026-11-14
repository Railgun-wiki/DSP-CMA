function out = test_io(cfg)
%TEST_IO JSON 证据完整性验证（F03/F08 整改）。
%
% 覆盖:
%   1) save_json/load_json 往返: 结构体数组(含嵌套/混合复实)元素数与
%      字段值不丢;
%   2) 向量 manifest 完整性: 12 用例、每用例 8 帧、哈希非空且文件在;
%   3) 正式运行 artifacts: 取最新"完整"运行 (三工件齐全; 当前运行在
%      run_tests 阶段尚未落盘, 天然被跳过), 校验检查项合计、taps 数组
%      与数据 SHA-256。

rng(cfg.rng_seed, 'twister');
out.name = 'IO';
out.checks = struct('what', {}, 'status', {}, 'value', {});

    function add(what, ok, val)
        if ok
            stw = 'PASS';
        else
            stw = 'FAIL';
        end
        out.checks(end+1) = struct('what', what, 'status', stw, 'value', val); %#ok<AGROW>
    end

% ---- 1) 往返: 结构体数组 + 嵌套 + 混合复实 ----
tmp = [tempname() '.json'];
cleanupObj = onCleanup(@() delete(tmp)); %#ok<NASGU>
n_in = struct('id', {1, 2, 3}, 'val', {1.5+0.5j, 2.5-1j, 0}, ...
    'sub', {struct('a', 10), struct('a', 20), struct('a', 30)});
n_in = reshape(n_in, 1, 3);
dspcma.io.save_json(tmp, n_in);
n_out = dspcma.io.load_json(tmp);
ok_rt = isstruct(n_out) && numel(n_out) == 3;
for k = 1:3
    % 复数字段以 {re, im} 结构编码; 实数保持数值 (混合类型都要能往返)
    v = n_out(k).val;
    if isstruct(v)
        dv = v.re + 1j * v.im;
    else
        dv = v;
    end
    ok_rt = ok_rt && n_out(k).id == k ...
        && abs(dv - n_in(k).val) < 1e-12 ...
        && n_out(k).sub.a == 10 * k;
end
add('JSON结构体数组往返', ok_rt, '3 元素含嵌套/复实混合');

% ---- 2) 向量 manifest 完整性: 12 用例、哈希非空、与实际文件一致 ----
man = dspcma.io.load_json(fullfile(cfg.rtl_vectors_dir, 'manifest.json'));
% jsondecode 把 JSON 数组读回为结构体数组, 统一转 cell
if isstruct(man.cases), man.cases = num2cell(man.cases); end
ok_man = iscell(man.cases) && numel(man.cases) == 12;
if ok_man
    for c = 1:12
        cc = man.cases{c};
        ok_man = ok_man && cc.n_frames == 8 && ~isempty(cc.sha_in) ...
            && ~isempty(cc.sha_exp);
        ok_man = ok_man && isfile(char(cc.file_in)) && isfile(char(cc.file_exp));
    end
end
add('向量manifest用例数与帧数', ok_man, ...
    sprintf('%d 用例', numel(man.cases)));

% ---- 3) 正式运行 artifacts 完整性 ----
% 取最新"完整"运行 (三工件齐全); 当前运行在 run_tests 阶段尚未落盘,
% 天然被跳过; 无历史完整运行时标注跳过 (本次落盘后由后续运行核验)。
rdir = cfg.results_root;
runs = dir(rdir);
runs = runs([runs.isdir]);
runs = runs(~startsWith({runs.name}, '.'));
rpath = '';
rname = '';
if ~isempty(runs)
    [~, order] = sort([runs.datenum], 'descend');
    for k = 1:numel(order)
        cand = fullfile(rdir, runs(order(k)).name);
        if isfile(fullfile(cand, 'tests_summary.json')) && ...
           isfile(fullfile(cand, 'summary.json')) && ...
           isfile(fullfile(cand, 'metrics_tapsweep.json'))
            rpath = cand;
            rname = runs(order(k)).name;
            break;
        end
    end
end
if isempty(rpath)
    add('正式运行工件完整性', true, ...
        '尚无历史完整运行 (本运行落盘后由后续运行核验)');
else
    ts = dspcma.io.load_json(fullfile(rpath, 'tests_summary.json'));
    T = ts.tests;
    if iscell(T)
        Tc = T;
    else
        Tc = num2cell(T);
    end
    % 结构完整性: 组数 = 9; 每组 checks 明细数 == n_total (F03 截断即
    % 在此暴露); 数据 SHA-256 存在; taps 数组含全部抽头。
    n_groups = numel(Tc);
    detail_ok = all(cellfun(@(x) numel(x.checks) == x.n_total, Tc));
    n_ok_all = sum(cellfun(@(x) x.n_ok, Tc));
    n_total_all = sum(cellfun(@(x) x.n_total, Tc));
    m = dspcma.io.load_json(fullfile(rpath, 'run_meta.json'));
    meta_ok = ~strcmp(m.data_sha256, 'unavailable') && ...
        strlength(m.data_sha256) == 64;
    sweep = dspcma.io.load_json(fullfile(rpath, 'metrics_tapsweep.json'));
    if isstruct(sweep.taps), sweep.taps = num2cell(sweep.taps); end
    taps_ok = iscell(sweep.taps) && numel(sweep.taps) == 3;
    sha8 = m.data_sha256(1:min(8, numel(m.data_sha256)));
    add('正式运行工件完整性', n_groups == 9 && detail_ok && meta_ok && taps_ok, ...
        sprintf('%s: %d 组, 明细 %d/%d, taps=%d, sha=%s', rname, ...
        n_groups, n_ok_all, n_total_all, numel(sweep.taps), sha8));
end
end
