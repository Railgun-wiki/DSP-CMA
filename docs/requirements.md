# 需求追踪与勘误转录

本文档转录课程要求原始材料（两张勘误截图、`大作业matlab.zip` 内说明与代码），给出编号、勘误口径与验收映射。原始图片与压缩包在 `docs/requirement/` 中只读保留，SHA-256 见 `data/reference/manifest.json`。

## 1. 原始要求转录

### 1.1 CMA 部分勘误（微信图片_20261114013336_212_2.jpg）

> 对大作业 CMA 部分内容进行勘误，**不用计算误码率，而是计算 EVM**。

截图所含课件页（课程大作业·基础任务：基于 Matlab 的光纤通信信号处理与 CMA 算法实现，占 80%）要点转录：

- 功能要求：
  1. 根据模块并行计算设计方法，编写 MATLAB 函数实现 32 点及 128 点的 FFT 算法。
  2. 基于自主编写的 FFT 函数，完成：超数据流的快速卷积（FFT —— 频域相乘 —— IFFT），要求输入信号与滤波器可由使用者指定。
  3. 针对上述频域模块完成 CMA 均衡器（利用快速卷积完成 CMA 中的梯度更新子），QAM 信号的产生与解调部分代码会给出；修改 CMA 的抽头长度，分析抽头长度对于均衡效果的影响。
- 设计约束：
  1. 不允许直接调用 MATLAB 内置的 `fft`、`ifft` 等相关函数。
  2. 手动实现旋转因子的计算与优化（利用对称性和周期性）。
- 验证要求：
  1. 完成基 2 FFT 的正确性验证。
  2. 快速卷积与直接卷积的结果对比。
  3. 重叠相加、保留法的正确性验证。
  4. CMA 均衡前后的信号质量对比（星座图，计算 EVM），不同抽头长度的影响。

### 1.2 Verilog FFT 部分补充说明与勘误（微信图片_20261114013341_213_2.jpg）

> FFT 模块的输入输出为复数数据，**每个点的实部和虚部各固定为 8 bit（合计 16 bit）**，不是实部与虚部共 8 bit。另外评分细则-进阶任务中**改为 32 点 FFT 和 64 点 FFT**（之前是 32 点 FFT 和 128 点 FFT）。

截图所含课件页（进阶任务：基于 Verilog 的 FFT 实现，占 20%）要点转录：

- 功能要求：
  1. 需要 Verilog 设计全并行 FFT 算法（32、64 点）。
  2. 输入/输出数据格式为复数，每个点的实部和虚部各固定为 8 bit（例如对于 32 点 FFT，总线输入/输出位宽为 (8+8)×32 bit）。
- 设计约束：
  1. 不使用 FPGA/ASIC 厂商提供的 FFT IP 核。
  2. 采用模块化设计。
  3. 采用流水线优化设计和并行处理提高运算效率。
  4. 数据通路乘法使用乘法器 IP 核或原语，延迟为 3 个时钟周期；不使用 `*` 实现数据通路乘法。
- 验证要求：
  1. 使用 Vivado 进行功能仿真，与 MATLAB 参考结果对比。
  2. 使用 `xcvu13p-flga2577-2-i` 型号的设备，在 250 MHz 时钟下运行 Implementation。
  3. 分析硬件实现的资源占用情况（LUT、FF、BRAM 等）与延迟情况。

### 1.3 评分细则（两图均有）

大作业以团队形式完成，最多 3 人/组。

| 部分 | 具体任务 | 分数比例 |
| --- | --- | --- |
| 基础任务 80% | 并行 FFT | 30% |
| | 快速卷积 | 10% |
| | CMA | 30% |
| | 汇报 & 报告 | 30% |
| 进阶任务 20% | 32 点并行 FFT | 40% |
| | 64 点并行 FFT | 30% |
| | 汇报 & 报告 | 30% |

### 1.4 随包材料（大作业matlab.zip/Readme.txt）

- `CMA_reference.m`：时域 CMA 的实现（参考基线，保留原版不改动）。
- `CMA_homework.m`：学生作业骨架，要求使用自编 FFT 在频域完成 CMA。
- `TD_TRdata.mat`：实验数据（定时恢复后的双偏振数据）。

## 2. 勘误后的验收口径

1. CMA 评估指标为 **EVM**（本数据无已知发送符号，实际计算并命名为判决导向 DD-EVM），**不计算 BER**。
2. MATLAB 基础任务 FFT 点数为 **32 与 128 点**；Verilog 进阶任务 FFT 点数为 **32 与 64 点**。
3. 8 bit 是每个实数分量的位宽：每个复数点 16 bit；32 点总线 512 bit，64 点总线 1024 bit。
4. 不允许调用 MATLAB 内置 `fft/ifft` 等；旋转因子手工计算并利用对称性、周期性优化。
5. RTL 数据通路乘法用 3 拍延迟的乘法器 IP/原语；综合源码不使用 `*`。

## 3. 需求编号与验收映射（B01–D01）

