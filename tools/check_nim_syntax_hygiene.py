#!/usr/bin/env python3
"""Fail when Rust syntax leaks into Nim source files."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GLOB = "src/**/*.nim"


@dataclass
class Violation:
    path: str
    line: int
    rule: str
    snippet: str


RULES = [
    ("crate_path", re.compile(r"\bcrate::")),
    ("namespace_path", re.compile(r"::")),
    ("await", re.compile(r"\.await\b")),
    ("mut_param", re.compile(r"\bmut\s+[A-Za-z_][A-Za-z0-9_]*\s*:")),
    (
        "rust_generic_type",
        re.compile(
            r"\b(?:Option|Result|Vec|HashMap|BTreeMap|BTreeSet|HashSet|Arc|Mutex|RwLock|Future)\s*<"
        ),
    ),
]


def scrub_source(text: str) -> list[str]:
    """Return source lines with strings/comments removed."""

    out_lines: list[str] = []
    in_block_comment = 0
    in_triple_string = False

    for raw_line in text.splitlines():
        line = raw_line
        i = 0
        out: list[str] = []
        in_string = False
        string_quote = ""
        escaped = False

        while i < len(line):
            if in_triple_string:
                if line.startswith('"""', i):
                    in_triple_string = False
                    i += 3
                else:
                    i += 1
                continue

            if in_block_comment > 0:
                if line.startswith("#[", i):
                    in_block_comment += 1
                    i += 2
                    continue
                if line.startswith("]#", i):
                    in_block_comment -= 1
                    i += 2
                    continue
                i += 1
                continue

            if in_string:
                if escaped:
                    escaped = False
                    i += 1
                    continue
                ch = line[i]
                if ch == "\\":
                    escaped = True
                    i += 1
                    continue
                if ch == string_quote:
                    in_string = False
                    string_quote = ""
                i += 1
                continue

            if line.startswith('"""', i):
                in_triple_string = True
                i += 3
                continue

            if line.startswith("#[", i):
                in_block_comment += 1
                i += 2
                continue

            if line[i] == "#":
                break

            if line[i] in ('"', "'"):
                in_string = True
                string_quote = line[i]
                i += 1
                continue

            out.append(line[i])
            i += 1

        out_lines.append("".join(out))

    return out_lines


def scan_file(path: Path) -> list[Violation]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    clean_lines = scrub_source(text)
    violations: list[Violation] = []

    for idx, line in enumerate(clean_lines, start=1):
        if not line.strip():
            continue
        for rule, pattern in RULES:
            if pattern.search(line):
                violations.append(
                    Violation(
                        path=str(path.relative_to(ROOT)),
                        line=idx,
                        rule=rule,
                        snippet=line.strip(),
                    )
                )
    return violations


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--glob", default=DEFAULT_GLOB, help="Glob to scan (default: src/**/*.nim)")
    args = parser.parse_args()

    files = sorted(ROOT.glob(args.glob))
    files = [p for p in files if p.is_file()]
    violations: list[Violation] = []
    for path in files:
        violations.extend(scan_file(path))

    if violations:
        print("Rust syntax hygiene check failed:")
        for v in violations:
            print(f" - {v.path}:{v.line} [{v.rule}] {v.snippet}")
        return 1

    print(f"Rust syntax hygiene check passed for {len(files)} files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
