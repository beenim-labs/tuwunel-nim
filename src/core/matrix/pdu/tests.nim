const
  RustPath* = "core/matrix/pdu/tests.rs"
  RustCrate* = "core"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import core/matrix/pdu/count

proc normalParseOk*(): bool =
  let parsed = parsePduCount("987654")
  parsed.ok and parsed.count.kind == pckNormal

proc backfilledParseOk*(): bool =
  let parsed = parsePduCount("-987654")
  parsed.ok and parsed.count.kind == pckBackfilled
