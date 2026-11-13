# run_sim.tcl: Vivado xsim 行为仿真 (H05 补跑入口)。
# 用法 (仓库根目录):
#   vivado -mode batch -source scripts/vivado/run_sim.tcl -tclargs <tb32|tb64|mult|bfly>
# 各 TB 自检并打印 PASS/FAIL; 存在 FAIL 时以非零码退出。
source scripts/vivado/common.tcl
check_repo_root

if {$argc < 1} {
    puts "用法: -tclargs <tb32|tb64|mult|bfly>"
    exit 1
}
set sel [lindex $argv 0]
set TOPMAP {tb32 tb_fft32 tb64 tb_fft64 mult tb_dsp_mult3 bfly tb_bfly2}
if {[dict exists $TOPMAP $sel]} {
    set TOP [dict get $TOPMAP $sel]
} else {
    puts "未知用例: $sel"
    exit 1
}

if {![file exists [file join build/vivado dspcma.xpr]]} {
    exec vivado -mode batch -source scripts/vivado/create_project.tcl >@ stdout 2>@ stderr
}
open_project [file join build/vivado dspcma.xpr]
set_property top $TOP [current_fileset -simset]
update_compile_order -fileset sim_1

# xsim 运行目录非仓库根: 通过 plusarg 传入向量目录 (TB 支持 +vectors=)
set_property -name {xsim.simulate.xsim.more_options} \
    -value {-testplusarg vectors=[pwd]/rtl/tb/vectors} -objects [current_fileset -simset]

launch_simulation
run all

# xsim 控制台输出含 TB 的 PASS/FAIL; 从日志复核
set LOG [file join [get_property DIRECTORY [current_simulation]] xsim.log]
if {![file exists $LOG]} {
    set LOG [file join [get_property DIRECTORY [current_simulation]] xelab.log]
}
set pass 0
if {[file exists $LOG]} {
    set fh [open $LOG r]
    set content [read $fh]
    close $fh
    if {[string first "PASS" $content] >= 0 && [string first "FAIL" $content] < 0} {
        set pass 1
    }
}
if {$pass} {
    puts "VIVADO_SIM PASS ($TOP)"
} else {
    puts "VIVADO_SIM FAIL ($TOP): 详见 $LOG"
    exit 1
}
close_sim
close_project
