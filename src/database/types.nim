## Database compatibility types and shared constants.

const
  Sep* = byte(0xFF)
  KeyStackCap* = 112
  ValStackCap* = 496
  DefStackCap* = KeyStackCap

type
  DbError* = object of CatchableError
  DbEntry* = tuple[key: seq[byte], value: seq[byte]]

proc newDbError*(msg: string): ref DbError =
  newException(DbError, msg)
