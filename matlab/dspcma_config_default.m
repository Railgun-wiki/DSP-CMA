function cfg = dspcma_config_default()
%DSPCMA_CONFIG_DEFAULT 加载唯一默认配置（测试与运行入口共用）。
%
% 从本文件位置定位 matlab/config/ 并加入路径后调用 default_config，
% 不依赖当前工作目录。

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'config'));
cfg = default_config();
end
