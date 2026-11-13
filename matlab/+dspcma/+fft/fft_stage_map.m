function map = fft_stage_map(N)
%FFT_STAGE_MAP 返回 N 点 DIT FFT 各级蝶形的索引结构（B01 结构说明用）。
%
% map{s+1} 为第 s 级（s = 0 起）结构体:
%   .M            -- 该级子 DFT 块长（蝶形跨距 2^s，块长 2^(s+1)）。
%   .pairs        -- (N/2)×2 的 1-based 元素索引对 [top bot]，自上而下
%                    按块内位置枚举，与 RTL 中同级的蝶形实例一一对应。
%   .tw_exponent  -- (N/2)×1 每个蝶形的旋转因子幂指数 m（W_M^m）。
%   .special      -- (N/2)×1 特殊因子标记: 1=+1, 2=-1, 3=-1j, 4=+1j, 0=普通。
%
% 与 my_fft 的逐级循环一致；RTL（fft_radix2_core.v）按同一映射布线。
% 仅支持 N 为 2 的幂且 N >= 2。

if ~isscalar(N) || N < 2 || bitand(N, N-1) ~= 0
    error('DSPCMA:fft:badLength', 'N 必须为 >= 2 的 2 的幂');
end
stages = log2(N);
map = struct('M', {}, 'pairs', {}, 'tw_exponent', {}, 'special', {});
for s = 0:stages-1
    half = 2^s;
    M = 2 * half;
    pairs = zeros(N/2, 2);
    expo = zeros(N/2, 1);
    row = 0;
    for start = 1:M:N
        for j = 1:half
            row = row + 1;
            pairs(row, :) = [start + j - 1, start + j - 1 + half];
            expo(row) = j - 1;
        end
    end
    special = zeros(N/2, 1);
    for r = 1:N/2
        m = expo(r);
        if m == 0
            special(r) = 1;                    % +1
        elseif M >= 4 && m == M/4
            special(r) = 3;                    % -1j
        elseif m == M/2
            special(r) = 2;                    % -1
        elseif M >= 4 && m == 3*M/4
            special(r) = 4;                    % +1j
        end
    end
    map(s+1).M = M;
    map(s+1).pairs = pairs;
    map(s+1).tw_exponent = expo;
    map(s+1).special = special;
end
end
