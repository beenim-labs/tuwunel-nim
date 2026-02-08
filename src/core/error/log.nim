## Error logging helpers.
##
## Ported from Rust core/error/log.rs — provides convenience procs for
## logging errors at various levels and returning defaults.

import std/logging
import mod as errormod

const
  RustPath* = "core/error/log.rs"
  RustCrate* = "core"

type
  LogLevel* = enum
    llError
    llWarn
    llInfo
    llDebug
    llTrace

proc inspectLog*(e: Error; level: LogLevel = llError) =
  ## Log an error at the given level.
  let msg = e.message()
  case level
  of llError: error(msg)
  of llWarn: warn(msg)
  of llInfo: info(msg)
  of llDebug: debug(msg)
  of llTrace: debug(msg) # Nim std/logging has no trace level

proc inspectDebugLog*(e: Error; level: LogLevel = llError) =
  ## Log an error's debug representation at the given level.
  inspectLog(e, level)

proc mapLog*(e: Error): Error =
  ## Log an error and return it.
  inspectLog(e)
  e

proc mapDebugLog*(e: Error): Error =
  ## Log an error at debug level and return it.
  inspectLog(e, llDebug)
  e

proc defaultLog*[T](e: Error): T =
  ## Log an error and return the default value for the type.
  inspectLog(e)
  result = default(T)

proc defaultDebugLog*[T](e: Error): T =
  ## Log an error at debug level and return the default value.
  inspectLog(e, llDebug)
  result = default(T)
