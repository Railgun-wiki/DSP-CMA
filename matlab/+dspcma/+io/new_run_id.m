function [run_id, out_dir] = new_run_id(cfg, tag)
%NEW_RUN_ID 生成结果运行标识与输出目录。
%
% run_id = <YYYYMMDD'T'HHMMSS>_<tag>（Asia/Singapore 本地时间），
% out_dir = results/<run_id>。目录已存在时追加序号避免覆盖。

dt = datetime('now', 'TimeZone', cfg.timezone);
run_id = sprintf('%s_%s', char(dt, 'yyyyMMdd''T''HHmmss'), tag);
out_dir = fullfile(cfg.results_root, run_id);
k = 1;
while exist(out_dir, 'dir')
    k = k + 1;
    run_id = sprintf('%s_%s_%d', char(dt, 'yyyyMMdd''T''HHmmss'), tag, k);
    out_dir = fullfile(cfg.results_root, run_id);
end
mkdir(out_dir);
end
