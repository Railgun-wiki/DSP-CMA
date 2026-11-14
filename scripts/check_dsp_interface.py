#!/usr/bin/env python3
"""DSP48E2 包装接口一致性检查 (F01 整改)。

将 rtl/common/dsp_mult3.v 的原语实例化端口/参数与官方 unisim 声明摘录
(rtl/ip/DSP48E2_unisim_decl.v, 纯文本参考件) 静态比对:
  1) 实例化连接的每个端口必须存在于官方声明且位宽一致;
  2) 官方必需连接端口 (输入) 不得遗漏连接 (悬空输入非法);
  3) 使用的参数必须存在于官方声明。
用法 (仓库根目录): python3 scripts/check_dsp_interface.py
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DECL = REPO / "rtl" / "ip" / "DSP48E2_unisim_decl.v"
WRAPPER = REPO / "rtl" / "common" / "dsp_mult3.v"


def parse_decl(text: str):
    """解析官方声明: 返回 {端口名: (方向, 位宽)} 与 {参数名: 默认值}。"""
    ports = {}
    for m in re.finditer(
        r"\b(input|output|inout)\s+(?:\[(\d+):(\d+)\]\s+)?(\w+)", text
    ):
        d, hi, lo, name = m.group(1), m.group(2), m.group(3), m.group(4)
        width = abs(int(hi) - int(lo)) + 1 if hi is not None else 1
        ports[name] = (d, width)
    params = {}
    for m in re.finditer(r"\bparameter\s+(?:integer\s+)?\[?(\d+):0\]?\s*(\w+)", text):
        params[m.group(2)] = int(m.group(1)) + 1
    for m in re.finditer(r"\bparameter\s+(?:integer\s+)?(\w+)\s*=", text):
        params.setdefault(m.group(1), None)
    return ports, params


def parse_wrapper_instantiation(text: str):
    """解析包装内 DSP48E2 实例: 返回 (端口连接 {port: expr}, 参数 {name: value})。"""
    m = re.search(r"DSP48E2\s*#\((.*?)\)\s*u_dsp48e2\s*\((.*?)\);", text, re.S)
    if not m:
        return None, None
    params = {}
    for pm in re.finditer(r"\.(\w+)\s*\(\s*([^)]*?)\s*\)", m.group(1)):
        params[pm.group(1)] = pm.group(2)
    conns = {}
    for cm in re.finditer(r"\.(\w+)\s*\(\s*([^)]*?)\s*\)", m.group(2)):
        conns[cm.group(1)] = cm.group(2)
    return conns, params


def width_of(expr: str):
    """从连接表达式推断位宽: 字面量与拼接/扩展。"""
    e = expr.replace(" ", "")
    m = re.match(r"^(\d+)'[dhsb]", e)
    if m:
        return int(m.group(1))
    m = re.match(r"^\{(\d+)\{", e)      # {N{pattern}}
    if m:
        return None                     # 复制常量, 由内部字面量决定
    m = re.match(r"^\{\{\d+\{\w+\[(\d+)\]\}\},\s*\w+\}$", e)  # 符号扩展拼接
    if m:
        return None
    m = re.search(r"\[(\d+):(\d+)\]", e)
    if m:
        return abs(int(m.group(1)) - int(m.group(2))) + 1
    return None


def main() -> None:
    if not DECL.exists():
        print("FAIL 官方声明参考件缺失:", DECL)
        sys.exit(1)
    ports, params = parse_decl(DECL.read_text(encoding="utf-8"))
    text = WRAPPER.read_text(encoding="utf-8")
    conns, used_params = parse_wrapper_instantiation(text)
    fails = []
    if conns is None:
        fails.append("未找到 DSP48E2 实例化")
    else:
        for name, expr in sorted(conns.items()):
            if name not in ports:
                fails.append(f"端口 {name} 不在官方声明中")
                continue
            d, w = ports[name]
            if d == "output" and expr == "":
                continue                      # 输出悬空合法
            we = width_of(expr)
            if we is not None and we != w:
                fails.append(f"端口 {name} 位宽 {we} != 官方 {w}")
        # 官方输入端口必须全部连接 (悬空输入非法)
        unconnected = [n for n, (d, _) in ports.items()
                       if d == "input" and n not in conns]
        if unconnected:
            fails.append("输入端口未连接: " + ", ".join(unconnected))
        for name, val in sorted(used_params.items()):
            if name not in params:
                fails.append(f"参数 {name} 不在官方声明中")
            elif params[name] is not None:
                vm = re.match(r"^\s*(\d+)", val)
                if vm and int(vm.group(1)) > params[name]:
                    fails.append(f"参数 {name} 位宽 {vm.group(1)} > 官方 {params[name]}")
    for f in fails:
        print("[FAIL]", f)
    if fails:
        print(f"DSP48E2 接口一致性: FAIL ({len(fails)} 项)")
        sys.exit(1)
    print(f"DSP48E2 接口一致性: PASS ({len(conns)} 端口 / {len(used_params)} 参数与官方声明一致)")


if __name__ == "__main__":
    main()
