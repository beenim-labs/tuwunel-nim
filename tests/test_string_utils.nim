import std/[options, unittest]

import core/utils/string as string_utils

suite "core string utility parity":
  test "camel_to_snake_string matches Rust transitions":
    check string_utils.camelToSnakeString("CamelToSnakeCase") == "camel_to_snake_case"
    check string_utils.camelToSnakeString("CAmelTOSnakeCase") == "camel_tosnake_case"
    check string_utils.camelToSnakeString("already_snake") == "already_snake"

  test "common_prefix matches Rust empty and populated cases":
    check string_utils.commonPrefix(["conduwuit", "conduit", "construct"]) == "con"
    check string_utils.commonPrefix(["abcdefg", "hijklmn", "opqrstu"]) == ""
    check string_utils.commonPrefix([]) == ""

  test "quote, between, and split helpers keep infallible fallbacks":
    check string_utils.unquote("\"foo\"").get("") == "foo"
    check string_utils.unquote("\"foo").isNone
    check string_utils.unquote("foo").isNone
    check string_utils.unquoteInfallible("\"foo\"") == "foo"
    check string_utils.unquoteInfallible("\"foo") == "foo"
    check string_utils.unquoteInfallible("foo") == "foo"

    check string_utils.between("\"foo\"", "\"", "\"").get("") == "foo"
    check string_utils.between("\"foo", "\"", "\"").isNone
    check string_utils.betweenInfallible("\"foo", "\"", "\"") == "\"foo"

    check string_utils.splitOnceInfallible("left:right", ":") == ("left", "right")
    check string_utils.splitOnceInfallible("left", ":") == ("left", "")
    check string_utils.rsplitOnceInfallible("a:b:c", ":") == ("a:b", "c")

  test "deterministic truncation and utf8 byte parsing":
    check string_utils.truncateDeterministic("abcdef", 1, 4) == "abc"
    check string_utils.truncateDeterministic("abc", 0, 0) == ""

    let ok = string_utils.stringFromBytes([byte(ord('h')), byte(ord('i'))])
    check ok.ok
    check ok.value == "hi"
    let bad = string_utils.stringFromBytes([byte(0xff)])
    check not bad.ok
