## Log span formatting.
##
## Ported from Rust core/log/fmt_span.rs

const
  RustPath* = "core/log/fmt_span.rs"
  RustCrate* = "core"

proc formatSpan*(name: string; fields: string = ""): string =
  ## Format a tracing span for log output.
  if fields.len > 0:
    name & "{" & fields & "}"
  else:
    name
