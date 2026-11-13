// 自动生成: matlab/+dspcma/+fixedpoint/gen_rtl_tables.m（勿手改）
// 旋转因子: Q15 16 bit, round(w*2^15); spec: 0 普通, 1=+1, 2=-1, 3=-1j, 4=+1j
// stage = 0..log2(N)-1, m = 0..2^stage-1（块长 M = 2^(stage+1) 的幂次）
`ifndef FFT_TWIDDLE_TABLES_VH
`define FFT_TWIDDLE_TABLES_VH

function [34:0] fft_tw32(input integer stage, input integer m);
    reg signed [15:0] w_re, w_im;
    reg [2:0] spec;
    begin
        spec = 3'd0; w_re = 16'sd0; w_im = 16'sd0;
        case (stage)
            0: begin
                case (m)
                    0: spec = 3'd1;
                    1: spec = 3'd2;
                    default: spec = 3'd0;
                endcase
            end
            1: begin
                case (m)
                    0: spec = 3'd1;
                    1: spec = 3'd3;
                    2: spec = 3'd2;
                    3: spec = 3'd4;
                    default: spec = 3'd0;
                endcase
            end
            2: begin
                case (m)
                    0: spec = 3'd1;
                    1: begin spec = 3'd0; w_re = 16'sd23170; w_im = -16'sd23170; end
                    2: spec = 3'd3;
                    3: begin spec = 3'd0; w_re = -16'sd23170; w_im = -16'sd23170; end
                    4: spec = 3'd2;
                    5: begin spec = 3'd0; w_re = -16'sd23170; w_im = 16'sd23170; end
                    6: spec = 3'd4;
                    7: begin spec = 3'd0; w_re = 16'sd23170; w_im = 16'sd23170; end
                    default: spec = 3'd0;
                endcase
            end
            3: begin
                case (m)
                    0: spec = 3'd1;
                    1: begin spec = 3'd0; w_re = 16'sd30274; w_im = -16'sd12540; end
                    2: begin spec = 3'd0; w_re = 16'sd23170; w_im = -16'sd23170; end
                    3: begin spec = 3'd0; w_re = 16'sd12540; w_im = -16'sd30274; end
                    4: spec = 3'd3;
                    5: begin spec = 3'd0; w_re = -16'sd12540; w_im = -16'sd30274; end
                    6: begin spec = 3'd0; w_re = -16'sd23170; w_im = -16'sd23170; end
                    7: begin spec = 3'd0; w_re = -16'sd30274; w_im = -16'sd12540; end
                    8: spec = 3'd2;
                    9: begin spec = 3'd0; w_re = -16'sd30274; w_im = 16'sd12540; end
                    10: begin spec = 3'd0; w_re = -16'sd23170; w_im = 16'sd23170; end
                    11: begin spec = 3'd0; w_re = -16'sd12540; w_im = 16'sd30274; end
                    12: spec = 3'd4;
                    13: begin spec = 3'd0; w_re = 16'sd12540; w_im = 16'sd30274; end
                    14: begin spec = 3'd0; w_re = 16'sd23170; w_im = 16'sd23170; end
                    15: begin spec = 3'd0; w_re = 16'sd30274; w_im = 16'sd12540; end
                    default: spec = 3'd0;
                endcase
            end
            4: begin
                case (m)
                    0: spec = 3'd1;
                    1: begin spec = 3'd0; w_re = 16'sd32138; w_im = -16'sd6393; end
                    2: begin spec = 3'd0; w_re = 16'sd30274; w_im = -16'sd12540; end
                    3: begin spec = 3'd0; w_re = 16'sd27246; w_im = -16'sd18205; end
                    4: begin spec = 3'd0; w_re = 16'sd23170; w_im = -16'sd23170; end
                    5: begin spec = 3'd0; w_re = 16'sd18205; w_im = -16'sd27246; end
                    6: begin spec = 3'd0; w_re = 16'sd12540; w_im = -16'sd30274; end
                    7: begin spec = 3'd0; w_re = 16'sd6393; w_im = -16'sd32138; end
                    8: spec = 3'd3;
                    9: begin spec = 3'd0; w_re = -16'sd6393; w_im = -16'sd32138; end
                    10: begin spec = 3'd0; w_re = -16'sd12540; w_im = -16'sd30274; end
                    11: begin spec = 3'd0; w_re = -16'sd18205; w_im = -16'sd27246; end
                    12: begin spec = 3'd0; w_re = -16'sd23170; w_im = -16'sd23170; end
                    13: begin spec = 3'd0; w_re = -16'sd27246; w_im = -16'sd18205; end
                    14: begin spec = 3'd0; w_re = -16'sd30274; w_im = -16'sd12540; end
                    15: begin spec = 3'd0; w_re = -16'sd32138; w_im = -16'sd6393; end
                    16: spec = 3'd2;
                    17: begin spec = 3'd0; w_re = -16'sd32138; w_im = 16'sd6393; end
                    18: begin spec = 3'd0; w_re = -16'sd30274; w_im = 16'sd12540; end
                    19: begin spec = 3'd0; w_re = -16'sd27246; w_im = 16'sd18205; end
                    20: begin spec = 3'd0; w_re = -16'sd23170; w_im = 16'sd23170; end
                    21: begin spec = 3'd0; w_re = -16'sd18205; w_im = 16'sd27246; end
                    22: begin spec = 3'd0; w_re = -16'sd12540; w_im = 16'sd30274; end
                    23: begin spec = 3'd0; w_re = -16'sd6393; w_im = 16'sd32138; end
                    24: spec = 3'd4;
                    25: begin spec = 3'd0; w_re = 16'sd6393; w_im = 16'sd32138; end
                    26: begin spec = 3'd0; w_re = 16'sd12540; w_im = 16'sd30274; end
                    27: begin spec = 3'd0; w_re = 16'sd18205; w_im = 16'sd27246; end
                    28: begin spec = 3'd0; w_re = 16'sd23170; w_im = 16'sd23170; end
                    29: begin spec = 3'd0; w_re = 16'sd27246; w_im = 16'sd18205; end
                    30: begin spec = 3'd0; w_re = 16'sd30274; w_im = 16'sd12540; end
                    31: begin spec = 3'd0; w_re = 16'sd32138; w_im = 16'sd6393; end
                    default: spec = 3'd0;
                endcase
            end
            default: begin spec = 3'd0; end
        endcase
        fft_tw32 = {spec, w_re, w_im};
    end
