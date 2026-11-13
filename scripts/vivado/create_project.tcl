# create_project.tcl: 创建 Vivado 工程 (H05/H06 补跑入口)。
# 用法 (仓库根目录):
#   vivado -mode batch -source scripts/vivado/create_project.tcl
# 工程文件落在 build/vivado/ (gitignore 内); 不提交生成目录。
source scripts/vivado/common.tcl
check_repo_root

set PROJ_DIR "build/vivado"
file mkdir $PROJ_DIR
if {[file exists [file join $PROJ_DIR dspcma.xpr]]} {
    puts "工程已存在, 跳过创建"
} else {
    create_project dspcma $PROJ_DIR -part $DEVICE -force
    foreach f $SYNTH_SOURCES {
        add_files -fileset sources_1 $f
    }
    foreach d $INCLUDE_DIRS {
        set_property include_dirs [concat [get_property include_dirs [current_fileset]] [list [file normalize $d]]] [current_fileset]
    }
    foreach f $SIM_SOURCES {
        add_files -fileset sim_1 $f
    }
    # 仿真顶层与文件集: 乘法器用行为模型 (rtl/sim), 不含综合版原语文件
    set_property top tb_fft32 [current_fileset -simset]
    set_property -name {xsim.simulate.runtime} -value {-all} -objects [current_fileset -simset]
    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1
    puts "工程创建完成: $PROJ_DIR/dspcma.xpr (器件 $DEVICE)"
}
