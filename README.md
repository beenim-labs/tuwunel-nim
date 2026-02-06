# tuwunel-nim

Nim rewrite foundation for `tuwunel` with baseline-pinned parity tracking.

## Current scope

This repository currently implements:

- M0 bootstrap scaffolding
- M1 parity inventory extraction and code generation
- A compileable `tuwunel` Nim entrypoint with compatibility-oriented CLI parsing shell

It does **not yet** implement full Matrix homeserver behavior. Generated inventories and parity docs are under `docs/parity/`.

## Baseline

- Rust source baseline: `../tuwunel`
- Frozen commit: `90d4bda70bf0396c38292a175f7debc2d8069109`

## Commands

```sh
cd tuwunel-nim
python3 tools/extract_inventory.py
python3 tools/generate_stubs.py
python3 tools/render_parity_matrix.py
nim c -d:ssl -o:build/tuwunel src/tuwunel.nim
nim c -r -d:ssl --out:build/tuwunel_nim_tests tests/all_tests.nim
bash tools/run_rocksdb_tests.sh
```

`nimble` tasks are also defined in `tuwunel_nim.nimble`. If this repository has
no initial Git commit yet, Nimble may refuse to run tasks until one exists.

## RocksDB-enabled tests

The RocksDB backend path is compile-flagged (`-d:tuwunel_use_rocksdb`) and
requires Nim packages `rocksdb` and `results` to be installed.

```sh
cd /tmp
nimble install -y rocksdb
cd /Users/martin/GitHub/beenim/tuwunel-nim
bash tools/run_rocksdb_tests.sh
```

## License

Apache-2.0
