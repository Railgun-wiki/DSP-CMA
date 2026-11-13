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

# 为顶层端口生成引脚约束 (无实板, 引脚为合成选择: HP bank LVCMOS12)。
# 目的: 让 Implementation 完整跑通布局布线; 报告中注明引脚非真实板级。
proc make_pin_constraints {top_name xdc_path} {
    set part [get_parts -quiet -filter "NAME =~ xcvu13p*"]
    if {[llength $part] == 0} {
        puts "ERROR: 器件库不支持 xcvu13p (原值已记录, 不擅自替换)"
        exit 1
    }
    set pins [get_package_pins -filter "PIN_FUNC == IOB && BANK_TYPE == HP"]
    if {[llength $pins] == 0} {
        set pins [get_package_pins -filter "PIN_FUNC == IOB"]
    }
    set ports [get_ports]
    set f [open $xdc_path w]
    puts $f "# 自动生成: scripts/vivado/run_impl.tcl (合成引脚, 非真实板级)"
    set idx 0
    foreach p $ports {
        set pin [lindex $pins $idx]
        incr idx
        if {$pin eq ""} {
            puts "ERROR: 引脚数量不足"
            exit 1
        }
        puts $f "set_property -dict {PACKAGE_PIN $pin IOSTANDARD LVCMOS12} \[get_ports $p\]"
    }
    set clk [get_ports -quiet clk]
    if {[llength $clk] > 0} {
        puts $f "create_clock -period [expr {[set ::CLK_PERIOD_NS]}] -name sys_clk \[get_ports clk\]"
    }
    close $f
    puts "引脚约束: $xdc_path ([llength $ports] 端口)"
}
