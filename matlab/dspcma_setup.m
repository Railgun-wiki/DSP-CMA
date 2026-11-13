function dspcma_setup()
%DSPCMA_SETUP 将工程所有 MATLAB 目录加入路径（幂等）。
%
% 从本文件位置定位仓库，加入 matlab/、config/、tests/。运行入口、
% 测试与脚本统一调用本函数定位仓库，不依赖当前工作目录。

here = fileparts(mfilename('fullpath'));
addpath(here);
addpath(fullfile(here, 'config'));
addpath(fullfile(here, 'tests'));
end
