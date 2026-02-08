## Result extension utilities — logging, inspection, mapping.
##
## Ported from Rust core/utils/result/*.rs — consolidates 14 Rust files
## (and_then_ref, debug_inspect, filter, flat_ok, inspect_log,
## into_is_ok, is_err_or, log_debug_err, log_err, map_expect,
## map_ref, not_found, unwrap_infallible, unwrap_or_err) into a single
## Nim module since Nim's exception handling replaces many of these patterns.

import std/[options, logging]

const
  RustPath* = "core/utils/result/*.rs"
  RustCrate* = "core"

# --- Result-like type for Nim ---
# Nim uses exceptions natively, but these utilities provide functional
# patterns similar to Rust's Result extensions.

type
  ResultKind* = enum rkOk, rkErr
  Result*[T, E] = object
    case kind*: ResultKind
    of rkOk: val*: T
    of rkErr: err*: E

proc ok*[T, E](v: T): Result[T, E] =
  Result[T, E](kind: rkOk, val: v)

proc err*[T, E](e: E): Result[T, E] =
  Result[T, E](kind: rkErr, err: e)

proc isOk*[T, E](r: Result[T, E]): bool = r.kind == rkOk
proc isErr*[T, E](r: Result[T, E]): bool = r.kind == rkErr

proc unwrap*[T, E](r: Result[T, E]): T =
  if r.kind == rkErr:
    raise newException(CatchableError, "unwrap on Err")
  r.val

proc unwrapOr*[T, E](r: Result[T, E]; default: T): T =
  if r.kind == rkOk: r.val else: default

proc unwrapOrElse*[T, E](r: Result[T, E]; f: proc(e: E): T): T =
  if r.kind == rkOk: r.val else: f(r.err)

proc unwrapErr*[T, E](r: Result[T, E]): E =
  if r.kind == rkOk:
    raise newException(CatchableError, "unwrap_err on Ok")
  r.err

proc mapResult*[T, E, U](r: Result[T, E]; f: proc(v: T): U): Result[U, E] =
  if r.kind == rkOk:
    ok[U, E](f(r.val))
  else:
    err[U, E](r.err)

proc mapErr*[T, E, F](r: Result[T, E]; f: proc(e: E): F): Result[T, F] =
  if r.kind == rkOk:
    ok[T, F](r.val)
  else:
    err[T, F](f(r.err))

proc andThen*[T, E, U](r: Result[T, E]; f: proc(v: T): Result[U, E]): Result[U, E] =
  if r.kind == rkOk: f(r.val) else: err[U, E](r.err)

proc orElse*[T, E, F](r: Result[T, E]; f: proc(e: E): Result[T, F]): Result[T, F] =
  if r.kind == rkOk: ok[T, F](r.val) else: f(r.err)

proc inspectResult*[T, E](r: Result[T, E]; f: proc(v: T)) =
  if r.kind == rkOk: f(r.val)

proc inspectErr*[T, E](r: Result[T, E]; f: proc(e: E)) =
  if r.kind == rkErr: f(r.err)

proc logErr*[T](r: Result[T, string]; msg: string = ""): Option[T] =
  ## Log the error if Err, return Some(val) if Ok.
  if r.kind == rkOk:
    some(r.val)
  else:
    if msg.len > 0:
      error(msg & ": " & r.err)
    else:
      error(r.err)
    none(T)

proc intoIsOk*[T, E](r: Result[T, E]): bool = r.isOk

proc flatOk*[T, E](r: Result[Option[T], E]): Option[T] =
  if r.kind == rkOk: r.val else: none(T)

proc filterResult*[T, E](r: Result[T, E]; pred: proc(v: T): bool; errVal: E): Result[T, E] =
  if r.kind == rkOk and pred(r.val):
    r
  else:
    err[T, E](errVal)

proc unwrapOrErr*[T](r: Result[T, T]): T =
  ## Unwrap either Ok or Err value (both same type).
  case r.kind
  of rkOk: r.val
  of rkErr: r.err
