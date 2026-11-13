function info = gen_rtl_tables(cfg)
%GEN_RTL_TABLES 生成 RTL 旋转因子查找表 include 文件。
%
% 输出 rtl/fft/fft_twiddle_tables.vh: Verilog-2001 函数
%   fft_tw32(stage, m) / fft_tw64(stage, m)
% 返回 {spec, w_re, w_im}（spec: 0 普通 / 1=+1 / 2=-1 / 3=-1j / 4=+1j;
% w_re/w_im 为 Q15 16 bit 二补码，仅 spec==0 时有效）。
% 表值由 twiddle_q15 生成并经对称性校验；文件由本脚本重建，不手改。

lines = {};
lines{end+1} = '// 自动生成: matlab/+dspcma/+fixedpoint/gen_rtl_tables.m（勿手改）';
lines{end+1} = '// 旋转因子: Q15 16 bit, round(w*2^15); spec: 0 普通, 1=+1, 2=-1, 3=-1j, 4=+1j';
lines{end+1} = '// stage = 0..log2(N)-1, m = 0..2^stage-1（块长 M = 2^(stage+1) 的幂次）';
lines{end+1} = '`ifndef FFT_TWIDDLE_TABLES_VH';
lines{end+1} = '`define FFT_TWIDDLE_TABLES_VH';
for N = [32, 64]
    lines{end+1} = sprintf('');
    lines{end+1} = sprintf('function [33:0] fft_tw%d(input integer stage, input integer m);', N);
    lines{end+1} = '    reg signed [15:0] w_re, w_im;';
    lines{end+1} = '    reg [1:0] spec;';
    lines{end+1} = '    begin';
    lines{end+1} = '        spec = 2''d0; w_re = 16''sd0; w_im = 16''sd0;';
    lines{end+1} = '        case (stage)';
    stages = log2(N);
    for s = 0:stages-1
        M = 2^(s+1);
        lines{end+1} = sprintf('            %0d: begin', s);
        lines{end+1} = sprintf('                case (m)');
        for m = 0:M-1
            [W, spec] = dspcma.fixedpoint.twiddle_q15(M, m);
            if spec == 0
                lines{end+1} = sprintf('                    %0d: begin spec = 2''d0; w_re = 16''sd%0d; w_im = 16''sd%0d; end', ...
                    m, W(1), W(2));
            else
                lines{end+1} = sprintf('                    %0d: spec = 2''d%0d;', m, spec);
            end
        end
        lines{end+1} = sprintf('                    default: spec = 2''d0;');
        lines{end+1} = sprintf('                endcase');
        lines{end+1} = sprintf('            end');
    end
    lines{end+1} = sprintf('            default: begin spec = 2''d0; end');
    lines{end+1} = sprintf('        endcase');
    lines{end+1} = sprintf('        fft_tw%d = {spec, w_re, w_im};', N);
    lines{end+1} = sprintf('    end');
    lines{end+1} = sprintf('endfunction');
end
lines{end+1} = '`endif';

fid = fopen(cfg.rtl_tables_file, 'w');
if fid == -1
    error('DSPCMA:fixedpoint:cannotOpen', '无法打开 %s', cfg.rtl_tables_file);
end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%s\n', lines{:});
info.file = cfg.rtl_tables_file;
info.sha256 = sha_of(cfg.rtl_tables_file);
end

function h = sha_of(path)
java_sha = java.security.MessageDigest.getInstance('SHA-256');
fid = fopen(path, 'rb');
if fid == -1
    error('DSPCMA:fixedpoint:cannotOpen', '无法打开 %s', path);
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
