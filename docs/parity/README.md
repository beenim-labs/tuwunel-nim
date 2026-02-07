# Parity Inventory Files

These files are generated from the pinned Rust baseline (`../tuwunel`) and should not
be edited manually.

## Files

- `baseline.json`: commit hash, totals, and baseline Complement counts.
- `rust_function_inventory.json`: function inventory by crate/file.
- `route_inventory.json`: extracted client/server/manual route sets.
- `config_inventory.json`: extracted public config fields from `core/config/mod.rs`.
- `config_default_inventory.json`: extracted and normalized config defaults from Rust serde providers/docs.
- `db_cf_inventory.json`: extracted RocksDB column family names and descriptor metadata (`dropped`/`ignored`).
- `module_coverage.json`: scaffold module coverage against `module_map.json`.
- `implementation_coverage.json`: behavioral module status (`scaffold`/`partial`/`implemented`) and crate rollups.
- `route_behavior_coverage.json`: per-route behavioral coverage (`registered`/`auth`/`handler`/`error-shape`).
- `route_runtime_coverage.json`: dispatch/runtime coverage (`implemented` vs `501` fallback) derived from generated route runtime wiring.
- `config_behavior_coverage.json`: key-level config behavior coverage (`typed`/`default`/`env alias`/`override`).
- `module_map.json`: Rust source path to planned Nim module path mapping.
- `complement_baseline.json`: parsed baseline Complement results.

## Refresh

```sh
python3 tools/extract_inventory.py
python3 tools/generate_stubs.py
python3 tools/generate_module_scaffold.py
python3 tools/render_parity_matrix.py
```
