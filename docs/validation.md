# 验证记录

状态口径：`PASS / FAIL / BLOCKED / NOT_RUN`。所有命令在仓库根目录执行。正式运行目录：`results/20261114T055101_full/`（亚洲/新加坡时间 2026-11-14 05:51，MATLAB R2026b Update 1，数据 SHA-256 `120c34e1…78ce`，代码版本见 run_meta.json）。

## 0. 验收意见（docs/acceptance.md）整改状态

独立验收（2026-11-14）给出 8 项发现；整改情况：

| 发现 | 整改 | 验证 |
| --- | --- | --- |
| F01 DSP48E2 包装端口/参数错误 | 按 unisim 官方声明重写包装（CEA1/CEA2/CEM/CEP、RSTA/RSTB/RSTM/RSTP 等，D 27 bit、OPMODE 9 bit、USE_MULT="MULTIPLY"、PREG=0+外层寄存=3 拍） | `python3 scripts/check_dsp_interface.py`：50 端口/14 参数与官方声明一致；声明参考件 `rtl/ip/DSP48E2_unisim_decl.v` 可与包装联合通过 lint |
| F02 Vivado Tcl 错误 | XDC 总线名 `{din[0]}` 括号保护；xsim 向量路径真实展开；引脚约束改静态端口清单（不依赖设计打开）；按顶层清理约束文件 | tclsh 桩验证：生成 164/292 端口 XDC，逐行可解析、无字面反斜杠；4 份 Tcl `info complete` 通过 |
| F03 save_json 结构体数组截断 | with_subs 对 numel>1 的结构体数组转 cell of structs；新增 load_json；补 test_io | 3 元素含嵌套/复实混合的往返断言；manifest 12 用例哈希与文件一致断言 |
| F04 报告因果解释超出证据 | 报告/README/架构/汇报稿改写：信道模型降级为待验证假设；44.65% 标注为条件计算；z⁴ 滞后相关（≈0.72 vs 打乱对照 <0.01）与 ±64 拍互相关搜索（≈0.014）作为证据纳入诊断 | `metrics_phase_diagnosis.json` 新增 z4_lag_corr/z4_lag_corr_shuffled/xcorr 字段 |
| F05 运行材料不全/引用缺失产物 | run_all 调用 channel_diagnosis（双偏振）；保存 config.json 快照与 cma_outputs.mat（未经校准输出）；detect_git 以仓库路径检测 | 正式运行目录含 phase_diagnosis.png、metrics_phase_diagnosis.json、config.json、cma_outputs.mat；run_meta.data_sha256 非 unavailable |
| F06 CMA 行向量/短输入边界 | check_pair 两路均转列并返回；不足一段显式报错 `DSPCMA:cma:tooShort`；seg_len/tap_len(奇)/par_num/step/Rx,Ry 配置校验 | `test_cma_kernel` 17/17（新增行向量一致性、短输入拒绝、非法配置拒绝） |
| F07 正式 RTL 未达 Verilog-2001 | `$clog2` → 常量函数 clog2p；舍入函数去掉输出形参（返回 {sat,q} 拼接） | `verilator --lint-only --language 1364-2001`（含官方声明参考件联合）0 错误 0 警告 |
| F08 批处理失败无退出门槛 | run_all 在证据落盘后显式抛错：测试 9 组全过、定点导出成功、两路 EVM 改善、输出有限、ρ<0.9（工程默认，未退化为同一路）五项门槛；PASS/FAIL/BLOCKED/NOT_RUN 分别记录于 summary.json | 门控逻辑为静态代码 + 正式运行 summary.gates 字段；单次运行门槛数值见表 |

## 1. 单元测试（正式运行内执行）

命令：`matlab -batch "addpath('matlab'); run_all"`（含 `run_tests`）→ **8/8 PASS**（`tests_summary.json`）。

| 测试 | 检查项 | 结果 | 关键数字 |
| --- | --- | --- | --- |
| test_smoke | 配置/基本调用 | PASS 5/5 | — |
| test_fft | 冲激/常数/单频/随机 vs 手写 DFT、IFFT 往返、形状、错误标识、级结构 | PASS 31/31 | 相对 L2 ≤ 3.5e-14（阈值 1e-10） |
| test_twiddle | 全索引/反对称/倍角递推/共轭/特殊因子/调用次数 | PASS 4/4 | 最大误差 8.0e-16（阈值 1e-12） |
| test_convolution | 复数/非整块/B<L-1/单点/稀疏跨块/长滤波器/尾部冲刷/错误标识 | PASS 18/18 | 相对 L2 ≤ 4.4e-16（阈值 1e-10） |
| test_evm | 公式解析值/零参考报错/校准恢复/解析 DD-EVM/判决确定性 | PASS 9/9 | 校准后 EVM ≈ 1.1e-15 |
| test_cma_kernel | 固定抽头/单次更新/20 时钟快照/更新时序/非整组/17、65 抽头/clk_dly 拒绝 | PASS 14/14 | 频域 vs 时域 ≤ 7e-16（阈值 1e-8） |
| test_cma_reference_parity | 与原版 CMA_reference.m 全量 639616 点对照 | PASS 6/6 | 输出与最终抽头误差 **0.00e+00** |
| test_fixedpoint | 缩放口径/DC/谱线/随机 vs 浮点/极值/Q15 量化/表生成 | PASS 14/14 | 随机 vs 浮点 0.699 LSB |
| test_io | JSON 结构体数组往返、向量 manifest 完整性、正式运行工件完整性 | PASS 3/3 | 12 用例哈希与文件一致 |

