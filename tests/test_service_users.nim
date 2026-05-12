import std/[json, options, strutils, tables, unittest]

import "service/users/mod" as users_service

suite "Service users parity":
  test "registration, profile fields, device metadata and tokens follow Rust service shape":
    var service = users_service.initUserService()
    check users_service.fullRegister(service, users_service.RegisterRequest(
      username: "alice",
      password: "secret",
      displayNameSuffix: "(local)",
    )).ok
    check service.exists("@alice:localhost")
    check users_service.displayName(service, "@alice:localhost").value == "alice (local)"

    users_service.setAvatarUrl(service, "@alice:localhost", some("mxc://localhost/avatar"))
    users_service.setBlurhash(service, "@alice:localhost", some("hash"))
    users_service.setTimezone(service, "@alice:localhost", some("Europe/Stockholm"))
    users_service.setProfileKey(service, "@alice:localhost", "org.example.extra", %*{"value": "one"})
    check users_service.avatarUrl(service, "@alice:localhost").value == "mxc://localhost/avatar"
    check users_service.blurhash(service, "@alice:localhost").value == "hash"
    check users_service.timezone(service, "@alice:localhost").value == "Europe/Stockholm"
    check users_service.allProfileKeys(service, "@alice:localhost").len == 2

    let created = users_service.createDevice(
      service,
      "@alice:localhost",
      deviceId = "DEV1",
      accessToken = repeat("a", users_service.TokenLength),
      expiresAtMs = some(60_000'u64),
      refreshToken = "refresh_" & repeat("b", users_service.TokenLength),
      initialDeviceDisplayName = "Alice Mac",
      clientIp = "127.0.0.1",
      nowMs = 1_000'u64,
    )
    check created.ok
    check users_service.deviceExists(service, "@alice:localhost", "DEV1")
    check users_service.allDeviceIds(service, "@alice:localhost") == @["DEV1"]
    check users_service.findFromToken(service, repeat("a", users_service.TokenLength)).deviceId == "DEV1"
    check users_service.getDevicelistVersion(service, "@alice:localhost") > 0

    check users_service.updateDeviceLastSeen(
      service,
      "@alice:localhost",
      "DEV1",
      lastSeenIp = "192.0.2.1",
      lastSeenTs = 2_000'u64,
    ).ok
    let device = users_service.getDeviceMetadata(service, "@alice:localhost", "DEV1")
    check device.ok
    check device.device.lastSeenIp == "192.0.2.1"
    check device.device.lastSeenTs == 2_000'u64

  test "to-device queues use since-exclusive and to-inclusive stream windows":
    var service = users_service.initUserService()
    check users_service.createUser(service, "@alice:localhost").ok
    check users_service.createDevice(service, "@alice:localhost", deviceId = "DEV1").ok

    let first = users_service.addToDeviceEvent(
      service,
      "@bob:localhost",
      "@alice:localhost",
      "DEV1",
      "m.dummy",
      %*{"a": 1},
    )
    let second = users_service.addToDeviceEvent(
      service,
      "@bob:localhost",
      "@alice:localhost",
      "DEV1",
      "m.secret.send",
      %*{"b": 2},
    )

    check users_service.getToDeviceEvents(service, "@alice:localhost", "DEV1").len == 2
    let incremental = users_service.getToDeviceEvents(
      service,
      "@alice:localhost",
      "DEV1",
      since = some(first),
      toPos = some(second),
    )
    check incremental.len == 1
    check incremental[0].eventType == "m.secret.send"

    users_service.removeToDeviceEvents(service, "@alice:localhost", "DEV1", some(first))
    check users_service.getToDeviceEvents(service, "@alice:localhost", "DEV1").len == 1

  test "device keys one-time keys fallback keys OIDC and dehydrated devices persist native state":
    var service = users_service.initUserService()
    check users_service.createUser(service, "@alice:localhost").ok
    check users_service.createDevice(service, "@alice:localhost", deviceId = "DEV1").ok

    check users_service.addOneTimeKeys(service, "@alice:localhost", "DEV1", @[
      ("signed_curve25519:one", %*{"key": "otk1"}),
      ("signed_curve25519:two", %*{"key": "otk2"}),
    ]).ok
    check users_service.countOneTimeKeys(service, "@alice:localhost", "DEV1")["signed_curve25519"] == 2
    let claimed = users_service.claimOneTimeKey(service, "@alice:localhost", "DEV1", "signed_curve25519")
    check claimed.ok
    check claimed.keyId == "signed_curve25519:one"
    check users_service.countOneTimeKeys(service, "@alice:localhost", "DEV1")["signed_curve25519"] == 1

    check users_service.addFallbackKey(
      service,
      "@alice:localhost",
      "DEV1",
      "signed_curve25519:fallback",
      %*{"key": "fallback"},
    ).ok
    check users_service.unusedFallbackKeyAlgorithms(service, "@alice:localhost", "DEV1") == @["signed_curve25519"]
    check users_service.takeFallbackKey(service, "@alice:localhost", "DEV1", "signed_curve25519").ok
    check users_service.unusedFallbackKeyAlgorithms(service, "@alice:localhost", "DEV1").len == 0

    check users_service.addDeviceKeys(
      service,
      "@alice:localhost",
      "DEV1",
      %*{"user_id": "@alice:localhost", "device_id": "DEV1"},
    ).ok
    check users_service.getDeviceKeys(service, "@alice:localhost", "DEV1").keys["device_id"].getStr == "DEV1"
    check users_service.addCrossSigningKey(service, "@alice:localhost", "master", %*{"keys": {}}).ok
    check users_service.getCrossSigningKey(service, "@alice:localhost", "master").ok

    users_service.markOidcDevice(service, "@alice:localhost", "DEV1", "idp")
    check users_service.isOidcDevice(service, "@alice:localhost", "DEV1")
    check users_service.getOidcDeviceIdp(service, "@alice:localhost", "DEV1").get() == "idp"
    let expires = users_service.allowCrossSigningReplacement(service, "@alice:localhost", 1_000'u64)
    check expires == 601_000'u64
    check users_service.canReplaceCrossSigningKeys(service, "@alice:localhost", 2_000'u64)
    check not users_service.canReplaceCrossSigningKeys(service, "@alice:localhost", 601_000'u64)

    users_service.putDehydratedDevice(service, "@alice:localhost", "DEHYD", %*{"device_data": true})
    check users_service.getDehydratedDevice(service, "@alice:localhost").device.deviceId == "DEHYD"
    check users_service.removeDehydratedDevice(service, "@alice:localhost", "OTHER").ok
    check users_service.getDehydratedDevice(service, "@alice:localhost").ok
    check users_service.removeDehydratedDevice(service, "@alice:localhost", "DEHYD").ok
    check not users_service.getDehydratedDevice(service, "@alice:localhost").ok
