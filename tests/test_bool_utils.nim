import std/[options, unittest]

import core/utils/bool as bool_utils

suite "bool utility parity":
  test "boolean chaining preserves option semantics":
    check true.andOption(some(7)).get(0) == 7
    check false.andOption(some(7)).isNone
    check true.andThen(proc(): Option[string] = some("ok")).get("") == "ok"
    check false.andThen(proc(): Option[string] = some("bad")).isNone

    check false.orSome("fallback").get("") == "fallback"
    check true.orSome("fallback").isNone
    check false.orOption(proc(): int = 9).get(0) == 9

  test "boolean result helpers expose ok and error branches":
    check true.intoResult().ok
    check not false.intoResult().ok
    check true.okOr("err").ok
    check false.okOr("err").message == "err"
    check false.okOrElse(proc(): string = "late").message == "late"

  test "map and then result helpers only call selected branches":
    check false.mapOr(3, proc(): int = 9) == 3
    check true.mapOr(3, proc(): int = 9) == 9
    check false.mapOrElse(proc(): int = 4, proc(): int = 9) == 4
    check true.mapBool(proc(value: bool): string =
      if value: "yes" else: "no"
    ) == "yes"

    let ok = true.thenOkOr("value", "err")
    check ok.ok
    check ok.value == "value"
    let err = false.thenOkOrElse("value", proc(): string = "late")
    check not err.ok
    check err.message == "late"

  test "expect helpers match Rust panic contracts":
    check true.expect("must be true")
    check not false.expectFalse("must be false")
    expect AssertionDefect:
      discard false.expect("must be true")
    expect AssertionDefect:
      discard true.expectFalse("must be false")
