## Handle helpers around DatabaseHandle lifecycle.

import db

type
  DatabaseHandleState* = enum
    dhsClosed
    dhsOpen

  ManagedDatabaseHandle* = object
    handle*: DatabaseHandle
    state*: DatabaseHandleState

proc manage*(handle: DatabaseHandle): ManagedDatabaseHandle =
  if handle.isNil:
    return ManagedDatabaseHandle(handle: nil, state: dhsClosed)
  ManagedDatabaseHandle(handle: handle, state: dhsOpen)

proc isOpen*(managed: ManagedDatabaseHandle): bool =
  managed.state == dhsOpen and not managed.handle.isNil

proc close*(managed: var ManagedDatabaseHandle) =
  if managed.handle.isNil:
    managed.state = dhsClosed
    return

  managed.handle.close()
  managed.state = dhsClosed

proc requireOpen*(managed: ManagedDatabaseHandle): DatabaseHandle =
  if not managed.isOpen():
    raise newException(ValueError, "Managed database handle is closed")
  managed.handle

proc reopenAsInMemory*(managed: var ManagedDatabaseHandle) =
  managed.close()
  managed.handle = openInMemory()
  managed.state = dhsOpen
