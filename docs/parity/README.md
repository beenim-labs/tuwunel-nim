# Parity Inventory Files

These files are generated from the pinned Rust baseline (`../tuwunel`) and should not
be edited manually.

## Files

- `baseline.json`: commit hash, totals, and baseline Complement counts.
- `rust_function_inventory.json`: function inventory by crate/file.
- `route_inventory.json`: extracted client/server/manual route sets.
- `config_inventory.json`: extracted public config fields from `core/config/mod.rs`.
- `db_cf_inventory.json`: extracted RocksDB column family names.
- `module_map.json`: Rust source path to planned Nim module path mapping.
- `complement_baseline.json`: parsed baseline Complement results.

## Refresh

```sh
python3 tools/extract_inventory.py
python3 tools/generate_stubs.py
python3 tools/render_parity_matrix.py
```
