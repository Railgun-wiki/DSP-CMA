#!/bin/bash
# RTL 功能仿真回归入口 (Verilator 5, AGENTS 8.3 第 3 条的 RTL 部分)。
# 用法 (仓库根目录): bash scripts/run_verilator.sh
# 说明: 仿真文件集使用 rtl/sim/dsp_mult3_sim.v (行为乘法模型) 替代
# 综合 rtl/common/dsp_mult3.v (DSP48E2 原语, Verilator 无 Xilinx 单元库)。
# 与 MATLAB 定点向量的逐位对照 = H05 的功能仿真证据; Vivado xsim 与
# Implementation 见 scripts/vivado/ (本机无 Vivado 时为 BLOCKED)。
set -u
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/dspcma_verilator"
mkdir -p "$OUT"
FAIL=0

run_tb () {
    local name="$1"; shift
    echo "=== $name ==="
    verilator --binary --timing -Wno-fatal -Wno-DECLFILENAME \
        -Wno-WIDTHTRUNC -Wno-TIMESCALEMOD -Wno-WIDTHEXPAND -Irtl/fft \
        "$@" --Mdir "$OUT/$name" -o "V$name" > "$OUT/$name.build.log" 2>&1
    if [ $? -ne 0 ]; then
        echo "BUILD FAIL: 见 $OUT/$name.build.log"
        FAIL=1
        return
    fi
    (cd . && "$OUT/$name/V$name" > "$OUT/$name.run.log" 2>&1)
    if grep -q "PASS" "$OUT/$name.run.log"; then
        grep "PASS" "$OUT/$name.run.log"
    else
        echo "RUN FAIL: 见 $OUT/$name.run.log"
        FAIL=1
    fi
}

run_tb mult  rtl/sim/dsp_mult3_sim.v rtl/tb/tb_dsp_mult3.v --top-module tb_dsp_mult3
run_tb bfly  rtl/sim/dsp_mult3_sim.v rtl/common/bfly2.v rtl/tb/tb_bfly2.v --top-module tb_bfly2
run_tb fft32 -Irtl/fft rtl/sim/dsp_mult3_sim.v rtl/common/bfly2.v \
    rtl/fft/fft_radix2_core.v rtl/fft/fft32_top.v rtl/tb/tb_fft32.v --top-module tb_fft32
run_tb fft64 -Irtl/fft rtl/sim/dsp_mult3_sim.v rtl/common/bfly2.v \
    rtl/fft/fft_radix2_core.v rtl/fft/fft64_top.v rtl/tb/tb_fft64.v --top-module tb_fft64

if [ $FAIL -eq 0 ]; then
    echo "RTL 回归: 全部 PASS"
else
    echo "RTL 回归: 存在 FAIL"
    exit 1
fi
