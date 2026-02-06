import std/[times, strformat]

type
  LogLevel* = enum
    llDebug
    llInfo
    llWarn
    llError

proc levelName(level: LogLevel): string =
  case level
  of llDebug: "DEBUG"
  of llInfo: "INFO"
  of llWarn: "WARN"
  of llError: "ERROR"

proc log*(level: LogLevel; msg: string) =
  let ts = now().utc.format("yyyy-MM-dd'T'HH:mm:ss'Z'")
  stderr.writeLine(fmt"{ts} {levelName(level)} {msg}")

proc debug*(msg: string) = log(llDebug, msg)
proc info*(msg: string) = log(llInfo, msg)
proc warn*(msg: string) = log(llWarn, msg)
proc error*(msg: string) = log(llError, msg)

proc die*(msg: string; code = 1): int =
  error(msg)
  result = code
