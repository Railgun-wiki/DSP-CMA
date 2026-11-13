function save_figure(fig, path)
%SAVE_FIGURE 无界面批处理保存图片并关闭自身创建的图。
%
% fig 必须是本函数调用方创建的图句柄；保存为 PNG 后关闭该图，
% 不触碰其他打开的图（AGENTS 6.1: 保存后关闭自身创建的图）。

if nargin < 2
    error('DSPCMA:io:badArgs', 'save_figure 需要图句柄与路径');
end
[d, ~] = fileparts(path);
if ~isempty(d) && ~exist(d, 'dir')
    mkdir(d);
end
exportgraphics(fig, path, 'ContentType', 'image');
close(fig);
end
