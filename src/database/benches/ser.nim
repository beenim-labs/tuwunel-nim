## Serialization benchmark helpers for parity tuning.

import std/times
import ../ser

proc benchSerializeU64*(iterations: int): int64 =
  let start = getMonoTime()
  var sink = 0'u64
  var i = 0
  while i < iterations:
    let payload = serializeU64(i.uint64)
    sink = sink xor uint64(payload.len)
    inc i
  discard sink
  (getMonoTime() - start).inNanoseconds

proc benchSerializeTuple*(iterations: int): int64 =
  let start = getMonoTime()
  var sink = 0
  var i = 0
  while i < iterations:
    let a = serializeU64(i.uint64)
    let b = serializeU32(i.uint32)
    let c = serializeI64(i.int64)
    let payload = serializeTuple3(a, b, c)
    sink = sink xor payload.len
    inc i
  discard sink
  (getMonoTime() - start).inNanoseconds

proc benchmarkReport*(iterations: int): tuple[u64Ns: int64, tupleNs: int64] =
  (
    u64Ns: benchSerializeU64(iterations),
    tupleNs: benchSerializeTuple(iterations),
  )
