#!/usr/bin/env python3
"""Extract baseline parity inventory from Rust tuwunel snapshot."""

from __future__ import annotations

import json
import re
import subprocess
from collections import Counter, defaultdict
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Tuple

ROOT = Path(__file__).resolve().parents[1]
RUST_ROOT = ROOT.parent / "tuwunel"
RUST_SRC = RUST_ROOT / "src"
OUT = ROOT / "docs" / "parity"

FN_NAME_RE = re.compile(r"\bfn\s+([A-Za-z_][A-Za-z0-9_]*)")
CLIENT_ROUTE_RE = re.compile(r"\.ruma_route\(&client::([A-Za-z0-9_]+)\)")
SERVER_ROUTE_RE = re.compile(r"\.ruma_route\(&server::([A-Za-z0-9_]+)\)")
MANUAL_ROUTE_RE = re.compile(r"\.route\(\s*\"([^\"]+)\"")
DB_CF_RE = re.compile(r"name:\s*\"([^\"]+)\"")
DESCRIPTOR_NAME_RE = re.compile(r'name:\s*"([^"]+)"')
DEFAULT_DOC_RE = re.compile(r"^\s*///\s*default:\s*(.+)\s*$", re.IGNORECASE)
SERDE_DEFAULT_FN_RE = re.compile(r'default\s*=\s*"([^"]+)"')
SERDE_DEFAULT_ENABLED_RE = re.compile(r"\bdefault\b")
STRUCT_START_RE = re.compile(r"^\s*(?:pub\s+)?struct\s+([A-Za-z_][A-Za-z0-9_]*)\s*\{")
FIELD_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


@dataclass
class FunctionFile:
    rust_path: str
    crate: str
    module: str
    function_count: int
    functions: List[str]


@dataclass
class ConfigField:
    key: str
    scope: str
    qualified_key: str
    rust_type: str
    line: int
    default_doc: str
    serde_default_provider: str
    serde_default_enabled: bool


@dataclass
class ModuleMapItem:
    rust_path: str
    nim_path: str
    crate: str



def run(cmd: List[str], cwd: Path | None = None) -> str:
    cp = subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, text=True)
    return cp.stdout.strip()



def rust_commit() -> str:
    return run(["git", "rev-parse", "HEAD"], cwd=RUST_ROOT)



def extract_functions() -> Dict[str, object]:
    files_by_crate = Counter()
    files_map: Dict[str, FunctionFile] = {}

    for path in sorted(RUST_SRC.rglob("*.rs")):
        rel = path.relative_to(RUST_SRC)
        rel_s = str(rel).replace("\\", "/")
        parts = rel.parts
        crate = parts[0] if parts else ""
        module = parts[1] if len(parts) > 1 else parts[0]
        files_map[rel_s] = FunctionFile(
            rust_path=rel_s,
            crate=crate,
            module=module,
            function_count=0,
            functions=[],
        )
        files_by_crate[crate] += 1

    rg_out = run(
        [
            "rg",
            "-n",
            r"^\s*(pub\s+)?(async\s+)?fn\s+",
            "src",
            "-g",
            "*.rs",
        ],
        cwd=RUST_ROOT,
    )

    for raw in rg_out.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        parts = raw.split(":", 2)
        if len(parts) != 3:
            continue
        path_s, _lineno, line = parts
        if path_s.startswith("src/"):
            rel_s = path_s[4:]
        else:
            rel_s = path_s

        ff = files_map.get(rel_s)
        if ff is None:
            continue

        m = FN_NAME_RE.search(line)
        fn_name = m.group(1) if m else "unknown_fn"
        ff.functions.append(fn_name)
        ff.function_count += 1

    files = list(files_map.values())
    by_crate = Counter({crate: 0 for crate in files_by_crate})
    for f in files:
        by_crate[f.crate] += f.function_count

    return {
        "total_functions": int(sum(by_crate.values())),
        "by_crate": [
            {
                "crate": crate,
                "function_count": int(by_crate[crate]),
                "file_count": int(files_by_crate[crate]),
            }
            for crate in sorted(by_crate)
        ],
        "files": [asdict(f) for f in files],
    }



