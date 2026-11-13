# DSP-CMA 课程大作业

MATLAB 自编 FFT/快速卷积/双偏振频域 CMA + Verilog 全并行 FFT 的课程大作业完整实现。需求原文、勘误与验收映射见 [docs/requirements.md](docs/requirements.md)；设计公式、定点方案与决策记录见 [docs/architecture.md](docs/architecture.md)；实验结果见 [docs/report.md](docs/report.md)；逐步验证状态见 [docs/validation.md](docs/validation.md)。

## 环境

| 工具 | 版本 | 用途 |
| --- | --- | --- |
| MATLAB | R2026b Update 1（`~/matlab`） | 全部算法、定点模型、向量与表格生成 |
| Verilator | 5.054 | RTL 功能仿真回归（H05 功能仿真证据） |
| Vivado | 2022.1+（本机未装，BLOCKED） | xsim 仿真 / Implementation（H06 补跑） |
| Python 3 + numpy | 仅辅助 | 数据准备脚本、规则检查器 |

核心算法不依赖任何 MATLAB 工具箱。

## 数据准备

原始材料在 `docs/requirement/`（只读保留）。以下命令从压缩包提取参考代码与数据到 `data/reference/`（不覆盖已存在文件）并生成 SHA-256 清单：

```bash
python3 scripts/prepare_data.py
```

## 运行命令

```bash
# 1) 全量批处理：单元测试(8 组) + 卷积演示 + 17/33/65 抽头 CMA 实验
#    + 定点向量/RTL 表生成 + 结果元数据（约 10 分钟）
matlab -batch "addpath('matlab'); run_all"

# 2) 仅单元测试
matlab -batch "addpath('matlab'); dspcma_setup; run_tests"

# 3) RTL 功能仿真回归（Verilator；4 个 testbench，约 1 分钟）
bash scripts/run_verilator.sh

# 4) 规则检查（禁用 API/数据通路乘法/绝对路径/交付完整性）
python3 scripts/check_rules.py

# 5) Vivado 补跑（需已安装 Vivado；xsim 4 个 TB + Implementation）
bash scripts/vivado/run_all.sh fft32_top fft64_top
```

开发期可缩小数据量：`matlab -batch "addpath('matlab'); run_all('quick')"`；正式交付必须用完整模式（默认）。

## 输出位置

- `results/<run_id>/`：`run_meta.json`（时间 Asia/Singapore、种子、工具版本、数据 SHA-256、代码版本）、`tests_summary.json`、`metrics_tapsweep.json`、`metrics_phase_diagnosis.json`、`metrics_fixedpoint.json`、星座图/收敛曲线 PNG。
- `rtl/tb/vectors/`：定点测试向量（`.mem`，每行一帧）与 `manifest.json`。
- `rtl/fft/fft_twiddle_tables.vh`：RTL 旋转因子表（`gen_rtl_tables.m` 生成，勿手改）。
- Vivado 产物落在 `build/vivado/` 与 `results/vivado_impl_<top>/`（gitignore 内）。

## 完成状态

| 需求 | 状态 | 证据 |
| --- | --- | --- |
| B01 32/128 点 FFT（模拟硬件并行结构） | PASS | `tests_summary.json`（vs 手写 DFT 相对 L2 ≤ 3.5e-14） |
| B02 手写旋转因子 + 对称/周期优化 | PASS | 同上（误差 8e-16，特殊角 isequal） |
| B03 快速卷积（用户指定信号/滤波器） | PASS | 同上 + `metrics_conv_demo.json`（OLA/OLS vs 直接 ≈ 4e-16） |
| B04 重叠相加/保留边界 | PASS | 18 项边界用例（非整块/单点/长滤波器/尾部冲刷） |
| B05 双偏振 4QAM 频域 CMA + DD-EVM | PASS | `metrics_tapsweep.json`、星座图/收敛曲线 |
| B06 抽头长度 17/33/65 对照 | PASS | 同上（含解析圆环下限分析） |
| H01–H03 全并行 32/64 点 RTL | PASS（功能仿真） | Verilator 回归 4 TB 全 PASS |
| H04 3 拍乘法器原语（DSP48E2） | PASS（功能仿真） | `tb_dsp_mult3`（延迟=3 拍，2000 组逐位） |
| H05 与 MATLAB 参考结果对比 | PASS（Verilator）/ BLOCKED（xsim） | 逐位一致；xsim 补跑命令已交付 |
| H06 xcvu13p 250 MHz Implementation | BLOCKED（本机无 Vivado） | `scripts/vivado/` 可重建 Tcl |
| D01 中文报告与汇报材料 | PASS | `docs/report.md`、`docs/presentation.md` |

## 限制

- 实验数据逐符号相位均匀随机（相干度 ≈ 0.01，见 `docs/report.md` §6）：DD-EVM 存在解析下限 44.65%，均衡后实测 45.7%（ISI 残余仅 +1 个百分点）——该下限由数据决定，不是均衡器缺陷。
- Vivado 仿真/综合/Implementation 未在本机执行（无工具）；补跑命令与工程脚本已交付，未产生任何虚构的资源/时序数字。
- CMA 抽头更新延迟仅承诺 `clk_dly=1`（与参考代码一致），其他值显式拒绝。
