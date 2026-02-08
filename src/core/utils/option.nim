## Option extension utilities.
##
## Ported from Rust core/utils/option.rs — simplified for Nim (no async).
## Rust's OptionExt trait provides async mapping; Nim uses simpler procs.

import std/options

const
  RustPath* = "core/utils/option.rs"
  RustCrate* = "core"

proc mapOption*[T, U](opt: Option[T]; f: proc(v: T): U): Option[U] =
  ## Map an Option value through a function.
  if opt.isSome:
    some(f(opt.get()))
  else:
    none(U)

proc flatMap*[T, U](opt: Option[T]; f: proc(v: T): Option[U]): Option[U] =
  ## FlatMap an Option through a function returning Option.
  if opt.isSome:
    f(opt.get())
  else:
    none(U)

proc getOrElse*[T](opt: Option[T]; f: proc(): T): T =
  ## Get the value or compute a default.
  if opt.isSome:
    opt.get()
  else:
    f()

proc orElse*[T](opt: Option[T]; f: proc(): Option[T]): Option[T] =
  ## If None, call f() to try to get a value.
  if opt.isSome:
    opt
  else:
    f()

proc filter*[T](opt: Option[T]; pred: proc(v: T): bool): Option[T] =
  ## Keep the value only if it satisfies the predicate.
  if opt.isSome and pred(opt.get()):
    opt
  else:
    none(T)

proc zip*[T, U](a: Option[T]; b: Option[U]): Option[(T, U)] =
  ## Combine two Options into a tuple Option.
  if a.isSome and b.isSome:
    some((a.get(), b.get()))
  else:
    none((T, U))
