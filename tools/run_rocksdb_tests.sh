#!/usr/bin/env bash
set -euo pipefail

ROCKS_PATH="$(cd /tmp && nimble path rocksdb)"
RESULTS_PATH="$(cd /tmp && nimble path results)"

nim c -r -d:ssl -d:tuwunel_use_rocksdb \
  --path:"${ROCKS_PATH}" \
  --path:"${RESULTS_PATH}" \
  --out:build/tuwunel_nim_tests_rocks \
  tests/all_tests.nim
