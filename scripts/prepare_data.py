#!/usr/bin/env python3
"""校验并准备课程原始材料。

从 docs/requirement/大作业matlab.zip 提取参考文件到 data/reference/（已存在且内容
一致时跳过，不覆盖用户修改），并把所有原始材料的 SHA-256 写入
data/reference/manifest.json。

用法（仓库根目录）:  python3 scripts/prepare_data.py
"""
import hashlib
import json
import zipfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
REQ_DIR = REPO / "docs" / "requirement"
REF_DIR = REPO / "data" / "reference"
ZIP_PATH = REQ_DIR / "大作业matlab.zip"
MANIFEST = REF_DIR / "manifest.json"

MEMBERS = ["Readme.txt", "CMA_homework.m", "CMA_reference.m", "TD_TRdata.mat"]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> None:
    REF_DIR.mkdir(parents=True, exist_ok=True)
    entries = {}

    for src in sorted(REQ_DIR.iterdir()):
        if src.is_file():
            entries[str(src.relative_to(REPO))] = {
                "sha256": sha256(src),
                "bytes": src.stat().st_size,
            }

    with zipfile.ZipFile(ZIP_PATH) as zf:
        names = set(zf.namelist())
        missing = [m for m in MEMBERS if m not in names]
        if missing:
            raise SystemExit(f"FAIL: zip 缺少成员: {missing}")
        for name in MEMBERS:
            dest = REF_DIR / name
            if dest.exists():
                digest = sha256(dest)
                if digest != entries[str(ZIP_PATH.relative_to(REPO))]["sha256"]:
                    print(f"KEEP: {dest} 已存在且与包内成员比较跳过（不覆盖）")
            else:
                dest.write_bytes(zf.read(name))
                print(f"EXTRACT: {name}")

    for name in MEMBERS:
        dest = REF_DIR / name
        if dest.exists():
            entries[str(dest.relative_to(REPO))] = {
                "sha256": sha256(dest),
                "bytes": dest.stat().st_size,
            }

    MANIFEST.write_text(
        json.dumps(entries, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"OK: manifest -> {MANIFEST}")
    for key, val in entries.items():
        print(f"  {val['sha256'][:16]}...  {key}")


if __name__ == "__main__":
    main()
