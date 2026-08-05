#!/usr/bin/env python3
"""Lightweight static checks for MQL4 source (no MetaEditor required)."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def strip_comments(src: str) -> str:
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    out = []
    for line in src.splitlines():
        if "//" in line:
            line = line.split("//", 1)[0]
        out.append(line)
    return "\n".join(out)


def main() -> int:
    if len(sys.argv) < 2:
        print("Usage: mql4_static_check.py <file.mq4>")
        return 2

    path = Path(sys.argv[1])
    raw = path.read_text(encoding="utf-8", errors="replace")
    src = strip_comments(raw)
    errors: list[str] = []
    warns: list[str] = []

    if src.count("{") != src.count("}"):
        errors.append(f"Unbalanced braces: {{ {src.count('{')} }} {src.count('}')}")
    if src.count("(") != src.count(")"):
        errors.append(f"Unbalanced parens: ( {src.count('(')} ) {src.count(')')}")
    if src.count('"') % 2 != 0:
        errors.append("Unbalanced double quotes")

    if "#property strict" not in raw:
        warns.append("Missing #property strict")

    inputs = re.findall(r"^input\s+\S+\s+(\w+)", raw, flags=re.M)
    # separator inputs are UI-only by design
    for name in inputs:
        if name.startswith("InpSep"):
            continue
        # word-boundary usage outside the input declaration line
        uses = len(re.findall(rf"\b{name}\b", raw))
        if uses <= 1:
            errors.append(f"UI-only / unused input: {name}")

    # required API surface for this EA
    required = [
        "OnInit",
        "OnTick",
        "OrderSend",
        "OrderModify",
        "OrderDelete",
        "OrderClose",
        "iATR",
        "iMA",
        "OP_BUYSTOP",
        "OP_SELLSTOP",
    ]
    for token in required:
        if token not in raw:
            errors.append(f"Missing required token: {token}")

    print(f"File: {path}")
    print(f"Lines: {len(raw.splitlines())}")
    print(f"Inputs: {len(inputs)}")
    for w in warns:
        print(f"WARN: {w}")
    if errors:
        for e in errors:
            print(f"ERROR: {e}")
        print("RESULT: FAIL")
        return 1

    print("RESULT: PASS (static)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
