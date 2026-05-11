version       = "0.1.0"
author        = "Beenim"
description   = "Nim baseline-pinned port of tuwunel"
license       = "Apache-2.0"
srcDir        = "src"
bin           = @["tuwunel"]

requires "nim >= 2.2.10"

task parity_extract, "Extract parity inventory from Rust baseline":
  exec "python3 tools/extract_inventory.py"

task parity_codegen, "Generate Nim stubs and parity matrix from inventory":
  exec "python3 tools/generate_stubs.py"
  exec "python3 tools/render_parity_matrix.py"

task parity_scaffold, "Generate missing module scaffold from module_map.json":
  exec "python3 tools/generate_module_scaffold.py"

task parity_sync, "Refresh inventory + generated artifacts":
  exec "python3 tools/extract_inventory.py"
  exec "python3 tools/generate_stubs.py"
  exec "python3 tools/render_parity_matrix.py"

task syntax_hygiene, "Fail on Rust syntax leakage in Nim files":
  exec "python3 tools/check_nim_syntax_hygiene.py"

task parity_diff, "Run Rust-vs-Nim behavioral diff harness":
  exec "nim c -d:ssl -o:build/tuwunel src/tuwunel.nim"
  exec "python3 tools/parity_diff.py --rust-bin ../tuwunel/target/release/tuwunel --nim-bin build/tuwunel --scenarios tests/parity/scenarios.json --out docs/parity/runtime_diff_report.json"

task build, "Build tuwunel binary":
  exec "nim c -d:ssl -o:build/tuwunel src/tuwunel.nim"

task test, "Run test suite":
  exec "nim c -r -d:ssl --out:build/tuwunel_nim_tests tests/all_tests.nim"

task test_rocksdb, "Run tests with RocksDB backend enabled":
  exec "bash tools/run_rocksdb_tests.sh"
