# run_impl.tcl: 综合 + Implementation + 报告 (H06 补跑入口)。
# 用法 (仓库根目录):
#   vivado -mode batch -source scripts/vivado/run_impl.tcl -tclargs <fft32_top|fft64_top>
# 时序未满足或实现失败时以非零码退出; 报告写入 results/vivado_impl_<top>/。

source scripts/vivado/common.tcl
check_repo_root

if {$argc < 1} {
    puts "用法: -tclargs <fft32_top|fft64_top>"
    exit 1
}
set TOP [lindex $argv 0]
if {$TOP ne "fft32_top" && $TOP ne "fft64_top"} {
    puts "未知顶层: $TOP"
    exit 1
}

if {![file exists [file join build/vivado dspcma.xpr]]} {
    exec vivado -mode batch -source scripts/vivado/create_project.tcl >@ stdout 2>@ stderr
}
open_project [file join build/vivado dspcma.xpr]
set_property top $TOP [current_fileset]
update_compile_order -fileset sources_1

# 引脚/时钟约束 (静态端口清单 + 合成引脚; F02 整改: 不在设计打开前
# 查询 get_ports; 清理其他顶层遗留的约束文件避免积累)
file mkdir build/vivado/constraints
foreach old [get_files -quiet -of_objects [get_filesets constrs_1]] {
    remove_files -fileset [get_filesets constrs_1] $old
}
set XDC [file join [file normalize [file join build vivado constraints]] ${TOP}.xdc]
if {$TOP eq "fft32_top"} {
    make_pin_constraints $TOP 32 $XDC
} else {
    make_pin_constraints $TOP 64 $XDC
}
add_files -fileset constrs_1 $XDC

# 综合 (fail 时 launch_runs 返回错误)
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%" ||
    [get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    puts "SYNTH FAIL: [get_property STATUS [get_runs synth_1]]"
    exit 1
}

# Implementation
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    puts "IMPL FAIL: [get_property STATUS [get_runs impl_1]]"
    exit 1
}

# 时序检查
open_run impl_1
set WNS [get_property SLACK [get_timing_paths -setup]]
set WHS [get_property SLACK [get_timing_paths -hold]]
puts "Setup WNS: $WNS ns, Hold WHS: $WHS ns"
set OUTDIR [file join results "vivado_impl_$TOP"]
file mkdir $OUTDIR
report_utilization -file [file join $OUTDIR utilization.rpt]
report_timing_summary -file [file join $OUTDIR timing_summary.rpt]
report_clocks -file [file join $OUTDIR clocks.rpt]
write_checkpoint -file [file join $OUTDIR ${TOP}_routed.dcp]
if {$WNS < 0 || $WHS < 0} {
    puts "TIMING FAIL: setup/hold 未满足约束 (250 MHz)"
    exit 1
}
puts "IMPL PASS: $TOP 资源与时序报告见 $OUTDIR"
close_project
