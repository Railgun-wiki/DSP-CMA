function meta = save_run_metadata(cfg, out_dir, run_id, extra)
%SAVE_RUN_METADATA 写入运行元数据（配置、种子、工具版本、数据哈希）。

meta.run_id = run_id;
dt = datetime('now', 'TimeZone', cfg.timezone);
meta.time_local = char(dt, 'yyyy-MM-dd''T''HH:mm:ss');
meta.timezone = cfg.timezone;
meta.rng_seed = cfg.rng_seed;
meta.matlab_version = version;
meta.platform = computer;
meta.data_mat = cfg.data_mat;
D = dir(cfg.data_mat);
if ~isempty(D)
    meta.data_bytes = D.bytes;
    try
        [~, ~, mdm] = dspcma.io.load_tdtr(cfg);
        meta.data_sha256 = mdm.sha256;
    catch
        meta.data_sha256 = 'unavailable';
    end
end
meta.code_version = detect_git();
meta.mode = 'full';
if isfield(cfg, 'run_mode')
    meta.mode = cfg.run_mode;
end
if nargin >= 4
    fn = fieldnames(extra);
    for k = 1:numel(fn)
        meta.(fn{k}) = extra.(fn{k});
    end
end
dspcma.io.save_json(fullfile(out_dir, 'run_meta.json'), meta);
end

function v = detect_git()
v = 'no-git';
% 以本文件位置定位仓库 (F05 整改: 不依赖当前工作目录)
repo = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
[st, out] = system(sprintf('git -C "%s" rev-parse --short HEAD 2>/dev/null', repo));
if st == 0 && ~isempty(out)
    v = strtrim(out);
end
end
