function out = load_json(path)
%LOAD_JSON 读取 UTF-8 JSON 文件 (证据完整性断言用)。
fid = fopen(path, 'r', 'n', 'UTF-8');
if fid == -1
    error('DSPCMA:io:cannotOpen', '无法打开 %s', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
raw = fread(fid, inf, 'uint8=>uint8');
out = jsondecode(char(raw).');   % 转行向量 (jsondecode 拒绝列)
end
