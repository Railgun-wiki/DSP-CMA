function cfg = default_config()
%DEFAULT_CONFIG 工程唯一默认参数来源。
%
% 返回结构体 cfg，集中管理随机种子、数据路径、算法参数与评估口径。
% 所有正式实验从本文件取默认参数；修改默认值必须记录原因与新旧值。
%
% 路径以本文件位置为基准定位仓库根目录，不依赖当前工作目录。

this_file = mfilename('fullpath');
repo_root = fileparts(fileparts(fileparts(this_file)));

% ---------- 随机与复现 ----------
cfg.rng_seed = 20261114;                 % 固定随机种子，'twister'
cfg.timezone = 'Asia/Singapore';         % 面向用户的时间戳时区

% ---------- 数据 ----------
cfg.data_mat = fullfile(repo_root, 'data', 'reference', 'TD_TRdata.mat');
cfg.reference_zip = fullfile(repo_root, 'docs', 'requirement', '大作业matlab.zip');

% ---------- 时域/频域 CMA 公共参数（与 CMA_reference.m 语义一致） ----------
cfg.seg_len = 32;                        % 每段数据点数
cfg.tap_len = 33;                        % FIR 抽头长度（奇数）
cfg.clk_dly = 1;                         % 抽头更新延迟（时钟拍数，仅承诺 1）
cfg.par_num = 4;                         % 每时钟并行处理的段数（更新组大小）
cfg.step = 2^-8;                         % CMA 步长 mu
cfg.Rx = 2;                              % X 偏振 CMA 半径 R
cfg.Ry = 2;                              % Y 偏振 CMA 半径 R

% ---------- 实验设计 ----------
cfg.tap_sweep = [17 33 65];              % 抽头长度对照实验
cfg.eval_len = 131072;                   % 尾部评估窗长度（精确点数）
cfg.calib_len = 131072;                  % 评估窗之前的独立校准段长度
cfg.ideal_4qam = [1+1j; 1-1j; -1+1j; -1-1j];   % 理想 4QAM 星座（|p| = sqrt(2)）

% ---------- 卷积演示默认信号（B03：用户可指定信号与滤波器） ----------
cfg.conv_demo.signal_len = 1000;
cfg.conv_demo.filter_len = 33;
cfg.conv_demo.block = 128;

% ---------- 输出 ----------
cfg.results_root = fullfile(repo_root, 'results');
cfg.rtl_vectors_dir = fullfile(repo_root, 'rtl', 'tb', 'vectors');
cfg.rtl_tables_file = fullfile(repo_root, 'rtl', 'fft', 'fft_twiddle_tables.vh');
end
