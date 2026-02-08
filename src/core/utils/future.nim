## Future utilities — async extensions for Nim.
##
## Ported from Rust core/utils/future/*.rs — consolidates 8 Rust files
## (bool_ext, ext_ext, option_ext, option_stream, ready_bool_ext,
## ready_eq_ext, try_ext_ext, mod) into Nim async patterns.
##
## Rust's Future/TryFuture extensions mostly don't apply in Nim since
## Nim uses a different async model. This module provides the relevant
## patterns that do translate.

import std/[asyncdispatch, options]

const
  RustPath* = "core/utils/future/*.rs"
  RustCrate* = "core"

# --- Bool extensions for async ---

proc andThenAsync*[T](b: bool; f: proc(): Future[T]): Future[Option[T]] {.async.} =
  ## If true, call async f() and return some(result); else return none.
  if b:
    let val = await f()
    return some(val)
  else:
    return none(T)

proc orElseAsync*[T](b: bool; f: proc(): Future[T]): Future[Option[T]] {.async.} =
  ## If false, call async f() and return some(result); else return none.
  if not b:
    let val = await f()
    return some(val)
  else:
    return none(T)

# --- Option extensions for async ---

proc mapAsync*[T, U](opt: Option[T]; f: proc(v: T): Future[U]): Future[Option[U]] {.async.} =
  ## Map an Option value through an async function.
  if opt.isSome:
    let val = await f(opt.get())
    return some(val)
  else:
    return none(U)

# --- TryFuture extensions ---

proc andThenTry*[T, U](
  fut: Future[T];
  f: proc(v: T): Future[U]
): Future[U] {.async.} =
  ## Chain two async operations.
  let val = await fut
  return await f(val)

proc mapTry*[T, U](fut: Future[T]; f: proc(v: T): U): Future[U] {.async.} =
  ## Map the result of a future through a function.
  return f(await fut)
