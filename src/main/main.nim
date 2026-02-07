import entrypoint

const
  RustPath* = "main/main.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

proc runMain*(): int =
  main()

proc runMainWithExitCode*(defaultCode = 0): int =
  let code = runMain()
  if code == 0:
    return defaultCode
  code

proc mainSucceeded*(): bool =
  runMain() == 0

proc mainFailed*(): bool =
  not mainSucceeded()

proc runMainSummary*(): string =
  let code = runMain()
  "tuwunel_main_exit_code=" & $code

proc mainSummaryWithStatus*(): string =
  let code = runMain()
  let status = if code == 0: "ok" else: "error"
  "status=" & status & " code=" & $code

when isMainModule:
  quit(runMain())
