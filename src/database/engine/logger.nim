## Engine event logger primitives.

import std/times

type
  EngineLogLevel* = enum
    ellDebug
    ellInfo
    ellWarn
    ellError

  EngineLogEvent* = object
    level*: EngineLogLevel
    message*: string
    unixTime*: int64

  EngineLogger* = ref object
    events*: seq[EngineLogEvent]

proc newEngineLogger*(): EngineLogger =
  new(result)
  result.events = @[]

proc log*(logger: EngineLogger; level: EngineLogLevel; message: string) =
  if logger.isNil:
    return
  let ts = now().toTime().toUnix().int64
  logger.events.add(EngineLogEvent(level: level, message: message, unixTime: ts))

proc debug*(logger: EngineLogger; message: string) =
  logger.log(ellDebug, message)

proc info*(logger: EngineLogger; message: string) =
  logger.log(ellInfo, message)

proc warn*(logger: EngineLogger; message: string) =
  logger.log(ellWarn, message)

proc error*(logger: EngineLogger; message: string) =
  logger.log(ellError, message)

proc eventCount*(logger: EngineLogger): int =
  if logger.isNil: 0 else: logger.events.len
