function out = test_cma_reference_parity(cfg)
%TEST_CMA_REFERENCE_PARITY 与原版参考脚本逐位对照（B05 证据）。
%
% 在受控环境运行 data/reference/CMA_reference.m（原版脚本，含其自带
% 的 clear/绘图），将其 CMAdataX/CMAdataY 与最终抽头 Tap_Matx 同
% cma_time_run 的输出比较。移植版逐样本复刻参考运算次序，预期一致；
% 通过条件: 相对 L2 <= 1e-12。

out.name = 'CMA reference parity';
out.checks = struct('what', {}, 'status', {}, 'value', {});

    function add(what, ok, val)
        if ok
            st = 'PASS';
        else
            st = 'FAIL';
        end
        out.checks(end+1) = struct('what', what, 'status', st, 'value', val); %#ok<AGROW>
    end

figs_before = findobj('Type', 'figure');
datadir = fileparts(cfg.data_mat);
addpath(datadir);   % 供脚本内 load TD_TRdata.mat 使用

% 原版脚本在 base 工作区执行（脚本自带 clear 与图窗，不能在函数
% 工作区内 run；结果变量随后从 base 取回）
script_path = fullfile(datadir, 'CMA_reference.m');
evalin('base', sprintf('run(''%s'');', script_path));
ref_x = evalin('base', 'SigX_out.''');      %#ok<NODEF> 全量输出（行向量）
ref_y = evalin('base', 'SigY_out.''');      %#ok<NODEF>
ref_taps = evalin('base', 'Tap_Matx'); %#ok<NODEF>
ref_tail_x = evalin('base', 'CMAdataX');  %#ok<NODEF> 参考尾部窗(131073 点)
evalin('base', 'clear RTdataX RTdataY SigX_in SigY_in SigX_out SigY_out errx_vec erry_vec SigX_in_padded SigY_in_padded CMAdataX CMAdataY Tap_Matx final_xx final_yy final_xy final_yx errx_reshaped erry_reshaped xx yy xy yx xx_accu yy_accu xy_accu yx_accu seg_len tap_len clk_dly par_num step Rx Ry seg_num clk_num total_len center_tap current_idx padded_idx input_x input_y k clk_pos update_clk_pos i');

figs_after = findobj('Type', 'figure');
for f = setdiff(figs_after(:), figs_before(:)).'
    delete(f);   % 仅关闭本次运行创建的图
end

% 函数化时域基线（与参考同参数）
runcfg = cfg;
runcfg.record_taps = false;
D = load(cfg.data_mat);
xx_ = dspcma.equalizer.cma_time_run(complex(D.RTdataX(:)), complex(D.RTdataY(:)), runcfg);

e_x = dspcma.metrics.rel_l2(xx_.zx(:).', ref_x);
e_y = dspcma.metrics.rel_l2(xx_.zy(:).', ref_y);
add('输出 X 与参考一致', e_x <= 1e-12, sprintf('%.2e', e_x));
add('输出 Y 与参考一致', e_y <= 1e-12, sprintf('%.2e', e_y));

% 参考尾部窗 end-131072:end（131073 点）与函数化输出的对应窗一致
e_tail = dspcma.metrics.rel_l2(xx_.zx(end - numel(ref_tail_x) + 1:end).', ref_tail_x);
add('参考尾部窗一致', e_tail <= 1e-12, sprintf('%.2e', e_tail));

% Tap_Matx = [[final_xx; final_xy] [final_yx; final_yy]]（tap_len*2 × 2）
tl = numel(xx_.final.xx);
tap_ref_xx = ref_taps(1:tl, 1);
tap_ref_xy = ref_taps(tl+1:2*tl, 1);
tap_ref_yx = ref_taps(1:tl, 2);
tap_ref_yy = ref_taps(tl+1:2*tl, 2);
e_t = max([max(abs(xx_.final.xx - tap_ref_xx)), max(abs(xx_.final.xy - tap_ref_xy)), ...
           max(abs(xx_.final.yx - tap_ref_yx)), max(abs(xx_.final.yy - tap_ref_yy))]);
add('最终抽头与参考一致', e_t == 0, sprintf('max_abs=%.2e', e_t));
add('输出长度一致', numel(xx_.zx) == numel(ref_x), sprintf('%d vs %d', numel(xx_.zx), numel(ref_x)));
add('无数据丢弃', xx_.dropped == 0, sprintf('dropped=%d', xx_.dropped));
end
