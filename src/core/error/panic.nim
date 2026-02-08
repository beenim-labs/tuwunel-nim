## Panic handling for errors.
##
## Ported from Rust core/error/panic.rs — provides panic capture and
## inspection. In Nim, panics map to Defects/exceptions.

import mod as errormod

const
  RustPath* = "core/error/panic.rs"
  RustCrate* = "core"

proc fromPanic*(message: string): Error =
  ## Create an Error from a panic message.
  result = Error(
    variant: evPanic,
    errKind: ekUnknown,
    detail: "PANIC! " & message,
    httpStatus: 500,
  )
  result.msg = result.detail

proc raiseAsPanic*(e: Error) {.noreturn.} =
  ## Re-raise an error as a Defect (Nim's equivalent of a panic).
  raise newException(Defect, e.message())

proc panicStr*(e: Error): string =
  ## Get the panic message string, if this error wraps a panic.
  if e.isPanic():
    e.detail
  else:
    ""
