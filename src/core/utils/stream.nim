## Stream utilities — iterator extensions for Nim.
##
## Ported from Rust core/utils/stream/*.rs — consolidates 15 Rust files
## (band, broadband, cloned, expect, ignore, iter_stream, ready,
## tools, try_broadband, try_parallel, try_ready, try_tools,
## try_wideband, wideband, mod) into Nim iterator patterns.
##
## Rust's async Stream ecosystem translates to Nim's iterators + async.

import std/[sequtils, algorithm]

const
  RustPath* = "core/utils/stream/*.rs"
  RustCrate* = "core"

# --- IterStream: convert iterators to streams ---

iterator toStream*[T](s: seq[T]): T =
  ## Convert a sequence to an iterator (trivial in Nim).
  for item in s:
    yield item

# --- Ready extensions: process items immediately ---

proc collectReady*[T](s: openArray[T]): seq[T] =
  ## Collect all items into a sequence (Nim equivalent of ready stream).
  @s

proc filterReady*[T](s: openArray[T]; pred: proc(item: T): bool): seq[T] =
  ## Filter items with a predicate.
  s.filterIt(pred(it))

proc mapReady*[T, U](s: openArray[T]; f: proc(item: T): U): seq[U] =
  ## Map items through a function.
  s.mapIt(f(it))

# --- Tools: stream processing utilities ---

proc chunks*[T](s: openArray[T]; size: int): seq[seq[T]] =
  ## Split a sequence into chunks of the given size.
  result = @[]
  var i = 0
  while i < s.len:
    let endIdx = min(i + size, s.len)
    result.add s[i ..< endIdx].toSeq
    i += size

proc enumerate*[T](s: openArray[T]): seq[(int, T)] =
  ## Pair each item with its index.
  result = newSeq[(int, T)](s.len)
  for i, item in s:
    result[i] = (i, item)

proc take*[T](s: openArray[T]; n: int): seq[T] =
  ## Take the first n items.
  let count = min(n, s.len)
  s[0 ..< count].toSeq

proc skip*[T](s: openArray[T]; n: int): seq[T] =
  ## Skip the first n items.
  if n >= s.len:
    @[]
  else:
    s[n ..< s.len].toSeq

proc any*[T](s: openArray[T]; pred: proc(item: T): bool): bool =
  ## Check if any item satisfies the predicate.
  for item in s:
    if pred(item):
      return true
  false

proc all*[T](s: openArray[T]; pred: proc(item: T): bool): bool =
  ## Check if all items satisfy the predicate.
  for item in s:
    if not pred(item):
      return false
  true

proc fold*[T, U](s: openArray[T]; init: U; f: proc(acc: U; item: T): U): U =
  ## Fold/reduce a sequence.
  result = init
  for item in s:
    result = f(result, item)

proc findFirst*[T](s: openArray[T]; pred: proc(item: T): bool): int =
  ## Find the index of the first item satisfying the predicate, or -1.
  for i, item in s:
    if pred(item):
      return i
  -1

# --- Broadband/Wideband: parallel processing (simplified) ---
# In Nim, these translate to sequential processing or
# can be enhanced with Nim's parallel pragma.

proc broadbandMap*[T, U](s: openArray[T]; f: proc(item: T): U): seq[U] =
  ## Map items (Nim equivalent — sequential; could use parallel pragma).
  result = newSeq[U](s.len)
  for i, item in s:
    result[i] = f(item)

proc widebandMap*[T, U](s: openArray[T]; f: proc(item: T): U): seq[U] =
  ## Map items (wideband = higher parallelism; same as broadband in Nim).
  broadbandMap(s, f)
