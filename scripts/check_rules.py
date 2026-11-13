#!/usr/bin/env python3
"""规则检查器 (AGENTS 6/7): 禁用 API、综合源数据乘法、绝对路径、交付完整性。

用法 (仓库根目录): python3 scripts/check_rules.py
输出逐条 PASS/FAIL; 任一 FAIL 时退出码 1。检测器允许注释、隔离验证
模型 (rtl/sim) 与参数上下文的乘号, 避免机械误报 (AGENTS 7)。
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RESULTS = []


def rule(name: str, ok: bool, detail: str = "") -> None:
    RESULTS.append((name, ok, detail))
    print(f"[{'PASS' if ok else 'FAIL'}] {name}" + (f" — {detail}" if detail else ""))


def strip_matlab_comments(text: str) -> str:
    """去掉 MATLAB 行注释、块注释与字符串字面量 (避免模式串误报)。"""
    text = re.sub(r"%\{.*?%\}", "", text, flags=re.S)
    text = re.sub(r"'[^']*'", "'STR'", text)   # 字符串字面量占位
    out = []
    for line in text.splitlines():
        out.append(re.sub(r"%.*$", "", line))
    return "\n".join(out)


def strip_verilog_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r"//[^\n]*", "", text)


def check_matlab_banned_apis() -> None:
    """正式 MATLAB 路径禁止内置 FFT/卷积/均衡器 (B05 设计约束)。"""
    banned = re.compile(
        r"\b(fft|ifft|fft2|ifft2|fftn|ifftn|dftmtx|cconv|fftfilt|"
        r"comm\.|commsrc\.)\s*\(", re.I
    )
    hits = []
    for p in sorted((REPO / "matlab").rglob("*.m")):
        text = strip_matlab_comments(p.read_text(encoding="utf-8"))
        for m in banned.finditer(text):
            hits.append(f"{p.relative_to(REPO)}:{text[:m.start()].count(chr(10)) + 1}:{m.group(1)}")
    rule("MATLAB 禁用 API", not hits, "; ".join(hits[:6]))


def check_matlab_hygiene() -> None:
    """核心模块禁止 clear/clc/close all、绝对路径、隐式全局。"""
    bad_clear = []
    bad_path = []
    for p in sorted((REPO / "matlab").rglob("*.m")):
        rel = str(p.relative_to(REPO))
        text = strip_matlab_comments(p.read_text(encoding="utf-8"))
        # 核心模块 (非 tests): clear/clc/close all
        if "/tests/" not in rel and "matlab/tests" not in rel:
            for kw in ("clear", "clc", "close all"):
                if re.search(rf"(?<![.\w])({re.escape(kw)})", text):
                    bad_clear.append(f"{rel}:{kw}")
        if re.search(r"(/home/|[A-Z]:\\\\|/Users/)", text):
            bad_path.append(rel)
    rule("MATLAB 核心 clear/clc/close all", not bad_clear, "; ".join(bad_clear[:5]))
    rule("MATLAB 无绝对路径", not bad_path, "; ".join(bad_path[:5]))


def check_rtl_datapath_multiply() -> None:
    """综合源码禁止数据通路乘法 `*` (H04)。

    判定口径: 仅扫描 assign 语句与 always 块内的数据行; parameter/
    localparam、常量函数体、复制常量 {N{...}}、循环边界中的乘号属于
    常量计算, 依 AGENTS "常量索引、位宽计算中的乘号可用" 放行。
    """
    synth_files = sorted(
        list((REPO / "rtl" / "common").glob("*.v"))
        + list((REPO / "rtl" / "fft").glob("*.v"))
    )
    hits = []
    for p in synth_files:
        text = strip_verilog_comments(p.read_text(encoding="utf-8"))
        lines = text.splitlines()
        in_always = False
        in_function = False
        for i, line in enumerate(lines, 1):
            st = line.strip()
            if re.match(r"\bfunction\b", st):
                in_function = True
            if re.match(r"\balways\b", st):
                in_always = True
                continue
            if re.match(r"\bassign\b", st):
                pass  # assign 数据行: 直接检查
            elif not in_always or in_function:
                # 非数据行: 参数/常量函数/块首等上下文, 放行
                if re.match(r"\b(endfunction)\b", st):
                    in_function = False
                if re.match(r"\b(end|else\b|begin\b|if\b|for\b|case\b|endcase\b)", st) and in_always and not in_function:
                    pass  # always 内控制行仍需检查其表达式
                else:
                    if re.match(r"\b(end)\b", st):
                        in_always = False
                    continue
            if re.match(r"\b(localparam|parameter)\b", st):
                continue
            # 常量上下文放行: 复制 {EXPR{...}}、位宽 [..]、for 循环边界
            if re.match(r"\bfor\b", st):
                continue
            probe = re.sub(r"\{[^{}]*\{[^{}]*\}[^{}]*\}", "REPL", st)
            probe = re.sub(r"\[[^\]]*\]", "[]", probe)
            if re.search(r"\*", probe):
                hits.append(f"{p.relative_to(REPO)}:{i}:{st.strip()[:60]}")
            if re.match(r"\bend\b", st):
                in_always = False
    rule("综合源数据通路乘法 *", not hits, "; ".join(hits[:5]))


def check_rtl_synth_hygiene() -> None:
    """综合源禁止仿真专用构造: initial/#延时/real/系统任务。"""
    bad = []
    for p in sorted(
        list((REPO / "rtl" / "common").glob("*.v"))
        + list((REPO / "rtl" / "fft").glob("*.v"))
    ):
        text = strip_verilog_comments(p.read_text(encoding="utf-8"))
        rel = str(p.relative_to(REPO))
        if re.search(r"\binitial\b", text):
            bad.append(f"{rel}:initial")
        if re.search(r"#\d", text):
            bad.append(f"{rel}:#delay")
        if re.search(r"\breal\b", text):
            bad.append(f"{rel}:real")
        if re.search(r"\$(display|fwrite|fopen|readmem)", text):
            bad.append(f"{rel}:$sysfunc")
    rule("综合源无仿真构造", not bad, "; ".join(bad[:5]))


