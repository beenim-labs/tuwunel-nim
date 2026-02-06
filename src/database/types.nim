## Database compatibility types and shared constants.

const
  Sep* = byte(0xFF)
  KeyStackCap* = 112
  ValStackCap* = 496
  DefStackCap* = KeyStackCap

type
  DbError* = object of CatchableError

proc newDbError*(msg: string): ref DbError =
  newException(DbError, msg)
