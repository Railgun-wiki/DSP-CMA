function summary = run_tests(test_names, cfg)
%RUN_TESTS 独立单元测试回归入口。
%
% summary = run_tests()                运行全部测试（默认配置）。
% summary = run_tests({'test_fft'})    仅运行指定测试。
%
% 每个测试函数返回含 .name 与 .checks 的结构体；本函数汇总为
% PASS/FAIL 并打印明细。失败不抛出异常，由调用方（run_all）决定
% 是否中止。

if nargin < 2
    cfg = dspcma_config_default();
end
if nargin < 1 || isempty(test_names)
    test_names = { ...
        'test_smoke', 'test_fft', 'test_twiddle', 'test_convolution', ...
        'test_evm', 'test_cma_kernel', 'test_cma_reference_parity', ...
        'test_fixedpoint' };
end

summary.tests = struct('name', {}, 'status', {}, 'n_ok', {}, 'n_total', {}, 'checks', {});
n_pass = 0;
fprintf('================ 单元测试 ================\n');
for t = 1:numel(test_names)
    fname = test_names{t};
    try
        out = feval(fname, cfg);
        [st, n_ok, n_total] = summarize_checks(out);
    catch err
        out = struct('name', fname, 'checks', []);
        st = 'FAIL';
        n_ok = 0;
        n_total = 1;
        out.crash = sprintf('%s: %s', err.identifier, err.message);
    end
    summary.tests(end+1) = struct('name', out.name, 'status', st, ...
        'n_ok', n_ok, 'n_total', n_total, 'checks', out.checks); %#ok<AGROW>
    if strcmp(st, 'PASS')
        n_pass = n_pass + 1;
    end
    fprintf('[%s] %-16s %d/%d\n', st, out.name, n_ok, n_total);
    if isfield(out, 'crash')
        fprintf('      崩溃: %s\n', out.crash);
    end
    for c = 1:numel(out.checks)
        mark = '  ';
        if ~strcmp(out.checks(c).status, 'PASS')
            mark = '!!';
        end
        fprintf('   %s %-28s %-4s %s\n', mark, out.checks(c).what, ...
            out.checks(c).status, out.checks(c).value);
    end
end
summary.n_pass = n_pass;
summary.n_total = numel(test_names);
fprintf('=========================================\n');
fprintf('测试汇总: %d/%d PASS\n', n_pass, numel(test_names));
end