def extract_routes() -> Dict[str, object]:
    router_rs = (RUST_SRC / "api" / "router.rs").read_text(encoding="utf-8", errors="ignore")
    client = CLIENT_ROUTE_RE.findall(router_rs)
    server = SERVER_ROUTE_RE.findall(router_rs)
    manual = MANUAL_ROUTE_RE.findall(router_rs)
    return {
        "client_ruma_routes": client,
        "server_ruma_routes": server,
        "manual_routes": manual,
        "counts": {
            "client_ruma_routes": len(client),
            "server_ruma_routes": len(server),
            "manual_routes": len(manual),
            "total": len(client) + len(server) + len(manual),
        },
    }



def extract_config_fields() -> Dict[str, object]:
    path = RUST_SRC / "core" / "config" / "mod.rs"
    source_lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    fields: List[ConfigField] = []
    pending_default_doc = ""
    pending_attrs: List[str] = []
    attr_buf: List[str] = []
    attr_depth = 0
    current_struct = ""
    struct_depth = 0

    def clear_pending() -> None:
        nonlocal pending_default_doc, pending_attrs, attr_buf, attr_depth
        pending_default_doc = ""
        pending_attrs = []
        attr_buf = []
        attr_depth = 0

    def parse_field_decl(line: str) -> Tuple[str, str] | None:
        stripped = line.strip()
        if stripped.startswith("pub "):
            stripped = stripped[4:].strip()
        elif stripped.startswith("pub("):
            close = stripped.find(")")
            if close < 0:
                return None
            stripped = stripped[close + 1 :].strip()
        else:
            return None

        if not stripped.endswith(",") or ":" not in stripped:
            return None

        name_part, type_part = stripped.split(":", 1)
        name = name_part.strip()
        rust_type = type_part[:-1].strip()
        if not FIELD_NAME_RE.fullmatch(name) or not rust_type:
            return None
        return name, rust_type

    for lineno, line in enumerate(source_lines, start=1):
        m_doc = DEFAULT_DOC_RE.search(line)
        if m_doc:
            pending_default_doc = m_doc.group(1).strip()
            continue

        stripped = line.strip()
        m_struct = STRUCT_START_RE.match(line)
        if m_struct and struct_depth == 0:
            current_struct = m_struct.group(1)
            struct_depth = line.count("{") - line.count("}")
            if struct_depth <= 0:
                current_struct = ""
                struct_depth = 0
            clear_pending()
            continue

        if current_struct:
            if stripped.startswith("#[") or attr_depth > 0:
                attr_buf.append(stripped)
                attr_depth += stripped.count("[") - stripped.count("]")
                if attr_depth <= 0:
                    pending_attrs.append(" ".join(attr_buf))
                    attr_buf = []
                    attr_depth = 0
                continue

            field = parse_field_decl(line)
            if field is not None:
                key, rust_type = field
                serde_attrs = " ".join(
                    attr for attr in pending_attrs if re.match(r"^#\[\s*serde\b", attr)
                )
                provider_match = SERDE_DEFAULT_FN_RE.search(serde_attrs)
                provider = provider_match.group(1) if provider_match else ""
                has_default = bool(SERDE_DEFAULT_ENABLED_RE.search(serde_attrs))

                fields.append(
                    ConfigField(
                        key=key,
                        scope=current_struct,
                        qualified_key=f"{current_struct}.{key}",
                        rust_type=rust_type,
                        line=lineno,
                        default_doc=pending_default_doc,
                        serde_default_provider=provider,
                        serde_default_enabled=has_default,
                    )
                )
                clear_pending()
                continue

            if stripped and not stripped.startswith("///"):
                pending_attrs = []
                pending_default_doc = ""

            struct_depth += line.count("{") - line.count("}")
            if struct_depth <= 0:
                current_struct = ""
                struct_depth = 0
                clear_pending()
            continue

        if stripped and not stripped.startswith("///"):
            pending_attrs = []
            pending_default_doc = ""

    source = "\n".join(source_lines)
    default_functions: Dict[str, str] = {}
    marker_re = re.compile(
        r"(?m)^\s*(?:pub\s+)?fn\s+([A-Za-z_][A-Za-z0-9_]*)\s*\([^)]*\)\s*->\s*[^{}]+\{"
    )
    for match in marker_re.finditer(source):
        name = match.group(1)
        brace_start = source.find("{", match.start())
        if brace_start < 0:
            continue

        depth = 0
        i = brace_start
        while i < len(source):
            ch = source[i]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1

        if depth != 0:
            continue

        body = source[brace_start + 1 : i].strip()
        default_functions[name] = body

    return {
        "source": "src/core/config/mod.rs",
        "field_count": len(fields),
        "fields": [asdict(f) for f in fields],
        "default_function_count": len(default_functions),
        "default_functions": default_functions,
    }



