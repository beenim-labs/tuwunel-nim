#!/usr/bin/env python3
"""Fail when generated Nim scaffolds accidentally contain raw Rust syntax."""

from __future__ import annotations

import pathlib
import re
import sys


ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "src"

PATTERNS = [
    re.compile(r"^\s*(pub\s+)?fn\s+\w+\s*\("),
    re.compile(r"^\s*impl(\s|<)"),
    re.compile(r"^\s*use\s+(crate|super|std)::"),
    re.compile(r"\blet\s+mut\s+\w+"),
    re.compile(r"::\w"),
    re.compile(r"=>\s*\{?"),
]

ALLOW_LINE_SUBSTRINGS = [
    "RustPath* =",
    "rustType:",
    "rust_fn:",
    "serde_json::Value",
    "BTreeMap<String",
    "BTreeSet<String",
    "HashSet<",
    "Vec<",
    "Option<",
]


def strip_strings(line: str) -> str:
    out = []
    in_string = False
    escaped = False
    for ch in line:
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            out.append(" ")
        else:
            if ch == "#":
                break
            if ch == '"':
                in_string = True
                out.append(" ")
            else:
                out.append(ch)
    return "".join(out)


def main() -> int:
    failures: list[str] = []
    for path in sorted(SRC.rglob("*.nim")):
        rel = path.relative_to(ROOT)
        for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            if any(allowed in raw for allowed in ALLOW_LINE_SUBSTRINGS):
                continue
            scanned = strip_strings(raw)
            for pattern in PATTERNS:
                if pattern.search(scanned):
                    failures.append(f"{rel}:{lineno}: {raw.strip()}")
                    break

    if failures:
        print("Raw Rust syntax found in Nim sources:", file=sys.stderr)
        for failure in failures[:80]:
            print(failure, file=sys.stderr)
        if len(failures) > 80:
            print(f"... {len(failures) - 80} more", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