| 编号 | 内容 | 实现 | 验证 | 结果/证据 |
| --- | --- | --- | --- | --- |
| B01 | MATLAB 32/128 点 FFT，模拟硬件并行结构 | `matlab/+dspcma/fft/my_fft.m`、`fft_stage_map.m` | `matlab/tests/test_fft.m`（对照手写 O(N²) DFT） | `results/<run_id>/metrics_*.json`、`docs/validation.md` |
| B02 | 手写旋转因子计算与对称/周期优化 | `matlab/+dspcma/fft/twiddle_table.m` | `matlab/tests/test_twiddle.m`（全索引、象限、特殊角） | 同上；`docs/architecture.md` 记录基础角调用次数 |
| B03 | 自编 FFT 完成快速卷积（用户指定信号/滤波器） | `matlab/+dspcma/convolution/ola_conv.m`、`ols_conv.m`、`conv_demo.m` | `matlab/tests/test_convolution.m`（与 `conv_direct.m` 对照） | 同上 |
| B04 | 重叠相加与重叠保留 | 同上 `ola_conv.m`、`ols_conv.m` | 边界用例：非整块、尾部、单点、复数、长滤波器 | 同上 |
| B05 | 双偏振 4QAM 频域 CMA | `matlab/+dspcma/equalizer/cma_freq_run.m`（时域基线 `cma_time_run.m`） | `matlab/tests/test_cma_kernel.m`（短程与时域基线一致） | `results/<run_id>/` 星座图、收敛曲线、DD-EVM |
| B06 | 修改抽头长度分析影响 | `matlab/+dspcma/equalizer/run_tap_sweep.m`（17/33/65） | 同一数据/步长/更新周期/评估口径 | `results/<run_id>/metrics_tapsweep.json`、报告表格 |
| H01 | Verilog 32/64 点全并行 FFT | `rtl/fft/fft32_top.v`、`fft64_top.v`、`rtl/fft/fft_radix2_core.v` | `rtl/tb/tb_fft32.v`、`tb_fft64.v`（xsim/Verilator） | `results/<run_id>/verilator_*.log`、Vivado 仿真日志 |
| H02 | 每分量实虚各 8 bit | 顶层 512/1024 bit 总线切片 | 位宽断言与定点向量逐位对照 | 向量清单 `rtl/tb/vectors/manifest.json` |
| H03 | 不用 FFT IP，模块化流水线全并行 | `rtl/common/`、`rtl/fft/` 源码清单 | 综合源无 `*`、无 IP 依赖（规则检查） | `scripts/check_rules.py` 输出 |
| H04 | 乘法用 3 拍乘法器原语/IP | `rtl/common/dsp_mult3.v`（DSP48E2 原语）+ `rtl/sim/dsp_mult3_sim.v`（行为模型） | `rtl/tb/tb_dsp_mult3.v`（延迟=3 拍） | 仿真日志 |
| H05 | Vivado 功能仿真 vs MATLAB | `scripts/vivado/run_sim.tcl` + 定点向量 | 逐位一致 + 浮点误差报告 | `docs/validation.md`（含 Verilator 交叉） |
| H06 | xcvu13p-flga2577-2-i、250 MHz Implementation | `scripts/vivado/create_project.tcl`、`run_impl.tcl`、约束 | 实现 post-route 时序/资源报告 | BLOCKED（本机无 Vivado），补跑命令见 validation |
| D01 | 中文报告与汇报材料 | `docs/report.md`、`docs/presentation.md` | 与保存结果一致（无占位数据） | 本仓库文档 |

## 4. 课程硬要求与工程默认值的区分

**课程硬要求**：上表 B01–D01 的内容本身、EVM 指标、32/128 与 32/64 点数、8 bit 分量位宽、总线位宽、禁用内置 FFT、旋转因子手工优化、不用 FFT IP、3 拍乘法器、指定器件与 250 MHz。

**工程默认值**（可调整，调整需记录原因）：
- DD-EVM 校准流程（四次方相位 + 模增益，独立校准段 131072 点）。
- 尾部评估窗精确取 131072 点（替代参考脚本 `end-131072:end` 的 131073 点）。
- 频域 CMA 按段（32 点）做 N=64 FFT 的 OLS 处理，每 4 段更新一次抽头。
- 定点方案：每级 1/2 缩放、内部 Q8、旋转因子 Q15、最近偶数舍入、输出饱和并计数。
- RTL 乘法器采用 DSP48E2 原语（H04 允许"IP 核或原语"，原语免 IP 生成依赖，配置见架构文档）。
- 规则检查以 Python 实现（辅助检查用途）。
- 仅承诺 `clk_dly=1` 的更新延迟语义（与参考一致）。

## 5. 明确不做的事项

- 不计算 BER，不把 DD-EVM 写成"已知参考 EVM"。
- 不使用 MATLAB 内置 `fft/ifft/fft2/ifft2/fftn/ifftn/dftmtx/cconv/fftfilt` 或工具箱均衡器作为正式算法路径（仅限隔离标注的可选对照测试）。
- 不改动 `docs/requirement/` 原始素材与 `data/reference/` 原版参考代码。
- 不虚构 Vivado/仿真/资源/时序结果；缺工具时标 BLOCKED 并给出补跑命令。