def check_deliverables() -> None:
    """AGENTS 3/8 规定的关键交付文件存在性。"""
    required = [
        "AGENTS.md",
        "README.md",
        "docs/requirements.md",
        "docs/architecture.md",
        "docs/validation.md",
        "docs/report.md",
        "docs/presentation.md",
        "matlab/run_all.m",
        "matlab/config/default_config.m",
        "scripts/prepare_data.py",
        "scripts/run_verilator.sh",
        "scripts/vivado/create_project.tcl",
        "scripts/vivado/run_sim.tcl",
        "scripts/vivado/run_impl.tcl",
        "rtl/fft/fft32_top.v",
        "rtl/fft/fft64_top.v",
        "rtl/tb/vectors/manifest.json",
    ]
    missing = [f for f in required if not (REPO / f).exists()]
    rule("关键交付文件", not missing, "; ".join(missing[:6]))


def check_result_metadata() -> None:
    """最新运行目录必须含 run_meta.json (含数据 SHA-256)。"""
    rdir = REPO / "results"
    runs = sorted([d for d in rdir.iterdir() if d.is_dir()]) if rdir.exists() else []
    if not runs:
        rule("结果元数据", False, "results/ 下无运行目录")
        return
    latest = runs[-1]
    meta = latest / "run_meta.json"
    ok = meta.exists() and "sha256" in meta.read_text(encoding="utf-8")
    rule("结果元数据", ok, str(latest.relative_to(REPO)))


def main() -> None:
    check_matlab_banned_apis()
    check_matlab_hygiene()
    check_rtl_datapath_multiply()
    check_rtl_synth_hygiene()
    check_deliverables()
    check_result_metadata()
    n_fail = sum(1 for _, ok, _ in RESULTS if not ok)
    print(f"规则检查: {len(RESULTS) - n_fail}/{len(RESULTS)} PASS")
    sys.exit(1 if n_fail else 0)


if __name__ == "__main__":
    main()
