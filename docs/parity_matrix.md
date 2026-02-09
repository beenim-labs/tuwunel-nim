# Parity Matrix (Baseline-Pinned)

Generated from `tools/*` against Rust baseline commit `90d4bda70bf0396c38292a175f7debc2d8069109`.

## Baseline summary

| Item | Count |
| --- | ---: |
| Rust functions | 2820 |
| Client routes (`.ruma_route`) | 149 |
| Server routes (`.ruma_route`) | 29 |
| Manual routes (`.route`) | 29 |
| Config fields (public) | 308 |
| DB column families | 103 |
| Complement pass | 494 |
| Complement fail | 267 |
| Complement skip | 16 |

## Module coverage

| Item | Count |
| --- | ---: |
| Mapped modules | 548 |
| Present modules | 548 |
| Missing modules | 0 |

## Behavioral implementation coverage

| Item | Count |
| --- | ---: |
| Implemented modules | 5 |
| Partial modules | 17 |
| Scaffold modules | 526 |
| Missing modules | 0 |
| Implemented ratio | 0.9% |

## Route behavior coverage

| Item | Count |
| --- | ---: |
| Total routes | 207 |
| Registered routes | 207 |
| Auth-covered routes | 207 |
| Handler-covered routes | 207 |
| Error-shape-covered routes | 207 |

## Config behavior coverage

| Item | Count |
| --- | ---: |
| Total config keys | 308 |
| Typed keys | 308 |
| Keys with defaults (applied/expected) | 302/302 |
| Keys with defaults (raw applied) | 302 |
| Env alias compatible keys | 308 |
| Option override compatible keys | 308 |

## Milestone status

| Milestone | Status | Notes |
| --- | --- | --- |
| M0 bootstrap | Implemented | Project scaffold, Nim build/test tasks, CI workflow, baseline metadata freeze |
| M1 inventory + codegen | Implemented | Module map scaffold complete; generated artifacts and inventories synced |
| M2 core runtime/CLI/config parity | Implemented | All config keys are typed/defaulted and override-compatible |
| M3 database compatibility | In progress | Database crate modules implemented=3/57 |
| M4+ | Pending | Service graph, routes, Matrix semantics, federation, admin, perf |

## Rust crate inventory

| Crate | Functions | Files |
| --- | ---: | ---: |
| `admin` | 58 | 45 |
| `api` | 123 | 115 |
| `core` | 1197 | 161 |
| `database` | 337 | 57 |
| `macros` | 24 | 9 |
| `main` | 48 | 14 |
| `router` | 19 | 9 |
| `service` | 1014 | 138 |

## Nim implementation by Rust crate

| Crate | Implemented | Partial | Scaffold | Missing | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| `admin` | 0 | 1 | 44 | 0 | 45 |
| `api` | 0 | 1 | 114 | 0 | 115 |
| `core` | 0 | 1 | 160 | 0 | 161 |
| `database` | 3 | 12 | 42 | 0 | 57 |
| `macros` | 0 | 1 | 8 | 0 | 9 |
| `main` | 1 | 0 | 13 | 0 | 14 |
| `router` | 1 | 0 | 8 | 0 | 9 |
| `service` | 0 | 1 | 137 | 0 | 138 |

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
