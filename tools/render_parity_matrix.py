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


def pct(numerator: int, denominator: int) -> str:
    if denominator <= 0:
        return "0.0%"
    return f"{(100.0 * numerator / denominator):.1f}%"


def main() -> int:
    baseline = load("baseline.json")
    fn = load("rust_function_inventory.json")
    routes = load("route_inventory.json")
    module_coverage = load_optional(
        "module_coverage.json",
        {"mapped": 0, "present": 0, "missing": 0, "missing_paths": []},
    )
    impl_coverage = load_optional(
        "implementation_coverage.json",
        {
            "total_modules": 0,
            "summary": {"scaffold": 0, "partial": 0, "implemented": 0, "missing": 0},
            "status_by_crate": [],
            "thresholds": {
                "all_modules_implemented": False,
                "database_modules_implemented": False,
            },
        },
    )
    route_behavior = load_optional(
        "route_behavior_coverage.json",
        {
            "summary": {
                "total_routes": 0,
                "registered_routes": 0,
                "auth_covered_routes": 0,
                "handler_covered_routes": 0,
                "error_shape_covered_routes": 0,
            },
            "thresholds": {
                "all_routes_registered": False,
                "all_routes_behavioral": False,
            },
        },
    )
    runtime_diff = load_optional(
        "runtime_diff_report.json",
        {
            "baseline_commit": "",
            "scenarios_total": 0,
            "passes_total": 0,
            "mismatches_total": 0,
            "skipped_total": 0,
            "results": [],
        },
    )
    config_behavior = load_optional(
        "config_behavior_coverage.json",
        {
            "summary": {
                "total_keys": 0,
                "typed_keys": 0,
                "default_keys": 0,
                "env_alias_keys": 0,
                "override_keys": 0,
            },
            "thresholds": {
                "all_keys_typed": False,
                "all_keys_have_defaults": False,
                "all_keys_env_alias_compatible": False,
                "all_keys_option_override_compatible": False,
                "m2_ready": False,
            },
        },
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

    m2_complete = bool(config_behavior.get("thresholds", {}).get("m2_ready", False))
    m2_status = "Implemented" if m2_complete else "In progress"
    cfg_summary = config_behavior.get("summary", {})
    cfg_total = int(cfg_summary.get("total_keys", 0))
    cfg_typed = int(cfg_summary.get("typed_keys", 0))
    cfg_default = int(cfg_summary.get("default_keys", 0))
    cfg_default_expected = int(cfg_summary.get("default_expected_keys", 0))
    cfg_default_expected_applied = int(cfg_summary.get("default_expected_applied_keys", 0))
    cfg_env = int(cfg_summary.get("env_alias_keys", 0))
    cfg_override = int(cfg_summary.get("override_keys", 0))
    m2_note = (
        "All config keys are typed/defaulted and override-compatible"
        if m2_complete
        else (
            f"typed={cfg_typed}/{cfg_total}, default={cfg_default_expected_applied}/{cfg_default_expected}, "
            f"env-alias={cfg_env}/{cfg_total}, option-override={cfg_override}/{cfg_total}"
        )
    )

    m3_complete = bool(impl_coverage.get("thresholds", {}).get("database_modules_implemented", False))
    m3_status = "Implemented" if m3_complete else "In progress"
    db_row = next(
        (r for r in impl_coverage.get("status_by_crate", []) if r.get("crate") == "database"),
        None,
    )
    db_total = int(db_row.get("total", 0)) if db_row else 0
    db_impl = int(db_row.get("implemented", 0)) if db_row else 0
    m3_note = (
        f"Database crate modules implemented={db_impl}/{db_total}"
        if db_total > 0
        else "Database crate implementation coverage unavailable"
    )
    diff_total = int(runtime_diff.get("scenarios_total", 0))
    diff_pass = int(runtime_diff.get("passes_total", 0))
    diff_mismatch = int(runtime_diff.get("mismatches_total", 0))
    diff_skipped = int(runtime_diff.get("skipped_total", 0))
    m4_complete = diff_total > 0 and diff_mismatch == 0 and diff_skipped == 0
    m4_status = "Implemented" if m4_complete else "In progress"
    m4_note = (
        "Rust-vs-Nim runtime diff is clean for all configured scenarios"
        if m4_complete
        else f"pass={diff_pass} mismatch={diff_mismatch} skipped={diff_skipped} total={diff_total}"
    )

    crate_rows = "\n".join(
        f"| `{item['crate']}` | {item['function_count']} | {item['file_count']} |"
        for item in fn["by_crate"]
    )
    impl = impl_coverage.get("summary", {})
    impl_total = int(impl_coverage.get("total_modules", 0))
    impl_crate_rows = "\n".join(
        "| `{crate}` | {implemented} | {partial} | {scaffold} | {missing} | {total} |".format(
            crate=item.get("crate", ""),
            implemented=int(item.get("implemented", 0)),
            partial=int(item.get("partial", 0)),
            scaffold=int(item.get("scaffold", 0)),
            missing=int(item.get("missing", 0)),
            total=int(item.get("total", 0)),
        )
        for item in impl_coverage.get("status_by_crate", [])
    )
    route_summary = route_behavior.get("summary", {})

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

## Behavioral implementation coverage

| Item | Count |
| --- | ---: |
| Implemented modules | {int(impl.get('implemented', 0))} |
| Partial modules | {int(impl.get('partial', 0))} |
| Scaffold modules | {int(impl.get('scaffold', 0))} |
| Missing modules | {int(impl.get('missing', 0))} |
| Implemented ratio | {pct(int(impl.get('implemented', 0)), impl_total)} |

## Route behavior coverage

| Item | Count |
| --- | ---: |
| Total routes | {int(route_summary.get('total_routes', 0))} |
| Registered routes | {int(route_summary.get('registered_routes', 0))} |
| Auth-covered routes | {int(route_summary.get('auth_covered_routes', 0))} |
| Handler-covered routes | {int(route_summary.get('handler_covered_routes', 0))} |
| Error-shape-covered routes | {int(route_summary.get('error_shape_covered_routes', 0))} |

## Runtime diff coverage

| Item | Count |
| --- | ---: |
| Total scenarios | {diff_total} |
| Passing scenarios | {diff_pass} |
| Mismatching scenarios | {diff_mismatch} |
| Skipped scenarios | {diff_skipped} |

## Config behavior coverage

| Item | Count |
| --- | ---: |
| Total config keys | {cfg_total} |
| Typed keys | {cfg_typed} |
| Keys with defaults (applied/expected) | {cfg_default_expected_applied}/{cfg_default_expected} |
| Keys with defaults (raw applied) | {cfg_default} |
| Env alias compatible keys | {cfg_env} |
| Option override compatible keys | {cfg_override} |

## Milestone status

| Milestone | Status | Notes |
| --- | --- | --- |
| M0 bootstrap | Implemented | Project scaffold, Nim build/test tasks, CI workflow, baseline metadata freeze |
| M1 inventory + codegen | {m1_status} | {m1_note} |
| M2 core runtime/CLI/config parity | {m2_status} | {m2_note} |
| M3 database compatibility | {m3_status} | {m3_note} |
| M4+ | {m4_status} | {m4_note} |

## Rust crate inventory

| Crate | Functions | Files |
| --- | ---: | ---: |
{crate_rows}

## Nim implementation by Rust crate

| Crate | Implemented | Partial | Scaffold | Missing | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
{impl_crate_rows}

## Generated artifacts

- `docs/parity/baseline.json`
- `docs/parity/rust_function_inventory.json`
- `docs/parity/route_inventory.json`
- `docs/parity/config_inventory.json`
- `docs/parity/config_default_inventory.json`
- `docs/parity/db_cf_inventory.json`
- `docs/parity/module_map.json`
- `docs/parity/module_coverage.json`
- `docs/parity/implementation_coverage.json`
- `docs/parity/route_behavior_coverage.json`
- `docs/parity/config_behavior_coverage.json`
- `docs/parity/complement_baseline.json`
- `docs/parity/runtime_diff_report.json`
- `src/api/generated_route_inventory.nim`
- `src/api/generated_route_types.nim`
- `src/api/generated_route_runtime.nim`
- `src/core/generated_config_keys.nim`
- `src/core/generated_config_model.nim`
- `src/core/generated_config_defaults.nim`
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
