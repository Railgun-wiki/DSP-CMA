# common.tcl: Vivado 工程公共配置 (AGENTS 5/8.3)。
# 器件与约束按需求截图录入; 路径一律相对仓库根, 由调用方先 cd 到仓库根。
# 工具版本: Vivado 2022.1+ (xcvu13p 支持)。

set DEVICE    "xcvu13p-flga2577-2-i"
set CLK_PERIOD_NS 4.0        ;# 250 MHz (需求: 在 250 MHz 时钟下运行 Implementation)
set CLK_PORT      "clk"

# 综合源清单 (不含任何 IP; 乘法为 DSP48E2 原语包装, H04)
set SYNTH_SOURCES {
    rtl/common/dsp_mult3.v
    rtl/common/bfly2.v
    rtl/fft/fft_radix2_core.v
    rtl/fft/fft32_top.v
    rtl/fft/fft64_top.v
}
set INCLUDE_DIRS { rtl/fft }

# 仿真文件集: testbench + 行为乘法模型 (替代综合版原语包装, 同名模块)
set SIM_SOURCES {
    rtl/sim/dsp_mult3_sim.v
    rtl/common/bfly2.v
    rtl/fft/fft_radix2_core.v
    rtl/fft/fft32_top.v
    rtl/fft/fft64_top.v
    rtl/tb/tb_dsp_mult3.v
    rtl/tb/tb_bfly2.v
    rtl/tb/tb_fft32.v
    rtl/tb/tb_fft64.v
}

proc check_repo_root {} {
    if {![file exists [file join [pwd] AGENTS.md]]} {
        puts "ERROR: 请在仓库根目录运行 (未找到 AGENTS.md)"
        exit 1
    }
}

# 为顶层生成引脚/时钟约束 (静态端口清单, 不依赖设计打开)。
# 引脚为合成选择 (HP bank LVCMOS12, 无实板), 总线位名用 {} 保护以
# 保证 XDC 重新解析安全 (F02 整改)。
proc make_pin_constraints {top_name n_points xdc_path} {
    set pins [get_package_pins -filter "PIN_FUNC == IOB && BANK_TYPE == HP"]
    if {[llength $pins] == 0} {
        set pins [get_package_pins -filter "PIN_FUNC == IOB"]
    }
    # 静态端口清单: fft32_top -> 512 bit, fft64_top -> 1024 bit
    set nbytes [expr {2 * $n_points}]
    set plist {}
    lappend plist clk rst in_valid
    for {set k 0} {$k < $nbytes} {incr k} { lappend plist "din\[$k\]" }
    for {set k 0} {$k < $nbytes} {incr k} { lappend plist "dout\[$k\]" }
    lappend plist out_valid
    for {set k 0} {$k < 32} {incr k} { lappend plist "sat_cnt\[$k\]" }
    if {[llength $plist] > [llength $pins]} {
        puts "ERROR: 可用封装引脚不足 ([llength $pins] < [llength $plist])"
        exit 1
    }
    set f [open $xdc_path w]
    puts $f "# 自动生成: scripts/vivado/run_impl.tcl (合成引脚, 非真实板级)"
    set idx 0
    foreach p $plist {
        set pin [lindex $pins $idx]
        incr idx
        puts $f "set_property -dict {PACKAGE_PIN $pin IOSTANDARD LVCMOS12} \[get_ports {$p}]"
    }
    puts $f "create_clock -period $::CLK_PERIOD_NS -name sys_clk \[get_ports {clk}\]"
    close $f
    puts "引脚约束: $xdc_path ([llength $plist] 端口, 静态清单)"
}
