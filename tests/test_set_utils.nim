import std/unittest

import core/utils/set as set_utils

suite "set utility parity":
  test "intersection keeps first input order and unsorted duplicate behavior":
    check set_utils.intersection(@[
      @[3, 2, 2, 1],
      @[2, 3],
      @[2, 3, 4],
    ]) == @[3, 2, 2]

    check set_utils.intersection(newSeq[seq[int]]()) == newSeq[int]()

  test "sorted intersection consumes matching values like Rust iterators":
    check set_utils.intersectionSorted(@[
      @[1, 2, 2, 3, 5],
      @[2, 2, 4, 5],
      @[2, 5],
    ]) == @[2, 5]

    check set_utils.intersectionSorted2(
      @["a", "b", "b", "c"],
      @["b", "c"],
    ) == @["b", "c"]

  test "sorted difference consumes equal values one-for-one":
    check set_utils.differenceSorted2(
      @[1, 1, 2, 3, 3, 5],
      @[1, 3, 4],
    ) == @[1, 2, 3, 5]

    check set_utils.differenceSortedStream2(
      @["a", "b", "b", "d"],
      @["b", "c"],
    ) == @["a", "b", "d"]
