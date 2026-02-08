## Server runtime state — lifecycle management, signals, shutdown coordination.
##
## Ported from Rust core/server.rs

import std/[times, atomics, logging]

const
  RustPath* = "core/server.rs"
  RustCrate* = "core"

type
  SignalCallback* = proc(sig: string) {.gcsafe.}

  Server* = ref object
    ## Server runtime state; public portion.
    name*: string              ## Configured server name
    started*: DateTime         ## Timestamp server was started
    stopping*: Atomic[bool]    ## Server is shutting down
    reloading*: Atomic[bool]   ## Reload in progress
    restarting*: Atomic[bool]  ## Restart desired after shutdown
    signalCallbacks: seq[SignalCallback]

proc newServer*(name: string): Server =
  result = Server(
    name: name,
    started: now(),
  )
  result.stopping.store(false)
  result.reloading.store(false)
  result.restarting.store(false)

proc signal*(s: Server; sig: string) =
  ## Send a signal to all registered callbacks.
  for cb in s.signalCallbacks:
    cb(sig)

proc onSignal*(s: Server; cb: SignalCallback) =
  ## Register a signal callback.
  s.signalCallbacks.add cb

proc running*(s: Server): bool =
  ## True if server is not stopping.
  not s.stopping.load()

proc isStopping*(s: Server): bool = s.stopping.load()
proc isReloading*(s: Server): bool = s.reloading.load()
proc isRestarting*(s: Server): bool = s.restarting.load()

proc isOurs*(s: Server; name: string): bool =
  ## Check if a server name matches ours.
  name == s.name

proc shutdown*(s: Server) =
  ## Initiate server shutdown.
  if s.stopping.exchange(true):
    warn "Shutdown already in progress"
    return
  s.signal("SIGTERM")

proc reload*(s: Server) =
  ## Initiate server reload.
  if s.reloading.exchange(true):
    warn "Reload already in progress"
    return
  if s.stopping.exchange(true):
    s.reloading.store(false)
    warn "Shutdown already in progress"
    return
  s.signal("SIGINT")

proc restart*(s: Server) =
  ## Initiate server restart.
  if s.restarting.exchange(true):
    warn "Restart already in progress"
    return
  s.shutdown()

proc checkRunning*(s: Server) =
  ## Raise if server is not running.
  if not s.running():
    raise newException(IOError, "Server shutting down")

proc uptime*(s: Server): Duration =
  ## Return server uptime.
  now() - s.started
