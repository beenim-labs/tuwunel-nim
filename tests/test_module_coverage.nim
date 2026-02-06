import std/[json, unittest]

suite "Parity module coverage":
  test "all mapped modules are present":
    let doc = parseJson(readFile("docs/parity/module_coverage.json"))
    let mapped = doc["mapped"].getInt()
    let present = doc["present"].getInt()
    let missing = doc["missing"].getInt()

    check mapped > 0
    check present == mapped
    check missing == 0

    if missing != 0:
      let paths = doc["missing_paths"]
      check paths.len == 0
      if paths.len > 0:
        checkpoint("missing module sample: " & paths[0].getStr())
