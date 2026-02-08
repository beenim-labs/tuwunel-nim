## Boolean extension utilities — chain methods for bool values.
##
## Ported from Rust core/utils/bool.rs — translates the BoolExt trait
## into Nim procs and templates.

import std/options

const
  RustPath* = "core/utils/bool.rs"
  RustCrate* = "core"

proc isFalse*(b: bool): bool {.inline.} =
  ## Return true if value is false.
  not b

proc intoOption*(b: bool): Option[bool] =
  ## Convert bool to Option: true → some(true), false → none.
  if b:
    result = some(b)
  else:
    result = none(bool)

template boolOkOr*(b: bool; errMsg: string) =
  ## Assert bool is true, raise if not.
  if not b:
    raise newException(CatchableError, errMsg)

proc mapOr*[T](b: bool; errVal: T; f: proc(): T): T {.inline.} =
  ## If true, call f(); otherwise return errVal.
  if b: f() else: errVal

proc mapOrElse*[T](b: bool; errFn: proc(): T; okFn: proc(): T): T {.inline.} =
  ## If true, call okFn(); otherwise call errFn().
  if b: okFn() else: errFn()

proc copyOr*[T](b: bool; errVal: T; okVal: T): T {.inline.} =
  ## If true, return okVal; otherwise return errVal.
  if b: okVal else: errVal

proc andOption*[T](b: bool; t: Option[T]): Option[T] {.inline.} =
  ## If true, return t; otherwise return none.
  if b: t else: none(T)

proc andThen*[T](b: bool; f: proc(): Option[T]): Option[T] {.inline.} =
  ## If true, call f(); otherwise return none.
  if b: f() else: none(T)

proc orSome*[T](b: bool; t: T): Option[T] {.inline.} =
  ## If false, return some(t); if true, return none.
  if b: none(T) else: some(t)

proc thenOkOr*[T, E](b: bool; okVal: T; errVal: E): tuple[ok: bool, val: T, err: E] {.inline.} =
  ## If true, return (true, okVal, _); otherwise return (false, _, errVal).
  if b: (true, okVal, errVal) else: (false, okVal, errVal)

template expectTrue*(b: bool; msg: string) =
  ## Assert that b is true, panic with msg otherwise.
  if not b:
    raise newException(AssertionDefect, msg)

template expectFalse*(b: bool; msg: string) =
  ## Assert that b is false, panic with msg otherwise.
  if b:
    raise newException(AssertionDefect, msg)
