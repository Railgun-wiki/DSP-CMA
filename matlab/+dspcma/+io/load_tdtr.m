function [x, y, meta] = load_tdtr(cfg)
%LOAD_TDTR 载入并校验实验数据（TD_TRdata.mat: RTdataX / RTdataY）。
%
% 内部统一转为复数列向量。校验: 字段存在、长度一致、有限值。
% meta 返回数据文件字节数与 SHA-256（证据链用）。

if ~exist(cfg.data_mat, 'file')
    error('DSPCMA:io:dataMissing', '数据文件不存在: %s（先运行 scripts/prepare_data.py）', cfg.data_mat);
end
S = load(cfg.data_mat);
if ~isfield(S, 'RTdataX') || ~isfield(S, 'RTdataY')
    error('DSPCMA:io:dataFields', '数据缺少 RTdataX/RTdataY 字段');
end
x = complex(S.RTdataX(:));
y = complex(S.RTdataY(:));
if numel(x) ~= numel(y)
    error('DSPCMA:io:dataShape', 'RTdataX 与 RTdataY 长度不同');
end
if any(~isfinite(x)) || any(~isfinite(y))
    error('DSPCMA:io:dataNotFinite', '数据含 NaN/Inf');
end
meta.file = cfg.data_mat;
meta.bytes = dir(cfg.data_mat).bytes;
meta.sha256 = file_sha256(cfg.data_mat);
end

function h = file_sha256(path)
%FILE_SHA256 流式计算文件 SHA-256（不依赖外部工具）。
java_sha = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(path, 'rb');
if fid == -1
    error('DSPCMA:io:cannotOpen', '无法打开 %s', path);
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
