function save_json(path, data)
%SAVE_JSON 将结构体/数组写为 UTF-8 JSON 文件。
%
% 支持标量、向量、元胞、嵌套结构体；复数拆为 {re, im}。
% 目录不存在时自动创建。写入失败抛出错误（不吞异常）。

if nargin < 2
    error('DSPCMA:io:badArgs', 'save_json 需要路径与数据');
end
[d, ~] = fileparts(path);
if ~isempty(d) && ~exist(d, 'dir')
    mkdir(d);
end
txt = jsonencode(with_subs(data));
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid == -1
    error('DSPCMA:io:cannotOpen', '无法打开 %s 写入', path);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', txt);
end

function out = with_subs(v)
%WITH_SUBS 递归归一化: 复数转 {re, im}; 结构体数组转 cell of structs
% (F03 整改: 旧实现只读 v(1), 静默丢弃数组元素); 元胞逐元素递归。
if isstruct(v)
    n = numel(v);
    if n > 1
        out = cell(1, n);
        for k = 1:n
            out{k} = with_subs(v(k));
        end
    else
        out = struct();
        fn = fieldnames(v);
        for k = 1:numel(fn)
            out.(fn{k}) = with_subs(v(1).(fn{k}));
        end
    end
elseif iscell(v)
    out = cell(size(v));
    for k = 1:numel(v)
        out{k} = with_subs(v{k});
    end
elseif isnumeric(v) && ~isreal(v)
    out = struct('re', real(v), 'im', imag(v));
else
    out = v;
end
end
