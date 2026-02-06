## Database pool runtime primitives.

import pool/configure
import db

type
  DbPool* = ref object
    config*: DbPoolConfig
    primary*: DatabaseHandle
    borrowed*: int

proc newDbPool*(primary: DatabaseHandle; config = defaultDbPoolConfig()): DbPool =
  if primary.isNil:
    raise newException(ValueError, "Primary database handle is nil")

  new(result)
  result.config = config.normalize()
  result.primary = primary
  result.borrowed = 0

proc borrow*(pool: DbPool): DatabaseHandle =
  if pool.isNil:
    raise newException(ValueError, "DbPool is nil")
  if pool.borrowed >= pool.config.maxWorkers:
    raise newException(ValueError, "DbPool worker limit reached")

  inc pool.borrowed
  pool.primary

proc release*(pool: DbPool) =
  if pool.isNil:
    return
  if pool.borrowed > 0:
    dec pool.borrowed

proc queueCapacity*(pool: DbPool): int =
  if pool.isNil:
    return 0
  pool.config.queueCapacity()

proc isSaturated*(pool: DbPool): bool =
  if pool.isNil:
    return false
  pool.borrowed >= pool.config.maxWorkers
