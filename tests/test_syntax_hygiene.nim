import std/[osproc, unittest]

suite "Syntax hygiene":
  test "Rust syntax leakage scanner passes for src":
    let cmd = "python3 tools/check_nim_syntax_hygiene.py"
    let output = execCmdEx(cmd)
    check output.exitCode == 0
