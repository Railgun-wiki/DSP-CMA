function [s, n_ok, n_total] = summarize_checks(out)
%SUMMARIZE_CHECKS 汇总单个测试的检查项状态。
%
% out 为含 .checks 结构体数组的测试结果；返回:
%   s       -- 总状态字符串 'PASS' / 'FAIL'。
%   n_ok    -- 通过的检查项数。
%   n_total -- 检查项总数。

checks = out.checks;
n_total = numel(checks);
n_ok = 0;
for k = 1:n_total
    if strcmpi(checks(k).status, 'PASS')
        n_ok = n_ok + 1;
    end
end
if n_ok == n_total
    s = 'PASS';
else
    s = 'FAIL';
end
end
