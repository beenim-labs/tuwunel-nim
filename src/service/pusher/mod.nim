const
  RustPath* = "service/pusher/mod.rs"
  RustCrate* = "service"

import std/[algorithm, strutils, tables]

import service/pusher/request
import service/pusher/suppressed

export request, suppressed

type
  Notified* = object
    ts*: uint64
    shortRoomId*: string
    tag*: string
    actions*: seq[string]

  PusherSetResult* = tuple[ok: bool, errcode: string, message: string]
  PusherFetchResult* = tuple[ok: bool, pusher: Pusher]

  PusherService* = object
    pushers*: Table[string, Pusher]
    pushkeyDevice*: Table[string, string]
    notifications*: Table[string, seq[tuple[count: uint64, notified: Notified]]]
    notificationCounts*: Table[string, uint64]
    highlightCounts*: Table[string, uint64]
    lastNotificationRead*: Table[string, uint64]
    nextCount*: uint64
    suppressed*: SuppressedQueue

proc initPusherService*(): PusherService =
  PusherService(
    pushers: initTable[string, Pusher](),
    pushkeyDevice: initTable[string, string](),
    notifications: initTable[string, seq[tuple[count: uint64, notified: Notified]]](),
    notificationCounts: initTable[string, uint64](),
    highlightCounts: initTable[string, uint64](),
    lastNotificationRead: initTable[string, uint64](),
    nextCount: 0'u64,
    suppressed: initSuppressedQueue(),
  )

proc senderKey*(sender, pushkey: string): string =
  sender & "\0" & pushkey

proc roomCountKey*(userId, roomId: string; threadRoot = ""): string =
  if threadRoot.len == 0:
    userId & "\0" & roomId
  else:
    userId & "\0" & roomId & "\0" & threadRoot

proc roomReadKey*(roomId, userId: string; threadRoot = ""): string =
  if threadRoot.len == 0:
    roomId & "\0" & userId
  else:
    roomId & "\0" & userId & "\0" & threadRoot

proc nextCountValue*(service: var PusherService): uint64 =
  inc service.nextCount
  service.nextCount

proc setPusher*(
  service: var PusherService;
  sender, senderDevice: string;
  pusher: Pusher;
): PusherSetResult =
  let policy = validatePusher(pusher)
  if not policy.ok:
    return (false, policy.errcode, policy.message)
  service.pushers[senderKey(sender, pusher.pushkey)] = pusher
  service.pushkeyDevice[pusher.pushkey] = senderDevice
  (true, "", "")

proc deletePusher*(service: var PusherService; sender, pushkey: string) =
  service.pushers.del(senderKey(sender, pushkey))
  service.pushkeyDevice.del(pushkey)
  discard service.suppressed.clearSuppressedPushkey(sender, pushkey)

proc getPusher*(service: PusherService; sender, pushkey: string): PusherFetchResult =
  let key = senderKey(sender, pushkey)
  if key notin service.pushers:
    return (false, Pusher())
  (true, service.pushers[key])

proc getPusherDevice*(service: PusherService; pushkey: string): tuple[ok: bool, deviceId: string] =
  if pushkey notin service.pushkeyDevice:
    return (false, "")
  (true, service.pushkeyDevice[pushkey])

proc getPushkeys*(service: PusherService; sender: string): seq[string] =
  result = @[]
  let prefix = sender & "\0"
  for key, pusher in service.pushers:
    if key.startsWith(prefix):
      result.add(pusher.pushkey)
  result.sort(system.cmp[string])

proc getPushers*(service: PusherService; sender: string): seq[Pusher] =
  result = @[]
  let prefix = sender & "\0"
  for key, pusher in service.pushers:
    if key.startsWith(prefix):
      result.add(pusher)
  result.sort(proc(a, b: Pusher): int = cmp(a.pushkey, b.pushkey))

proc getDevicePushkeys*(service: PusherService; sender, deviceId: string): seq[string] =
  result = @[]
  for pushkey in service.getPushkeys(sender):
    let device = service.getPusherDevice(pushkey)
    if device.ok and device.deviceId == deviceId:
      result.add(pushkey)
