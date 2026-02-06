#!/usr/bin/env python3
"""Render docs/parity_matrix.md from machine-readable inventory files."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARITY = ROOT / "docs" / "parity"
OUT = ROOT / "docs" / "parity_matrix.md"


def load(name: str):
    return json.loads((PARITY / name).read_text(encoding="utf-8"))


def load_optional(name: str, default):
    path = PARITY / name
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    baseline = load("baseline.json")
    fn = load("rust_function_inventory.json")
    routes = load("route_inventory.json")
    module_coverage = load_optional(
        "module_coverage.json",
        {"mapped": 0, "present": 0, "missing": 0, "missing_paths": []},
    )

    b = baseline["baseline"]
    totals = baseline["totals"]
    rc = baseline["route_counts"]
    cc = baseline["complement_counts"]

    m1_complete = module_coverage["mapped"] > 0 and module_coverage["missing"] == 0
    m1_status = "Implemented" if m1_complete else "In progress"
    m1_note = (
        "Module map scaffold complete; generated artifacts and inventories synced"
        if m1_complete
        else (
            f"Module scaffold incomplete; missing "
            f"{module_coverage['missing']} of {module_coverage['mapped']} mapped modules"
        )
    )

    crate_rows = "\n".join(
        f"| `{item['crate']}` | {item['function_count']} | {item['file_count']} |"
        for item in fn["by_crate"]
    )

    md = f"""# Parity Matrix (Baseline-Pinned)

Generated from `tools/*` against Rust baseline commit `{b['rust_commit']}`.

## Baseline summary

| Item | Count |
| --- | ---: |
| Rust functions | {totals['rust_function_total']} |
| Client routes (`.ruma_route`) | {rc['client_ruma_routes']} |
| Server routes (`.ruma_route`) | {rc['server_ruma_routes']} |
| Manual routes (`.route`) | {rc['manual_routes']} |
| Config fields (public) | {totals['config_field_total']} |
| DB column families | {totals['db_column_family_total']} |
| Complement pass | {cc['pass']} |
| Complement fail | {cc['fail']} |
| Complement skip | {cc['skip']} |

## Module coverage

| Item | Count |
| --- | ---: |
| Mapped modules | {module_coverage['mapped']} |
| Present modules | {module_coverage['present']} |
| Missing modules | {module_coverage['missing']} |

## Milestone status

| Milestone | Status | Notes |
| --- | --- | --- |
| M0 bootstrap | Implemented | Project scaffold, Nim build/test tasks, CI workflow, baseline metadata freeze |
| M1 inventory + codegen | {m1_status} | {m1_note} |
| M2 core runtime/CLI/config parity | Implemented | Compatibility config loader/merge path, argument transforms, and deterministic bootstrap diagnostics implemented |
| M3 database compatibility | Implemented | Serializer/deserializer primitives, CF descriptor policy, in-memory backend, and compile-flagged RocksDB compatibility behaviors with tests |
| M4+ | Pending | Service graph, routes, Matrix semantics, federation, admin, perf |

## Rust crate inventory

| Crate | Functions | Files |
| --- | ---: | ---: |
{crate_rows}

## Generated artifacts

- `docs/parity/baseline.json`
- `docs/parity/rust_function_inventory.json`
- `docs/parity/route_inventory.json`
- `docs/parity/config_inventory.json`
- `docs/parity/db_cf_inventory.json`
- `docs/parity/module_map.json`
- `docs/parity/module_coverage.json`
- `docs/parity/complement_baseline.json`
- `src/api/generated_route_inventory.nim`
- `src/api/generated_route_types.nim`
- `src/core/generated_config_keys.nim`
- `src/core/generated_function_inventory.nim`
- `src/database/generated_column_families.nim`
- `src/database/generated_column_family_descriptors.nim`
- `src/service/generated_service_inventory.nim`

## Notes

- Baseline policy is frozen to local Rust snapshot and should only change via explicit re-baseline.
- Generated files must be refreshed through `nimble parity_sync`.
"""

    OUT.write_text(md, encoding="utf-8")
    print("Wrote", OUT)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
