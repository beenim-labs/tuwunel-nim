import std/[json, options, strutils, tables, unittest]

import "service/registration_tokens/data" as registration_token_data
import "service/registration_tokens/mod" as registration_tokens
import "service/transaction_ids/mod" as transaction_ids
import "service/uiaa/mod" as uiaa_service

suite "Service registration token, transaction id and UIAA parity":
  test "registration token data enforces duplicate, expiry and max-use behavior":
    var data = registration_token_data.initRegistrationTokenData()
    let expiry = registration_token_data.tokenExpires(
      maxUses = some(1'u64),
      maxAgeUnix = some(1_100'i64),
    )
    let saved = registration_token_data.saveToken(data, "db-token", expiry)
    check saved.ok
    check saved.info.uses == 0'u64
    check not registration_token_data.saveToken(data, "db-token", expiry).ok

    check registration_token_data.checkToken(data, "db-token", consume = false, nowUnix = 1_000'i64)
    check data.tokens["db-token"].uses == 0'u64
    check registration_token_data.checkToken(data, "db-token", consume = true, nowUnix = 1_000'i64)
    check "db-token" notin data.tokens
    check not registration_token_data.checkToken(data, "db-token", consume = false, nowUnix = 1_000'i64)

    check registration_token_data.saveToken(
      data,
      "expired",
      registration_token_data.tokenExpires(maxAgeUnix = some(900'i64)),
    ).ok
    check registration_token_data.iterateAndCleanTokens(data, nowUnix = 1_000'i64).len == 0
    check "expired" notin data.tokens

  test "registration token service keeps config tokens valid and non-revocable":
    var service = registration_tokens.initRegistrationTokenService(["config-token"])
    check registration_tokens.isEnabled(service, nowUnix = 1_000'i64)
    check registration_tokens.isTokenValid(service, "config-token", nowUnix = 1_000'i64)
    check registration_tokens.tryConsume(service, "config-token", nowUnix = 1_000'i64)
    check not registration_tokens.revokeToken(service, "config-token").ok

    let issued = registration_tokens.issueToken(
      service,
      registration_token_data.tokenExpires(maxUses = some(2'u64)),
    )
    check issued.ok
    check issued.token.len == registration_tokens.RandomTokenLength
    check registration_tokens.isTokenValid(service, issued.token)
    let listed = registration_tokens.iterateTokens(service)
    check listed.len == 2

  test "transaction id responses are scoped by user device and txn id":
    var store = transaction_ids.initTransactionIdStore()
    transaction_ids.addTxnid(store, "@alice:example.test", "DEVICE", "txn1", "{\"event_id\":\"$1\"}")

    let hit = transaction_ids.existingTxnid(store, "@alice:example.test", "DEVICE", "txn1")
    check hit.ok
    check hit.data.contains("$1")
    check not transaction_ids.existingTxnid(store, "@alice:example.test", "OTHER", "txn1").ok
    check not transaction_ids.existingTxnid(store, "@bob:example.test", "DEVICE", "txn1").ok

    transaction_ids.addTxnid(store, "@alice:example.test", "txn2", "global-device-response")
    check transaction_ids.existingTxnid(store, "@alice:example.test", "txn2").ok

  test "UIAA stores requests, advances stages and removes completed sessions":
    var store = uiaa_service.initUiaaStore()
    let userId = "@alice:example.test"
    let deviceId = "DEVICE"
    let created = uiaa_service.create(
      store,
      userId,
      deviceId,
      uiaa_service.UiaaInfo(
        session: "session1",
        flows: @[@["m.login.dummy"]],
        completed: @[],
      ),
      %*{"delete_devices": ["DEVICE"]},
    )
    check created.session == "session1"
    check uiaa_service.getUiaaRequest(store, userId, deviceId, "session1")["delete_devices"][0].getStr == "DEVICE"
    check uiaa_service.getUiaaSession(store, userId, deviceId, "session1").ok

    let completed = uiaa_service.tryAuth(
      store,
      userId,
      deviceId,
      "m.login.dummy",
      uiaa_service.UiaaInfo(),
      session = "session1",
    )
    check completed.ok
    check completed.completed
    check not uiaa_service.getUiaaSession(store, userId, deviceId, "session1").ok

    let password = uiaa_service.tryAuth(
      store,
      userId,
      deviceId,
      "m.login.password",
      uiaa_service.UiaaInfo(flows: @[@["m.login.password"]]),
      identifierUser = "@bob:example.test",
      passwordOk = true,
    )
    check not password.ok
    check password.err == "User ID and access token mismatch."

    let badToken = uiaa_service.tryAuth(
      store,
      userId,
      deviceId,
      "m.login.registration_token",
      uiaa_service.UiaaInfo(flows: @[@["m.login.registration_token"]]),
      registrationTokenOk = false,
    )
    check badToken.ok
    check not badToken.completed
    check badToken.info.authErrorMessage == "Invalid registration token."
