const
  RustPath* = "service/users/dehydrated_device.rs"
  RustCrate* = "service"

import std/[json, tables]

import service/users/device

proc putDehydratedDevice*(
  service: var UserService;
  userId, deviceId: string;
  deviceData: JsonNode;
) =
  service.dehydratedDevices[userId] = DehydratedDeviceRecord(
    userId: userId,
    deviceId: deviceId,
    deviceData: if deviceData.isNil: newJObject() else: deviceData.copy(),
  )

proc getDehydratedDevice*(service: UserService; userId: string): tuple[ok: bool, device: DehydratedDeviceRecord] =
  if userId notin service.dehydratedDevices:
    return (false, DehydratedDeviceRecord())
  (true, service.dehydratedDevices[userId])

proc removeDehydratedDevice*(
  service: var UserService;
  userId: string;
  deviceId = "";
): UserResult =
  if userId notin service.dehydratedDevices:
    return userError("M_NOT_FOUND", "No dehydrated device is stored.")
  if deviceId.len > 0 and service.dehydratedDevices[userId].deviceId != deviceId:
    return okResult()
  service.dehydratedDevices.del(userId)
  okResult()