def extract_db_cfs() -> Dict[str, object]:
    path = RUST_SRC / "database" / "maps.rs"
    source = path.read_text(encoding="utf-8", errors="ignore")
    names = DB_CF_RE.findall(source)

    descriptors = []
    cursor = 0
    marker = "Descriptor {"
    while True:
        start = source.find(marker, cursor)
        if start < 0:
            break

        brace_start = source.find("{", start)
        if brace_start < 0:
            break

        depth = 0
        i = brace_start
        while i < len(source):
            ch = source[i]
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1

        if depth != 0:
            break

        block = source[brace_start : i + 1]
        cursor = i + 1

        name_match = DESCRIPTOR_NAME_RE.search(block)
        if not name_match:
            continue

        name = name_match.group(1)
        dropped = "..descriptor::DROPPED" in block
        ignored = "..descriptor::IGNORED" in block
        descriptors.append(
            {
                "name": name,
                "dropped": dropped,
                "ignored": ignored,
            }
        )

    if descriptors:
        names = [d["name"] for d in descriptors]

    required_names = [
        d["name"]
        for d in descriptors
        if not d["dropped"] and not d["ignored"]
    ]

    return {
        "source": "src/database/maps.rs",
        "column_family_count": len(names),
        "column_families": names,
        "descriptor_count": len(descriptors),
        "required_column_family_count": len(required_names),
        "dropped_column_family_count": sum(1 for d in descriptors if d["dropped"]),
        "descriptors": descriptors,
        "required_column_families": required_names,
    }



def extract_module_map(functions: Dict[str, object]) -> Dict[str, object]:
    items: List[ModuleMapItem] = []
    for f in functions["files"]:
        rust_path = f["rust_path"]
        crate = f["crate"]
        nim_path = "src/" + rust_path[:-3] + ".nim"
        items.append(ModuleMapItem(rust_path=rust_path, nim_path=nim_path, crate=crate))

    return {
        "count": len(items),
        "items": [asdict(i) for i in items],
    }



def extract_complement_stats() -> Dict[str, object]:
    path = RUST_ROOT / "tests" / "complement" / "results.jsonl"
    counts = Counter()
    tests = []

    if path.exists():
        for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            raw = raw.strip()
            if not raw:
                continue
            obj = json.loads(raw)
            action = obj.get("Action", "unknown")
            name = obj.get("Test", "")
            counts[action] += 1
            tests.append({"action": action, "test": name})

    return {
        "source": "tests/complement/results.jsonl",
        "counts": {
            "pass": int(counts.get("pass", 0)),
            "fail": int(counts.get("fail", 0)),
            "skip": int(counts.get("skip", 0)),
            "total": int(sum(counts.values())),
        },
        "tests": tests,
    }



def write_json(name: str, obj: Dict[str, object]) -> None:
    path = OUT / name
    path.write_text(json.dumps(obj, indent=2, sort_keys=False) + "\n", encoding="utf-8")



def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)

    commit = rust_commit()
    functions = extract_functions()
    routes = extract_routes()
    config = extract_config_fields()
    db = extract_db_cfs()
    module_map = extract_module_map(functions)
    complement = extract_complement_stats()

    timestamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat()

    baseline = {
        "baseline": {
            "rust_root": str(RUST_ROOT.resolve()),
            "rust_commit": commit,
            "generated_at_utc": timestamp,
            "policy": "baseline-frozen",
        },
        "totals": {
            "rust_function_total": functions["total_functions"],
            "route_total": routes["counts"]["total"],
            "config_field_total": config["field_count"],
            "db_column_family_total": db["column_family_count"],
        },
        "route_counts": routes["counts"],
        "complement_counts": complement["counts"],
    }

    write_json("baseline.json", baseline)
    write_json("rust_function_inventory.json", functions)
    write_json("route_inventory.json", routes)
    write_json("config_inventory.json", config)
    write_json("db_cf_inventory.json", db)
    write_json("module_map.json", module_map)
    write_json("complement_baseline.json", complement)

    print("Wrote parity inventory:")
    for n in [
        "baseline.json",
        "rust_function_inventory.json",
        "route_inventory.json",
        "config_inventory.json",
        "db_cf_inventory.json",
        "module_map.json",
        "complement_baseline.json",
    ]:
        print(" -", n)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
