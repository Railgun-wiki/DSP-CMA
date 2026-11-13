function out = test_smoke(cfg)
%TEST_SMOKE 最小冒烟测试：路径、配置与 oracle 基础调用可用。

out.name = 'Smoke';
out.checks = struct('what', {}, 'status', {}, 'value', {});
cfg = dspcma_config_default();
add('配置加载', isfield(cfg, 'tap_len') && cfg.tap_len == 33, sprintf('tap_len=%d', cfg.tap_len));
X = dspcma.fft.my_fft([1 0 0 0 0 0 0 0].');
add('my_fft 冲激', isequal(X, ones(8, 1)), 'ones(8,1)');
x = dspcma.fft.my_ifft(ones(8, 1));
add('my_ifft 常数', max(abs(x - [1; zeros(7, 1)])) < 1e-12, 'delta(8,1)');
W = dspcma.fft.twiddle_table(4);
add('twiddle 基础', isequal(W, [1; -1j; -1; 1j]), 'M=4 精确');
e = dspcma.metrics.rel_l2([1 2 3].', [1 2 4].');
add('rel_l2', abs(e - 1/sqrt(21)) < 1e-12, sprintf('%.6f', e));

    function add(what, ok, val)
        if ok
            st = 'PASS';
        else
            st = 'FAIL';
        end
        out.checks(end+1) = struct('what', what, 'status', st, 'value', val); %#ok<AGROW>
    end
setup_ok = out;
end
