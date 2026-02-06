# M2/M3 Decisions (Baseline-Pinned)

## M2 config + CLI compatibility

- Config source precedence is:
  1. `CONDUIT_CONFIG`, `CONDUWUIT_CONFIG`, `TUWUNEL_CONFIG` (in that order)
  2. CLI `-c/--config` paths (in provided order)
  3. env overrides `CONDUIT_`, `CONDUWUIT_`, `TUWUNEL_` with `__` mapped to `.`
  4. CLI `-O/--option` overrides.
- `-O/--option` follows Rust-style validation:
  - missing `=` is rejected,
  - empty key is rejected,
  - empty value is rejected.
- Argument transforms follow Rust `args::update` compatibility:
  - `--read-only` sets `rocksdb_read_only=true`,
  - `--read-only` or `--maintenance` set `startup_netburst=false` and `listening=false`,
  - `--execute` appends to `admin_execute`,
  - `--test` appends to `test`.

## M3 DB schema + serialization compatibility

- Serializer framing keeps `0xFF` as tuple record separator.
- BE integer encoding/decoding is implemented for `u64`, `i64`, `u32`.
- Top-level string serialization is rejected by parity serializer helpers.
- Deserializer includes tuple default/optional behavior for parity tests.
- RocksDB open policy is descriptor-driven:
  - required CFs are all descriptors where `dropped=false` and `ignored=false`,
  - unknown on-disk CFs are tolerated and opened as ignored-compatible families,
  - missing required CFs in an existing DB are rejected.
- RocksDB open options are explicit (`read_only`, `secondary`, `repair`, `never_drop_columns`).
  - `secondary` is currently surfaced but unsupported by the current Nim binding path.
