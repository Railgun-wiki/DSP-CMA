#!/bin/bash
# Vivado 补跑总入口 (本机无 Vivado 时 BLOCKED, 命令已验证语法可读)。
# 用法 (仓库根目录): bash scripts/vivado/run_all.sh [fft32_top|fft64_top]
# 依次执行: 行为仿真 (4 个 TB) -> 综合 -> Implementation -> 报告。
# 每一步失败即以非零码退出 (AGENTS 8.3)。
set -u
cd "$(dirname "$0")/../.."
VIVADO=${VIVADO:-vivado}
TOPS=${@:-"fft32_top fft64_top"}

echo "== Vivado 行为仿真 =="
for tb in tb32 tb64 mult bfly; do
    "$VIVADO" -mode batch -source scripts/vivado/run_sim.tcl -tclargs $tb || exit 1
done

for top in $TOPS; do
    echo "== Implementation: $top =="
    "$VIVADO" -mode batch -source scripts/vivado/run_impl.tcl -tclargs $top || exit 1
done
echo "== Vivado 补跑全部完成 =="
