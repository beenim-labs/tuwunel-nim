## Buffered write cork for grouped map updates.

import db

type
  CorkOpKind* = enum
    cokPut
    cokDel

  CorkOp* = object
    kind*: CorkOpKind
    columnFamily*: string
    key*: seq[byte]
    value*: seq[byte]

  Cork* = ref object
    database*: DatabaseHandle
    ops*: seq[CorkOp]

proc newCork*(database: DatabaseHandle): Cork =
  if database.isNil:
    raise newException(ValueError, "Database handle is nil")
  new(result)
  result.database = database
  result.ops = @[]

proc put*(cork: Cork; columnFamily: string; key, value: openArray[byte]) =
  cork.ops.add(CorkOp(kind: cokPut, columnFamily: columnFamily, key: @key, value: @value))

proc del*(cork: Cork; columnFamily: string; key: openArray[byte]) =
  cork.ops.add(CorkOp(kind: cokDel, columnFamily: columnFamily, key: @key, value: @[]))

proc apply*(cork: Cork): int =
  result = 0
  for op in cork.ops:
    case op.kind
    of cokPut:
      cork.database.put(op.columnFamily, op.key, op.value)
      inc result
    of cokDel:
      if cork.database.del(op.columnFamily, op.key):
        inc result

proc clear*(cork: Cork) =
  cork.ops.setLen(0)