endfunction

function [34:0] fft_tw64(input integer stage, input integer m);
    reg signed [15:0] w_re, w_im;
    reg [2:0] spec;
    begin
        spec = 3'd0; w_re = 16'sd0; w_im = 16'sd0;
        case (stage)
            0: begin
                case (m)
                    0: spec = 3'd1;
                    1: spec = 3'd2;
                    default: spec = 3'd0;
                endcase
            end
            1: begin
                case (m)
                    0: spec = 3'd1;
                    1: spec = 3'd3;
                    2: spec = 3'd2;
                    3: spec = 3'd4;
                    default: spec = 3'd0;
                endcase
            end
            2: begin
                case (m)
                    0: spec = 3'd1;
                    1: begin spec = 3'd0; w_re = 16'sd23170; w_im = -16'sd23170; end
                    2: spec = 3'd3;
                    3: begin spec = 3'd0; w_re = -16'sd23170; w_im = -16'sd23170; end
                    4: spec = 3'd2;
                    5: begin spec = 3'd0; w_re = -16'sd23170; w_im = 16'sd23170; end
                    6: spec = 3'd4;
                    7: begin spec = 3'd0; w_re = 16'sd23170; w_im = 16'sd23170; end
                    default: spec = 3'd0;
                endcase
            end
            3: begin
                case (m)
                    0: spec = 3'd1;
                    1: begin spec = 3'd0; w_re = 16'sd30274; w_im = -16'sd12540; end
                    2: begin spec = 3'd0; w_re = 16'sd23170; w_im = -16'sd23170; end
                    3: begin spec = 3'd0; w_re = 16'sd12540; w_im = -16'sd30274; end
                    4: spec = 3'd3;
                    5: begin spec = 3'd0; w_re = -16'sd12540; w_im = -16'sd30274; end
                    6: begin spec = 3'd0; w_re = -16'sd23170; w_im = -16'sd23170; end
                    7: begin spec = 3'd0; w_re = -16'sd30274; w_im = -16'sd12540; end
                    8: spec = 3'd2;
                    9: begin spec = 3'd0; w_re = -16'sd30274; w_im = 16'sd12540; end
                    10: begin spec = 3'd0; w_re = -16'sd23170; w_im = 16'sd23170; end
                    11: begin spec = 3'd0; w_re = -16'sd12540; w_im = 16'sd30274; end
                    12: spec = 3'd4;
                    13: begin spec = 3'd0; w_re = 16'sd12540; w_im = 16'sd30274; end
                    14: begin spec = 3'd0; w_re = 16'sd23170; w_im = 16'sd23170; end
                    15: begin spec = 3'd0; w_re = 16'sd30274; w_im = 16'sd12540; end
                    default: spec = 3'd0;
                endcase
            end
            4: begin
                case (m)
                    0: spec = 3'd1;
                    1: begin spec = 3'd0; w_re = 16'sd32138; w_im = -16'sd6393; end
                    2: begin spec = 3'd0; w_re = 16'sd30274; w_im = -16'sd12540; end
                    3: begin spec = 3'd0; w_re = 16'sd27246; w_im = -16'sd18205; end
                    4: begin spec = 3'd0; w_re = 16'sd23170; w_im = -16'sd23170; end
                    5: begin spec = 3'd0; w_re = 16'sd18205; w_im = -16'sd27246; end
                    6: begin spec = 3'd0; w_re = 16'sd12540; w_im = -16'sd30274; end
                    7: begin spec = 3'd0; w_re = 16'sd6393; w_im = -16'sd32138; end
                    8: spec = 3'd3;
                    9: begin spec = 3'd0; w_re = -16'sd6393; w_im = -16'sd32138; end
                    10: begin spec = 3'd0; w_re = -16'sd12540; w_im = -16'sd30274; end
                    11: begin spec = 3'd0; w_re = -16'sd18205; w_im = -16'sd27246; end
                    12: begin spec = 3'd0; w_re = -16'sd23170; w_im = -16'sd23170; end
                    13: begin spec = 3'd0; w_re = -16'sd27246; w_im = -16'sd18205; end
                    14: begin spec = 3'd0; w_re = -16'sd30274; w_im = -16'sd12540; end
                    15: begin spec = 3'd0; w_re = -16'sd32138; w_im = -16'sd6393; end
                    16: spec = 3'd2;
                    17: begin spec = 3'd0; w_re = -16'sd32138; w_im = 16'sd6393; end
                    18: begin spec = 3'd0; w_re = -16'sd30274; w_im = 16'sd12540; end
                    19: begin spec = 3'd0; w_re = -16'sd27246; w_im = 16'sd18205; end
                    20: begin spec = 3'd0; w_re = -16'sd23170; w_im = 16'sd23170; end
                    21: begin spec = 3'd0; w_re = -16'sd18205; w_im = 16'sd27246; end
                    22: begin spec = 3'd0; w_re = -16'sd12540; w_im = 16'sd30274; end
                    23: begin spec = 3'd0; w_re = -16'sd6393; w_im = 16'sd32138; end
                    24: spec = 3'd4;
                    25: begin spec = 3'd0; w_re = 16'sd6393; w_im = 16'sd32138; end
                    26: begin spec = 3'd0; w_re = 16'sd12540; w_im = 16'sd30274; end
                    27: begin spec = 3'd0; w_re = 16'sd18205; w_im = 16'sd27246; end
                    28: begin spec = 3'd0; w_re = 16'sd23170; w_im = 16'sd23170; end
                    29: begin spec = 3'd0; w_re = 16'sd27246; w_im = 16'sd18205; end
                    30: begin spec = 3'd0; w_re = 16'sd30274; w_im = 16'sd12540; end
                    31: begin spec = 3'd0; w_re = 16'sd32138; w_im = 16'sd6393; end
                    default: spec = 3'd0;
                endcase
            end
            5: begin
                case (m)
                    0: spec = 3'd1;
                    1: begin spec = 3'd0; w_re = 16'sd32610; w_im = -16'sd3212; end
                    2: begin spec = 3'd0; w_re = 16'sd32138; w_im = -16'sd6393; end
                    3: begin spec = 3'd0; w_re = 16'sd31357; w_im = -16'sd9512; end
                    4: begin spec = 3'd0; w_re = 16'sd30274; w_im = -16'sd12540; end
                    5: begin spec = 3'd0; w_re = 16'sd28899; w_im = -16'sd15447; end
                    6: begin spec = 3'd0; w_re = 16'sd27246; w_im = -16'sd18205; end
                    7: begin spec = 3'd0; w_re = 16'sd25330; w_im = -16'sd20788; end
                    8: begin spec = 3'd0; w_re = 16'sd23170; w_im = -16'sd23170; end
                    9: begin spec = 3'd0; w_re = 16'sd20788; w_im = -16'sd25330; end
                    10: begin spec = 3'd0; w_re = 16'sd18205; w_im = -16'sd27246; end
                    11: begin spec = 3'd0; w_re = 16'sd15447; w_im = -16'sd28899; end
                    12: begin spec = 3'd0; w_re = 16'sd12540; w_im = -16'sd30274; end
                    13: begin spec = 3'd0; w_re = 16'sd9512; w_im = -16'sd31357; end
                    14: begin spec = 3'd0; w_re = 16'sd6393; w_im = -16'sd32138; end
                    15: begin spec = 3'd0; w_re = 16'sd3212; w_im = -16'sd32610; end
                    16: spec = 3'd3;
                    17: begin spec = 3'd0; w_re = -16'sd3212; w_im = -16'sd32610; end
                    18: begin spec = 3'd0; w_re = -16'sd6393; w_im = -16'sd32138; end
                    19: begin spec = 3'd0; w_re = -16'sd9512; w_im = -16'sd31357; end
                    20: begin spec = 3'd0; w_re = -16'sd12540; w_im = -16'sd30274; end
                    21: begin spec = 3'd0; w_re = -16'sd15447; w_im = -16'sd28899; end
                    22: begin spec = 3'd0; w_re = -16'sd18205; w_im = -16'sd27246; end
                    23: begin spec = 3'd0; w_re = -16'sd20788; w_im = -16'sd25330; end
                    24: begin spec = 3'd0; w_re = -16'sd23170; w_im = -16'sd23170; end
                    25: begin spec = 3'd0; w_re = -16'sd25330; w_im = -16'sd20788; end
                    26: begin spec = 3'd0; w_re = -16'sd27246; w_im = -16'sd18205; end
                    27: begin spec = 3'd0; w_re = -16'sd28899; w_im = -16'sd15447; end
                    28: begin spec = 3'd0; w_re = -16'sd30274; w_im = -16'sd12540; end
                    29: begin spec = 3'd0; w_re = -16'sd31357; w_im = -16'sd9512; end
                    30: begin spec = 3'd0; w_re = -16'sd32138; w_im = -16'sd6393; end
                    31: begin spec = 3'd0; w_re = -16'sd32610; w_im = -16'sd3212; end
                    32: spec = 3'd2;
                    33: begin spec = 3'd0; w_re = -16'sd32610; w_im = 16'sd3212; end
                    34: begin spec = 3'd0; w_re = -16'sd32138; w_im = 16'sd6393; end
                    35: begin spec = 3'd0; w_re = -16'sd31357; w_im = 16'sd9512; end
                    36: begin spec = 3'd0; w_re = -16'sd30274; w_im = 16'sd12540; end
                    37: begin spec = 3'd0; w_re = -16'sd28899; w_im = 16'sd15447; end
                    38: begin spec = 3'd0; w_re = -16'sd27246; w_im = 16'sd18205; end
                    39: begin spec = 3'd0; w_re = -16'sd25330; w_im = 16'sd20788; end
                    40: begin spec = 3'd0; w_re = -16'sd23170; w_im = 16'sd23170; end
                    41: begin spec = 3'd0; w_re = -16'sd20788; w_im = 16'sd25330; end
                    42: begin spec = 3'd0; w_re = -16'sd18205; w_im = 16'sd27246; end
                    43: begin spec = 3'd0; w_re = -16'sd15447; w_im = 16'sd28899; end
                    44: begin spec = 3'd0; w_re = -16'sd12540; w_im = 16'sd30274; end
                    45: begin spec = 3'd0; w_re = -16'sd9512; w_im = 16'sd31357; end
                    46: begin spec = 3'd0; w_re = -16'sd6393; w_im = 16'sd32138; end
                    47: begin spec = 3'd0; w_re = -16'sd3212; w_im = 16'sd32610; end
                    48: spec = 3'd4;
                    49: begin spec = 3'd0; w_re = 16'sd3212; w_im = 16'sd32610; end
                    50: begin spec = 3'd0; w_re = 16'sd6393; w_im = 16'sd32138; end
                    51: begin spec = 3'd0; w_re = 16'sd9512; w_im = 16'sd31357; end
                    52: begin spec = 3'd0; w_re = 16'sd12540; w_im = 16'sd30274; end
                    53: begin spec = 3'd0; w_re = 16'sd15447; w_im = 16'sd28899; end
                    54: begin spec = 3'd0; w_re = 16'sd18205; w_im = 16'sd27246; end
                    55: begin spec = 3'd0; w_re = 16'sd20788; w_im = 16'sd25330; end
                    56: begin spec = 3'd0; w_re = 16'sd23170; w_im = 16'sd23170; end
                    57: begin spec = 3'd0; w_re = 16'sd25330; w_im = 16'sd20788; end
                    58: begin spec = 3'd0; w_re = 16'sd27246; w_im = 16'sd18205; end
                    59: begin spec = 3'd0; w_re = 16'sd28899; w_im = 16'sd15447; end
                    60: begin spec = 3'd0; w_re = 16'sd30274; w_im = 16'sd12540; end
                    61: begin spec = 3'd0; w_re = 16'sd31357; w_im = 16'sd9512; end
                    62: begin spec = 3'd0; w_re = 16'sd32138; w_im = 16'sd6393; end
                    63: begin spec = 3'd0; w_re = 16'sd32610; w_im = 16'sd3212; end
                    default: spec = 3'd0;
                endcase
            end
            default: begin spec = 3'd0; end
        endcase
        fft_tw64 = {spec, w_re, w_im};
    end
endfunction
`endif