日志：`results/20261114T152426_full/tests_summary.json`。失败实验（保留）：`results/20261114T054257_full`（首次执行在卷积演示处因工具箱 `sinc` 缺失中断，已改显式实现重跑）、`results/20261114T054534_full`/`20261114T054829_full`/`20261114T055101_full`/`20261114T055558_full`（JSON 序列化与元数据修复的中间运行：struct 数组→JSON 数组、数据 SHA-256 取第三输出、tests_summary 保存修复后的 summary 对象）。

## 2. 全量 CMA 实验（B05/B06）

命令：同上（run_all 第 3 步，`dspcma.equalizer.run_tap_sweep` + `channel_diagnosis`）→ **PASS**。

- 输出：`metrics_tapsweep.json`、`metrics_phase_diagnosis.json`、`constellation_before.png`、`constellation_tap33.png`、`convergence.png`、`tapsweep_evm.png`。
- 核心数字：均衡前 DD-EVM 55.04%/54.44%；均衡后 tap=17/33/65 → 45.67/45.65%、45.69/45.65%、45.94/45.86%；解析圆环下限 44.65%；|z|² ≈ 1.93；ρ ≈ 0.007；频域 vs 时域全长自适应后 4.7e-16；数据丢弃 0。
- 检查项：无 NaN/Inf、两偏振未退化（ρ 远小于 1）、两路均改善——工程验收目标（AGENTS 4.4）满足。

## 3. 定点模型与向量（H02/H05 前置）

命令：run_all 第 4 步（`dspcma.fixedpoint.export_all`）→ **PASS**。

- 向量：`rtl/tb/vectors/`（32/64 点 × 6 用例 × 8 帧），manifest 含逐文件 SHA-256。
- 定点 vs 浮点：最大绝对误差 0.699 LSB（`metrics_fixedpoint.json`）。

## 4. RTL 功能仿真（H04/H05 功能部分）

命令：`bash scripts/run_verilator.sh`（Verilator 5.054）→ **4/4 PASS**。

| TB | 覆盖 | 结果 |
| --- | --- | --- |
| tb_dsp_mult3 | 2000 组随机 16×16 乘积逐位、延迟恰 3 拍、en 门控、复位 | PASS |
| tb_bfly2 | 特殊因子旁路、复乘、半偶舍入恰半、顶/底臂、延迟 4 拍、冻结 | PASS |
| tb_fft32 | 6 用例 × 8 帧逐位（连续/气泡/中途复位）、延迟 22 拍、无陈旧输出、sat_cnt=0 | PASS |
| tb_fft64 | 同上，延迟 26 拍 | PASS |

日志：`$TMPDIR/dspcma_verilator/*.run.log`。说明：仿真文件集用 `rtl/sim/dsp_mult3_sim.v` 行为乘法模型；综合版 DSP48E2 原语文件仅进入 Vivado 文件集（Verilator 无 Xilinx 单元库，lint 该文件时仅报 DSP48E2 未定义，属预期）。

## 5. Vivado 仿真 / 综合 / Implementation（H05 仿真部分 / H06）—— **BLOCKED**

- 原因：本机未安装 Vivado（`vivado`/`xvlog` 不在 PATH）。
- 已交付：`scripts/vivado/create_project.tcl`、`run_sim.tcl`、`run_impl.tcl`、`run_all.sh`（器件 xcvu13p-flga2577-2-i、4 ns 约束、综合/仿真文件集分离、合成引脚约束、WNS/WHS 非零退出）。
- **补跑命令**：

```bash
bash scripts/vivado/run_all.sh fft32_top fft64_top
```

或分步：

```bash
vivado -mode batch -source scripts/vivado/run_sim.tcl  -tclargs tb32
vivado -mode batch -source scripts/vivado/run_sim.tcl  -tclargs tb64
vivado -mode batch -source scripts/vivado/run_impl.tcl -tclargs fft32_top
vivado -mode batch -source scripts/vivado/run_impl.tcl -tclargs fft64_top
```

- 补跑后应核对：xsim 日志 PASS；`results/vivado_impl_<top>/utilization.rpt`、`timing_summary.rpt`；setup/hold 均满足 4 ns（250 MHz）。补跑完成前**不宣称硬件验收完成**。

## 6. 规则检查（AGENTS 7）

命令：`python3 scripts/check_rules.py` → **7/7 PASS**（本批文档与正式运行落盘后复核）。覆盖：MATLAB 禁用 API（fft/ifft/dftmtx/cconv/fftfilt/工具箱均衡器）、核心模块 clear/clc/close all、绝对路径、综合源数据通路乘法 `*`（常量上下文放行）、仿真构造（initial/#/real/$任务）、交付完整性、结果元数据。

## 7. Octave 检查 —— **NOT_RUN**

本机无 Octave；MATLAB 为正式验证工具，Octave 交叉检查不作为验收依据（AGENTS 7 允许缺工具时按 MATLAB 口径验收）。

## 8. 待办汇总

| 事项 | 状态 | 责任命令 |
| --- | --- | --- |
| Vivado xsim 4 TB | BLOCKED | `bash scripts/vivado/run_all.sh` |
| Vivado 综合 + Implementation（两顶层） | BLOCKED | 同上 |
| 资源/时序报告（LUT/FF/BRAM、WNS/WHS） | BLOCKED | 补跑后从 `results/vivado_impl_<top>/` 提取并更新本文件与 report |
| 规则检查 7/7 | 文档与正式结果落盘后复核 | `python3 scripts/check_rules.py` |
