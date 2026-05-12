import std/[json, locks, os, sets, strutils, tables, unittest]

include ../src/main/entrypoint

const EntrypointSource = staticRead("../src/main/entrypoint.nim")

proc newCompatState(statePath: string): ServerState =
  result = ServerState(
    statePath: statePath,
    serverName: "localhost",
    serverKeyId: "",
    serverSigningSeed: "",
    streamPos: 0,
    deliveryCounter: 0,
    roomCounter: 0,
    usersByName: initTable[string, string](),
    users: initTable[string, UserProfile](),
    tokens: initTable[string, AccessSession](),
    userTokens: initTable[string, seq[string]](),
    loginTokens: initTable[string, LoginTokenRecord](),
    refreshTokens: initTable[string, RefreshTokenRecord](),
    ssoSessions: initTable[string, SsoSessionRecord](),
    oidcClients: initTable[string, OidcClientRecord](),
    oidcAuthRequests: initTable[string, OidcAuthRequestRecord](),
    oidcAuthCodes: initTable[string, OidcAuthCodeRecord](),
    oidcAccessTokens: initTable[string, OidcAccessTokenRecord](),
    oidcRefreshTokens: initTable[string, OidcRefreshTokenRecord](),
    devices: initTable[string, DeviceRecord](),
    rooms: initTable[string, RoomData](),
    accountData: initTable[string, AccountDataRecord](),
    filters: initTable[string, JsonNode](),
    pushers: initTable[string, JsonNode](),
    pushRules: initTable[string, JsonNode](),
    backupCounter: 0,
    backupVersions: initTable[string, BackupVersionRecord](),
    backupSessions: initTable[string, BackupSessionRecord](),
    deviceKeys: initTable[string, DeviceKeyRecord](),
    oneTimeKeys: initTable[string, OneTimeKeyRecord](),
    fallbackKeys: initTable[string, FallbackKeyRecord](),
    dehydratedDevices: initTable[string, DehydratedDeviceRecord](),
    crossSigningKeys: initTable[string, CrossSigningKeyRecord](),
    deviceListUpdates: initTable[string, DeviceListUpdateRecord](),
    toDeviceEvents: initTable[string, ToDeviceEventRecord](),
    toDeviceTxnIds: initHashSet[string](),
    openIdTokens: initTable[string, OpenIdTokenRecord](),
    typing: initTable[string, TypingRecord](),
    typingUpdates: initTable[string, int64](),
    receipts: initTable[string, ReceiptRecord](),
    presence: initTable[string, PresenceRecord](),
    reports: @[],
    userJoinedRooms: initTable[string, HashSet[string]](),
    appserviceRegs: @[],
    appserviceByAsToken: initTable[string, AppserviceRegistration](),
    pendingDeliveries: @[],
    deliveryInFlight: 0,
    deliveryBaseMs: 100,
    deliveryMaxMs: 1000,
    deliveryMaxAttempts: 3,
    deliveryMaxInflight: 1,
    deliverySent: 0,
    deliveryFailed: 0,
    deliveryDeadLetters: 0,
    typingFederationTimeoutMs: 30000
  )
  initLock(result.lock)

suite "entrypoint compat helpers":
  test "client versions response matches Rust advertised versions and unstable flags":
    let payload = versionsResponse()
    check payload["versions"].len == 17
    check payload["versions"][0].getStr("") == "r0.0.1"
    check payload["versions"][^1].getStr("") == "v1.15"
    check payload["unstable_features"].len == 33
    check payload["unstable_features"]["org.matrix.msc3575"].getBool(false)
    check payload["unstable_features"]["org.matrix.msc4380.stable"].getBool(false)
    check payload["unstable_features"]["net.zemos.msc4383"].getBool(false)
    check payload["server"]["name"].getStr("") == "tuwunel"
    check payload["server"]["version"].getStr("") == RustBaselineVersion
    check payload["server"]["compiler"].getStr("") == "nim"

  test "tuwunel-specific version and local user count payloads match Rust shape":
    let versionPayload = tuwunel_api.tuwunelServerVersionPayload(RustBaselineVersion)
    check versionPayload["name"].getStr("") == "Tuwunel"
    check versionPayload["version"].getStr("") == RustBaselineVersion
    check tuwunel_api.tuwunelLocalUserCountPayload(3)["count"].getInt() == 3

  test "federation auth origin parser accepts standard X-Matrix headers":
    check federationAuthOriginHeader("X-Matrix origin=remote.example,key=ed25519:1,sig=abc") == "remote.example"
    check federationAuthOriginHeader("X-Matrix origin=\"remote.example\",key=ed25519:1,sig=abc") == "remote.example"
    check federationAuthOriginHeader("X-Matrix,origin=remote.example,key=ed25519:1,sig=abc") == "remote.example"
    check federationAuthOriginHeader("Bearer token") == ""

  test "session token helpers issue consume and rotate native tokens":
    let statePath = getTempDir() / "tuwunel-entrypoint-session-tokens.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "old",
      displayName: "Alice",
      avatarUrl: "",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )

    let accessToken = state.addTokenForUser("@alice:localhost", "DEV1", "Device 1")
    let login = state.createLoginTokenLocked("@alice:localhost", 120000)
    let consumed = state.consumeLoginTokenLocked(login.loginToken)
    check consumed.ok
    check consumed.userId == "@alice:localhost"
    check state.consumeLoginTokenLocked(login.loginToken).errcode == "M_FORBIDDEN"

    let refresh = state.createRefreshTokenLocked("@alice:localhost", "DEV1", 604800000)
    let rotated = state.refreshAccessTokenLocked(refresh.refreshToken, "Device 1", 604800000)
    check rotated.ok
    check rotated.accessToken.len > 0
    check rotated.refreshToken.startsWith("refresh_")
    check accessToken notin state.tokens
    check rotated.accessToken in state.tokens
    check refresh.refreshToken notin state.refreshTokens
    check rotated.refreshToken in state.refreshTokens

  test "SSO provider helpers create sessions redirects and login tokens":
    var cfg = initFlatConfig()
    cfg["global.identity_provider.client_id"] = newStringValue("test-idp")
    cfg["global.identity_provider.brand"] = newStringValue("Example")
    cfg["global.identity_provider.name"] = newStringValue("Example Login")
    cfg["global.identity_provider.authorization_url"] = newStringValue("https://idp.example/authorize")
    cfg["global.identity_provider.callback_url"] = newStringValue("https://matrix.example/_matrix/client/unstable/login/sso/callback/test-idp")
    cfg["global.identity_provider.scope"] = newArrayValue(@[newStringValue("openid"), newStringValue("profile")])

    let providerOpt = ssoProviderFromConfig(cfg)
    check providerOpt.isSome
    let provider = providerOpt.get()
    check provider.id == "test-idp"
    check provider.providerMatches("Example")
    let loginFlows = loginTypesResponseWithSso(cfg)
    check loginFlows["flows"][^1]["type"].getStr("") == "m.login.sso"
    check loginFlows["flows"][^1]["identity_providers"][0]["id"].getStr("") == "test-idp"

    let barePath = ssoLoginPathParts("/_matrix/client/v3/login/sso/redirect")
    check barePath.ok
    check barePath.providerId == ""
    let providerPath = ssoLoginPathParts("/_matrix/client/v3/login/sso/redirect/test-idp")
    check providerPath.ok
    check providerPath.providerId == "test-idp"
    check ssoCallbackProviderId("/_matrix/client/unstable/login/sso/callback/test-idp") == "test-idp"
    check pkceS256CodeChallenge("dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") ==
      "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"

    let statePath = getTempDir() / "tuwunel-entrypoint-sso.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "pw",
      displayName: "Alice",
      avatarUrl: "",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    let loginToken = state.createLoginTokenLocked("@alice:localhost", 120000)
    let session = state.createSsoSessionLocked(provider, "https://client.example/done", loginToken.loginToken)
    check session.userId == "@alice:localhost"
    check session.sessionId in state.ssoSessions
    let location = ssoAuthorizationLocation(provider, session)
    check location.startsWith("https://idp.example/authorize?")
    check location.contains("client_id=test-idp")
    check location.contains("state=" & encodeUrl(session.sessionId))
    check location.contains("code_challenge_method=S256")
    check location.contains("code_challenge=" & encodeUrl(pkceS256CodeChallenge(session.codeVerifier)))
    check ssoCookie(session, provider).contains("tuwunel_grant_session=")

    let completed = state.ensureSsoUserLocked(provider, session, newJObject())
    check completed.ok
    check completed.userId == "@alice:localhost"
    let callbackToken = state.createLoginTokenLocked(completed.userId, 120000)
    check callbackToken.loginToken in state.loginTokens

  test "OIDC server helpers register clients complete grants and revoke issued devices":
    let statePath = getTempDir() / "tuwunel-entrypoint-oidc.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "pw",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/alice",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )

    let metadata = oidcProviderMetadataPayload("https://matrix.example/")
    check metadata["issuer"].getStr("") == "https://matrix.example/"
    check metadata["authorization_endpoint"].getStr("") == "https://matrix.example/_tuwunel/oidc/authorize"
    check metadata["grant_types_supported"].len == 2
    check oidcJwksPayload().hasKey("keys")

    let registered = state.registerOidcClientLocked(%*{
      "redirect_uris": ["https://client.example/callback"],
      "client_name": "Beenim Desktop",
    })
    check registered.ok
    let clientId = registered.payload["client_id"].getStr("")
    check clientId.len > 0
    check clientId in state.oidcClients

    let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
    let authParams = parseUrlEncodedParams(
      "client_id=" & encodeUrl(clientId) &
      "&redirect_uri=" & encodeUrl("https://client.example/callback") &
      "&response_type=code" &
      "&response_mode=query" &
      "&scope=" & encodeUrl("openid urn:matrix:org.matrix.msc2967.client:device:OIDCDEV") &
      "&state=state123" &
      "&nonce=nonce123" &
      "&code_challenge_method=S256" &
      "&code_challenge=" & encodeUrl(pkceS256CodeChallenge(verifier))
    )
    let authorize = state.createOidcAuthorizeRedirectLocked(authParams, "test-idp", "https://matrix.example/")
    check authorize.ok
    check authorize.location.startsWith("https://matrix.example/_matrix/client/v3/login/sso/redirect/test-idp?")
    check authorize.location.contains(encodeUrl("https://matrix.example/_tuwunel/oidc/_complete?oidc_req_id="))
    check state.oidcAuthRequests.len == 1

    var requestId = ""
    for key in state.oidcAuthRequests.keys:
      requestId = key
    let loginToken = state.createLoginTokenLocked("@alice:localhost", 120000)
    let completed = state.completeOidcAuthRequestLocked(requestId, loginToken.loginToken)
    check completed.ok
    check completed.location.startsWith("https://client.example/callback?")
    check completed.location.contains("state=state123")
    check loginToken.loginToken notin state.loginTokens

    let callbackParams = parseUrlEncodedParams(parseUri(completed.location).query)
    let code = firstParam(callbackParams, "code")
    check code.len > 0
    check code in state.oidcAuthCodes

    let tokenParams = parseUrlEncodedParams(
      "grant_type=authorization_code" &
      "&code=" & encodeUrl(code) &
      "&redirect_uri=" & encodeUrl("https://client.example/callback") &
      "&client_id=" & encodeUrl(clientId) &
      "&code_verifier=" & encodeUrl(verifier)
    )
    let token = state.exchangeOidcAuthCodeLocked(tokenParams, "https://matrix.example/", 604800000)
    check token.ok
    let accessToken = token.payload["access_token"].getStr("")
    let refreshToken = token.payload["refresh_token"].getStr("")
    check accessToken in state.tokens
    check accessToken in state.oidcAccessTokens
    check refreshToken in state.refreshTokens
    check refreshToken in state.oidcRefreshTokens
    check token.payload["id_token"].getStr("").split('.').len == 3
    check code notin state.oidcAuthCodes

    let userInfo = state.oidcUserInfoPayloadLocked(accessToken)
    check userInfo.ok
    check userInfo.payload["sub"].getStr("") == "@alice:localhost"
    check userInfo.payload["name"].getStr("") == "Alice"
    let plainAccess = state.addTokenForUser("@alice:localhost", "PLAIN")
    check not state.oidcUserInfoPayloadLocked(plainAccess).ok

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check clientId in loaded.oidcClients
    check accessToken in loaded.oidcAccessTokens

    let refreshed = state.refreshOidcTokenLocked(
      parseUrlEncodedParams("grant_type=refresh_token&refresh_token=" & encodeUrl(refreshToken)),
      604800000,
    )
    check refreshed.ok
    check accessToken notin state.tokens
    check refreshToken notin state.refreshTokens
    let refreshedAccess = refreshed.payload["access_token"].getStr("")
    check refreshedAccess in state.oidcAccessTokens

    let badHint = state.revokeOidcTokenLocked(refreshedAccess, "device")
    check not badHint.ok
    check badHint.error == "unsupported_token_type"
    let revoked = state.revokeOidcTokenLocked(refreshedAccess, "access_token")
    check revoked.ok
    check refreshedAccess notin state.tokens
    check state.revokeOidcTokenLocked("missing", "").ok

  test "OIDC account management callbacks preserve login-token and session semantics":
    var cfg = initFlatConfig()
    cfg["global.identity_provider.client_id"] = newStringValue("test-idp")
    cfg["global.identity_provider.brand"] = newStringValue("Example")
    cfg["global.identity_provider.name"] = newStringValue("Example Login")
    cfg["global.identity_provider.authorization_url"] = newStringValue("https://idp.example/authorize")
    cfg["global.identity_provider.callback_url"] = newStringValue("https://matrix.example/_matrix/client/unstable/login/sso/callback/test-idp")
    cfg["global.identity_provider.scope"] = newArrayValue(@[newStringValue("openid"), newStringValue("profile")])
    let provider = ssoProviderFromConfig(cfg).get()

    let statePath = getTempDir() / "tuwunel-entrypoint-oidc-account.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "pw",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/alice",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    let firstToken = state.addTokenForUser("@alice:localhost", "DEV1", "Laptop")
    let targetToken = state.addTokenForUser("@alice:localhost", "DEV2", "Phone")
    let targetRefresh = state.createRefreshTokenLocked("@alice:localhost", "DEV2", 604800000)
    state.oidcAccessTokens[targetToken] = OidcAccessTokenRecord(
      accessToken: targetToken,
      userId: "@alice:localhost",
      deviceId: "DEV2",
      clientId: "client-account",
      scope: "openid",
      expiresAtMs: nowMs() + 3600000,
    )
    state.oidcRefreshTokens[targetRefresh.refreshToken] = OidcRefreshTokenRecord(
      refreshToken: targetRefresh.refreshToken,
      userId: "@alice:localhost",
      deviceId: "DEV2",
      clientId: "client-account",
      scope: "openid",
      expiresAtMs: targetRefresh.expiresAtMs,
    )

    let accountRedirect = accountSsoRedirectLocation(
      provider,
      "https://matrix.example/",
      "org.matrix.session_view",
      "DEV2",
    )
    check accountRedirect.startsWith("https://matrix.example/_matrix/client/v3/login/sso/redirect/test-idp?")
    let redirectParams = parseUrlEncodedParams(parseUri(accountRedirect).query)
    check firstParam(redirectParams, "redirectUrl") ==
      "https://matrix.example/_tuwunel/oidc/account_callback?action=org.matrix.session_view&device_id=DEV2"

    let invalidLogin = state.createLoginTokenLocked("@alice:localhost", 120000)
    let invalid = state.completeAccountCallbackLocked(
      "GET",
      "org.matrix.unsupported",
      "",
      invalidLogin.loginToken,
      "",
    )
    check not invalid.ok
    check invalid.errcode == "M_INVALID_PARAM"
    check invalidLogin.loginToken in state.loginTokens

    let sessionsLogin = state.createLoginTokenLocked("@alice:localhost", 120000)
    let sessions = state.completeAccountCallbackLocked(
      "GET",
      "org.matrix.sessions_list",
      "",
      sessionsLogin.loginToken,
      "",
    )
    check sessions.ok
    check sessions.html.contains("Active Sessions")
    check sessions.html.contains("DEV1")
    check sessions.html.contains("DEV2")
    check sessionsLogin.loginToken notin state.loginTokens

    let profileLogin = state.createLoginTokenLocked("@alice:localhost", 120000)
    let profilePage = state.completeAccountCallbackLocked(
      "GET",
      "org.matrix.profile",
      "",
      profileLogin.loginToken,
      "",
    )
    check profilePage.ok
    check profilePage.html.contains("Profile")
    check profileLogin.loginToken in state.loginTokens
    let profileSaved = state.completeAccountCallbackLocked(
      "POST",
      "org.matrix.profile",
      "",
      profileLogin.loginToken,
      " Alice\nZero ",
    )
    check profileSaved.ok
    check profileSaved.changed
    check profileLogin.loginToken notin state.loginTokens
    check state.users["@alice:localhost"].displayName == "AliceZero"

    let viewLogin = state.createLoginTokenLocked("@alice:localhost", 120000)
    let sessionView = state.completeAccountCallbackLocked(
      "GET",
      "org.matrix.session_view",
      "DEV2",
      viewLogin.loginToken,
      "",
    )
    check sessionView.ok
    check sessionView.html.contains("Session Details")
    check sessionView.html.contains("Phone")
    check viewLogin.loginToken in state.loginTokens
    let endConfirm = state.completeAccountCallbackLocked(
      "GET",
      "org.matrix.session_end",
      "DEV2",
      viewLogin.loginToken,
      "",
    )
    check endConfirm.ok
    check endConfirm.html.contains("Sign Out Session")
    check viewLogin.loginToken in state.loginTokens

    let ended = state.completeAccountCallbackLocked(
      "POST",
      "org.matrix.session_end",
      "DEV2",
      viewLogin.loginToken,
      "",
    )
    check ended.ok
    check ended.changed
    check viewLogin.loginToken notin state.loginTokens
    check deviceKey("@alice:localhost", "DEV2") notin state.devices
    check targetToken notin state.tokens
    check targetRefresh.refreshToken notin state.refreshTokens
    check targetToken notin state.oidcAccessTokens
    check targetRefresh.refreshToken notin state.oidcRefreshTokens
    check firstToken in state.tokens
    check deviceKey("@alice:localhost", "DEV1") in state.devices

  test "joinedMembersPayload includes only joined users with profile data":
    let statePath = getTempDir() / "tuwunel-entrypoint-compat-state.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/alice",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    state.users["@bob:localhost"] = UserProfile(
      userId: "@bob:localhost",
      username: "bob",
      password: "",
      displayName: "Bob",
      avatarUrl: "",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    let room = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: true,
      members: {
        "@alice:localhost": "join",
        "@bob:localhost": "invite",
        "@carol:localhost": "join"
      }.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

    let payload = joinedMembersPayload(state, room)
    check payload["joined"].hasKey("@alice:localhost")
    check payload["joined"].hasKey("@carol:localhost")
    check not payload["joined"].hasKey("@bob:localhost")
    check payload["joined"]["@alice:localhost"]["display_name"].getStr("") == "Alice"
    check payload["joined"]["@alice:localhost"]["avatar_url"].getStr("") == "mxc://localhost/alice"

  test "media upload helpers persist data and metadata":
    let statePath = getTempDir() / "tuwunel-entrypoint-media-state.json"
    let mediaDir = mediaDirFromStatePath(statePath)
    if dirExists(mediaDir):
      for kind, entry in walkDir(mediaDir):
        if kind in {pcFile, pcLinkToFile}:
          removeFile(entry)
      removeDir(mediaDir)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if dirExists(mediaDir):
        for kind, entry in walkDir(mediaDir):
          if kind in {pcFile, pcLinkToFile}:
            removeFile(entry)
        removeDir(mediaDir)

    let mediaId = storeUploadedMedia(state, "hello", "text/plain", "hello.txt")
    check mediaId.startsWith("media_")
    check fileExists(mediaDataPath(state.statePath, mediaId))
    let meta = loadStoredMediaMeta(state, mediaId)
    check meta.ok
    check meta.contentType == "text/plain"
    check meta.fileName == "hello.txt"
    check readFile(mediaDataPath(state.statePath, mediaId)) == "hello"
    let loaded = loadStoredMedia(state, mediaId)
    check loaded.ok
    check loaded.body == "hello"
    check loaded.contentType == "text/plain"
    check mediaContentDisposition(loaded.contentType, loaded.fileName) == "inline; filename=\"hello.txt\""

  test "media path helpers recognize upload and download aliases":
    check isMediaUploadPath("/_matrix/media/v3/upload")
    check isMediaUploadPath("/_matrix/client/v1/media/upload")
    check isMediaPreviewPath("/_matrix/client/v1/media/preview_url")
    let parsed = mediaDownloadParts("/_matrix/client/v1/media/download/localhost/abc123/test.png")
    check parsed.ok
    check parsed.mediaId == "abc123"
    let thumb = mediaDownloadParts("/_matrix/media/v3/thumbnail/localhost/thumb123")
    check thumb.ok
    check thumb.mediaId == "thumb123"
    let fedDownload = federationMediaPathParts("/_matrix/federation/v1/media/download/fed123")
    check fedDownload.ok
    check not fedDownload.thumbnail
    check fedDownload.mediaId == "fed123"
    let fedThumbnail = federationMediaPathParts("/_matrix/federation/v1/media/thumbnail/fedthumb")
    check fedThumbnail.ok
    check fedThumbnail.thumbnail
    check fedThumbnail.mediaId == "fedthumb"

  test "entrypoint only has one sync route handler":
    check EntrypointSource.count("if isSyncPath(path):") == 1

  test "entrypoint creates rooms with default power levels":
    check "\"m.room.power_levels\"" in EntrypointSource

  test "appendEventLocked indexes empty-key state events":
    let statePath = getTempDir() / "tuwunel-entrypoint-state-index.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    let ev = state.appendEventLocked(
      "!room:localhost",
      "@creator:localhost",
      "m.room.power_levels",
      "",
      defaultPowerLevelsContent("@creator:localhost")
    )
    check stateKey("m.room.power_levels", "") in state.rooms["!room:localhost"].stateByKey
    check stateEventResponsePayload(ev, "")["users"]["@creator:localhost"].getInt(0) == 100
    let formatted = stateEventResponsePayload(ev, "event")
    check formatted["event_id"].getStr("").len > 0
    check formatted["state_key"].getStr("missing") == ""
    check formatted["content"]["users"]["@creator:localhost"].getInt(0) == 100

  test "empty-key state aliases parse stable and trailing-slash routes":
    let v3 = roomAndStateEventFromPath("/_matrix/client/v3/rooms/!room%3Alocalhost/state/m.room.power_levels")
    check v3.ok
    check v3.roomId == "!room:localhost"
    check v3.eventType == "m.room.power_levels"
    check v3.stateKeyValue == ""

    let v3Slash = roomAndStateEventFromPath("/_matrix/client/v3/rooms/!room%3Alocalhost/state/m.room.power_levels/")
    check v3Slash.ok
    check v3Slash.stateKeyValue == ""

    let r0 = roomAndStateEventFromPath("/_matrix/client/r0/rooms/!room%3Alocalhost/state/m.room.name")
    check r0.ok
    check r0.eventType == "m.room.name"

    let r0Slash = roomAndStateEventFromPath("/_matrix/client/r0/rooms/!room%3Alocalhost/state/m.room.name/")
    check r0Slash.ok
    check r0Slash.stateKeyValue == ""

  test "appendEventLocked stores top-level redacts for redaction events":
    let statePath = getTempDir() / "tuwunel-entrypoint-redact.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    let ev = state.appendEventLocked(
      "!room:localhost",
      "@creator:localhost",
      "m.room.redaction",
      "",
      %*{
        "reason": "Removed in Beenim",
        "delete_for_everyone": true,
        "redacts": "$target"
      },
      redacts = "$target"
    )

    check ev.redacts == "$target"
    let payload = ev.eventToJson()
    check payload["redacts"].getStr("") == "$target"
    check payload["content"]["redacts"].getStr("") == "$target"

  test "roomAndRedactFromPath parses client redaction routes":
    let parsedV3 = roomAndRedactFromPath("/_matrix/client/v3/rooms/%21room%3Alocalhost/redact/%24evt1/txn123")
    check parsedV3.roomId == "!room:localhost"
    check parsedV3.eventId == "$evt1"
    check parsedV3.txnId == "txn123"

    let parsedR0 = roomAndRedactFromPath("/_matrix/client/r0/rooms/%21room%3Alocalhost/redact/%24evt2/txn456")
    check parsedR0.roomId == "!room:localhost"
    check parsedR0.eventId == "$evt2"
    check parsedR0.txnId == "txn456"

  test "ensureDefaultPowerLevelsLocked repairs existing rooms":
    let statePath = getTempDir() / "tuwunel-entrypoint-power-repair.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@creator:localhost",
      isDirect: true,
      members: {"@creator:localhost": "join"}.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

    check state.ensureDefaultPowerLevelsLocked("!room:localhost", "@viewer:localhost")
    let room = state.rooms["!room:localhost"]
    let key = stateKey("m.room.power_levels", "")
    check key in room.stateByKey
    check room.stateByKey[key].content["users"]["@creator:localhost"].getInt(0) == 100
    check roomStateArray(room).len == 1

  test "ensureDefaultJoinRulesLocked repairs existing rooms":
    let statePath = getTempDir() / "tuwunel-entrypoint-join-rules-repair.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@creator:localhost",
      isDirect: true,
      members: {"@creator:localhost": "join"}.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

    check state.ensureDefaultJoinRulesLocked("!room:localhost", "@viewer:localhost")
    let room = state.rooms["!room:localhost"]
    let key = stateKey("m.room.join_rules", "")
    check key in room.stateByKey
    check room.stateByKey[key].content["join_rule"].getStr("") == "invite"

  test "entrypoint handles room join by id path":
    check "roomIdFromRoomsPath(path, \"join\")" in EntrypointSource

  test "entrypoint handles room messages path":
    check "roomIdFromRoomsPath(path, \"messages\")" in EntrypointSource

  test "room event path parser covers event and context routes":
    let eventRoute = roomAndEventFromPath("/_matrix/client/v3/rooms/%21room%3Alocalhost/event/%24evt%2F1", "event")
    check eventRoute.roomId == "!room:localhost"
    check eventRoute.eventId == "$evt/1"

    let contextRoute = roomAndEventFromPath("/_matrix/client/r0/rooms/%21room%3Alocalhost/context/%24evt2", "context")
    check contextRoute.roomId == "!room:localhost"
    check contextRoute.eventId == "$evt2"

    let wrongMarker = roomAndEventFromPath("/_matrix/client/v3/rooms/%21room%3Alocalhost/context/%24evt2", "event")
    check wrongMarker.roomId == ""
    check wrongMarker.eventId == ""

  test "room history helpers expose aliases context members and state-keyed events":
    let statePath = getTempDir() / "tuwunel-entrypoint-room-history.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: true,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@bob:localhost", membershipContent("leave"))
    let aliasEv = state.appendEventLocked(
      "!room:localhost",
      "@alice:localhost",
      "m.room.canonical_alias",
      "",
      %*{
        "alias": "#main:localhost",
        "alt_aliases": ["#side:localhost", "#main:localhost"]
      }
    )
    let msg1 = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "one"})
    let msg2 = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "two"})
    let msg3 = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "three"})

    let room = state.rooms["!room:localhost"]
    check roomMembersArray(room, "join", "").len == 1
    check roomMembersArray(room, "", "leave").len == 1

    let aliases = roomAliasesPayload(room)
    check aliases["aliases"].len == 2
    check aliases["aliases"][0].getStr("") == "#main:localhost"
    check aliases["aliases"][1].getStr("") == "#side:localhost"

    let aliasJson = aliasEv.eventToJson()
    check aliasJson.hasKey("state_key")
    check aliasJson["state_key"].getStr("missing") == ""

    let idx = roomEventIndex(room, msg2.eventId)
    check idx >= 0
    check room.timeline[idx].eventToJson()["event_id"].getStr("") == msg2.eventId

    let context = roomContextPayload(room, idx, 3)
    check context["event"]["event_id"].getStr("") == msg2.eventId
    check context["events_before"].len == 1
    check context["events_before"][0]["event_id"].getStr("") == msg1.eventId
    check context["events_after"].len == 1
    check context["events_after"][0]["event_id"].getStr("") == msg3.eventId
    check context["state"].len >= 2

  test "room search returns timeline hits pagination highlights and state":
    let statePath = getTempDir() / "tuwunel-entrypoint-room-search.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    state.rooms["!other:localhost"] = RoomData(
      roomId: "!other:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.name", "", %*{"name": "Search Room"})
    let older = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "needle alpha"})
    let newer = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "needle beta"})
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "other text"})
    discard state.appendEventLocked("!other:localhost", "@alice:localhost", "m.room.member", "@bob:localhost", membershipContent("join"))
    discard state.appendEventLocked("!other:localhost", "@bob:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "needle hidden"})

    let firstPage = state.searchRoomEventsPayload(
      "@alice:localhost",
      %*{
        "search_categories": {
          "room_events": {
            "search_term": "needle beta",
            "include_state": true,
            "filter": {
              "limit": 1,
              "rooms": ["!room:localhost", "!other:localhost"]
            }
          }
        }
      },
      ""
    )
    let roomEvents = firstPage["search_categories"]["room_events"]
    check roomEvents["count"].getInt() == 1
    check roomEvents["results"].len == 1
    check roomEvents["results"][0]["result"]["event_id"].getStr("") == newer.eventId
    check roomEvents["results"][0]["context"]["events_before"].len >= 1
    check roomEvents["state"].hasKey("!room:localhost")
    check not roomEvents["state"].hasKey("!other:localhost")
    check roomEvents["highlights"].len == 2

    let paged = state.searchRoomEventsPayload(
      "@alice:localhost",
      %*{
        "search_categories": {
          "room_events": {
            "search_term": "needle",
            "filter": {"limit": 1}
          }
        }
      },
      "1"
    )
    let pagedEvents = paged["search_categories"]["room_events"]
    check pagedEvents["count"].getInt() == 2
    check pagedEvents["results"].len == 1
    check pagedEvents["results"][0]["result"]["event_id"].getStr("") == older.eventId

  test "events stream returns joined-room timeline events after token":
    let statePath = getTempDir() / "tuwunel-entrypoint-events-stream.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    state.rooms["!hidden:localhost"] = RoomData(
      roomId: "!hidden:localhost",
      creator: "@bob:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    let first = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"body": "first"})
    let second = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"body": "second"})
    discard state.appendEventLocked("!hidden:localhost", "@bob:localhost", "m.room.member", "@bob:localhost", membershipContent("join"))
    discard state.appendEventLocked("!hidden:localhost", "@bob:localhost", "m.room.message", "", %*{"body": "hidden"})

    let stream = state.eventStreamPayload("@alice:localhost", "", encodeSinceToken(first.streamPos))
    check stream.ok
    check stream.payload["chunk"].len == 1
    check stream.payload["chunk"][0]["event_id"].getStr("") == second.eventId
    check stream.payload["start"].getStr("") == encodeSinceToken(second.streamPos)
    check stream.payload["end"].getStr("") == encodeSinceToken(second.streamPos)

    let hidden = state.eventStreamPayload("@alice:localhost", "!hidden:localhost", "0")
    check not hidden.ok

    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@bob:localhost", membershipContent("join"))
    let bobMessage = state.appendEventLocked("!room:localhost", "@bob:localhost", "m.room.message", "", %*{"body": "notify alice"})
    let notifications = state.notificationsPayload("@alice:localhost", encodeSinceToken(second.streamPos), "", 10)
    check notifications["notifications"].len == 1
    check notifications["notifications"][0]["room_id"].getStr("") == "!room:localhost"
    check notifications["notifications"][0]["event"]["event_id"].getStr("") == bobMessage.eventId
    check notifications["notifications"][0]["actions"][0].getStr("") == "notify"
    check state.notificationsPayload("@alice:localhost", "0", "highlight", 10)["notifications"].len == 0

  test "sliding sync v5 returns native room windows and extension state":
    let statePath = getTempDir() / "tuwunel-entrypoint-sync-v5.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    check isSyncV5Path("/_matrix/client/unstable/org.matrix.simplified_msc3575/sync")
    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "pw",
      displayName: "Alice",
      avatarUrl: "",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.name", "", %*{"name": "Sync V5"})
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"msgtype": "m.text", "body": "hello v5"})

    let payload = state.slidingSyncV5Payload(
      "@alice:localhost",
      "DEV1",
      %*{
        "txn_id": "txn-v5",
        "lists": {
          "main": {
            "ranges": [[0, 0]]
          }
        }
      },
      0
    )
    check payload["txn_id"].getStr("") == "txn-v5"
    check payload["pos"].getStr("").len > 0
    check payload["lists"]["main"]["count"].getInt(0) == 1
    check payload["lists"]["main"]["ops"][0]["room_ids"][0].getStr("") == "!room:localhost"
    check payload["rooms"]["!room:localhost"]["name"].getStr("") == "Sync V5"
    check payload["rooms"]["!room:localhost"]["timeline"].len >= 3
    check payload["rooms"]["!room:localhost"]["required_state"].len >= 2
    check payload["extensions"]["e2ee"].hasKey("device_one_time_keys_count")

  test "relations and threads return persisted timeline relations":
    let statePath = getTempDir() / "tuwunel-entrypoint-relations.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    let relationParts = relationPathParts(
      "/_matrix/client/v3/rooms/%21room%3Alocalhost/relations/%24root/m.annotation/m.reaction"
    )
    check relationParts.ok
    check relationParts.roomId == "!room:localhost"
    check relationParts.eventId == "$root"
    check relationParts.relType == "m.annotation"
    check relationParts.eventType == "m.reaction"

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    state.rooms["!hidden:localhost"] = RoomData(
      roomId: "!hidden:localhost",
      creator: "@bob:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )

    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    let root = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{"body": "root"})
    let reaction = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.reaction", "", %*{
      "m.relates_to": {
        "rel_type": "m.annotation",
        "event_id": root.eventId,
        "key": "👍"
      }
    })
    let edit = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{
      "body": "edit",
      "m.relates_to": {
        "rel_type": "m.replace",
        "event_id": root.eventId
      }
    })
    let threadReply = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.message", "", %*{
      "body": "thread reply",
      "m.relates_to": {
        "rel_type": "m.thread",
        "event_id": root.eventId
      }
    })
    let nestedReaction = state.appendEventLocked("!room:localhost", "@alice:localhost", "m.reaction", "", %*{
      "m.relates_to": {
        "rel_type": "m.annotation",
        "event_id": reaction.eventId,
        "key": "nested"
      }
    })
    discard edit
    discard threadReply

    let annotations = state.relatedEventsPayload(
      "@alice:localhost",
      (ok: true, roomId: "!room:localhost", eventId: root.eventId, relType: "m.annotation", eventType: "m.reaction"),
      "",
      "",
      "f",
      10,
      false,
    )
    check annotations.ok
    check annotations.payload["chunk"].len == 1
    check annotations.payload["chunk"][0]["event_id"].getStr("") == reaction.eventId

    let allRelations = state.relatedEventsPayload(
      "@alice:localhost",
      (ok: true, roomId: "!room:localhost", eventId: root.eventId, relType: "", eventType: ""),
      "",
      "",
      "f",
      2,
      false,
    )
    check allRelations.ok
    check allRelations.payload["chunk"].len == 2
    check allRelations.payload["next_batch"].getStr("").len > 0

    let recursive = state.relatedEventsPayload(
      "@alice:localhost",
      (ok: true, roomId: "!room:localhost", eventId: root.eventId, relType: "m.annotation", eventType: "m.reaction"),
      "",
      "",
      "f",
      10,
      true,
    )
    check recursive.ok
    check recursive.payload["chunk"].len == 2
    check recursive.payload["chunk"][1]["event_id"].getStr("") == nestedReaction.eventId
    check recursive.payload["recursion_depth"].getInt() >= 1

    let threads = state.threadEventsPayload("@alice:localhost", "!room:localhost", "", 10)
    check threads.ok
    check threads.payload["chunk"].len == 1
    check threads.payload["chunk"][0]["event_id"].getStr("") == root.eventId

    discard state.appendEventLocked("!hidden:localhost", "@bob:localhost", "m.room.member", "@bob:localhost", membershipContent("join"))
    let forbidden = state.relatedEventsPayload(
      "@alice:localhost",
      (ok: true, roomId: "!hidden:localhost", eventId: root.eventId, relType: "", eventType: ""),
      "",
      "",
      "b",
      10,
      false,
    )
    check not forbidden.ok
    check not forbidden.notFound

  test "filter and account-data path parsers cover stable client routes":
    let filterCreate = userFilterPathParts("/_matrix/client/v3/user/%40alice%3Alocalhost/filter")
    check filterCreate.ok
    check filterCreate.create
    check filterCreate.userId == "@alice:localhost"

    let filterGet = userFilterPathParts("/_matrix/client/r0/user/%40alice%3Alocalhost/filter/abcd")
    check filterGet.ok
    check not filterGet.create
    check filterGet.filterId == "abcd"

    let global = userAccountDataPathParts("/_matrix/client/v3/user/%40alice%3Alocalhost/account_data/m.direct")
    check global.ok
    check global.userId == "@alice:localhost"
    check global.roomId == ""
    check global.eventType == "m.direct"

    let room = userAccountDataPathParts("/_matrix/client/r0/user/%40alice%3Alocalhost/rooms/%21room%3Alocalhost/account_data/m.tag")
    check room.ok
    check room.roomId == "!room:localhost"
    check room.eventType == "m.tag"

    let deleted = userAccountDataPathParts("/_matrix/client/unstable/org.matrix.msc3391/user/%40alice%3Alocalhost/account_data/m.direct")
    check deleted.ok
    check deleted.eventType == "m.direct"

  test "tag path parsers cover stable client routes":
    let collection = userTagsPathParts("/_matrix/client/v3/user/%40alice%3Alocalhost/rooms/%21room%3Alocalhost/tags")
    check collection.ok
    check collection.collection
    check collection.userId == "@alice:localhost"
    check collection.roomId == "!room:localhost"

    let detail = userTagsPathParts("/_matrix/client/r0/user/%40alice%3Alocalhost/rooms/%21room%3Alocalhost/tags/u.work")
    check detail.ok
    check not detail.collection
    check detail.tag == "u.work"

  test "presence path parser covers stable client routes":
    let presence = presencePathParts("/_matrix/client/v3/presence/%40alice%3Alocalhost/status")
    check presence.ok
    check presence.userId == "@alice:localhost"

    let legacy = presencePathParts("/_matrix/client/r0/presence/%40bob%3Alocalhost/status")
    check legacy.ok
    check legacy.userId == "@bob:localhost"

  test "profile path parser covers stable and unstable field routes":
    let display = profilePathParts("/_matrix/client/v3/profile/%40alice%3Alocalhost/displayname")
    check display.userId == "@alice:localhost"
    check display.field == "displayname"

    let custom = profilePathParts("/_matrix/client/unstable/uk.tcpip.msc4133/profile/%40alice%3Alocalhost/com.example.status")
    check custom.userId == "@alice:localhost"
    check custom.field == "com.example.status"

    let timezone = profilePathParts("/_matrix/client/unstable/us.cloke.msc4175/profile/%40alice%3Alocalhost/m.tz")
    check timezone.userId == "@alice:localhost"
    check timezone.field == "m.tz"

  test "typing, receipt, and read-marker path parsers cover stable client routes":
    let typing = roomTypingPathParts("/_matrix/client/v3/rooms/%21room%3Alocalhost/typing/%40alice%3Alocalhost")
    check typing.ok
    check typing.roomId == "!room:localhost"
    check typing.userId == "@alice:localhost"

    let receipt = roomReceiptPathParts("/_matrix/client/r0/rooms/%21room%3Alocalhost/receipt/m.read/%24event")
    check receipt.ok
    check receipt.roomId == "!room:localhost"
    check receipt.receiptType == "m.read"
    check receipt.eventId == "$event"

    let readMarker = roomReadMarkersPathParts("/_matrix/client/v3/rooms/%21room%3Alocalhost/read_markers")
    check readMarker.ok
    check readMarker.roomId == "!room:localhost"

  test "typing state emits active and cleared ephemeral sync events":
    let statePath = getTempDir() / "tuwunel-entrypoint-typing.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.setTypingLocked("!room:localhost", "@alice:localhost", true, 30000)
    let initial = state.typingEventsForSync("!room:localhost", 0, true)
    check initial.len == 1
    check initial[0]["type"].getStr("") == "m.typing"
    check initial[0]["content"]["user_ids"][0].getStr("") == "@alice:localhost"

    let sinceActive = state.streamPos
    state.setTypingLocked("!room:localhost", "@alice:localhost", false, 30000)
    let cleared = state.typingEventsForSync("!room:localhost", sinceActive, false)
    check cleared.len == 1
    check cleared[0]["content"]["user_ids"].len == 0

  test "receipt records are grouped for sync and persisted":
    let statePath = getTempDir() / "tuwunel-entrypoint-receipts.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    discard state.setReceiptLocked("!room:localhost", "$event", "m.read", "@alice:localhost", "")
    discard state.setReceiptLocked("!room:localhost", "$event", "m.read.private", "@bob:localhost", "$thread")
    let ephemeral = state.receiptEventsForSync("!room:localhost", 0, true)
    check ephemeral.len == 1
    check ephemeral[0]["type"].getStr("") == "m.receipt"
    check ephemeral[0]["content"]["$event"]["m.read"]["@alice:localhost"]["ts"].getInt(0) > 0
    check ephemeral[0]["content"]["$event"]["m.read.private"]["@bob:localhost"]["thread_id"].getStr("") == "$thread"

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.receipts[receiptKey("!room:localhost", "$event", "m.read", "@alice:localhost", "")].userId == "@alice:localhost"

  test "presence records persist and sync only to users sharing rooms":
    let statePath = getTempDir() / "tuwunel-entrypoint-presence.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/alice",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: true,
      members: {
        "@alice:localhost": "join",
        "@bob:localhost": "join"
      }.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    state.rebuildJoinedRooms()

    discard state.setPresenceLocked("@alice:localhost", "online", "available")
    let bobPresence = state.setPresenceLocked("@bob:localhost", "unavailable", "")
    discard state.setPresenceLocked("@carol:localhost", "online", "hidden")

    let response = presenceResponseJson(state.presence["@alice:localhost"])
    check response["presence"].getStr("") == "online"
    check response["currently_active"].getBool(false)
    check response["status_msg"].getStr("") == "available"

    let events = state.presenceEventsForSync("@alice:localhost", 0, true)
    check events.len == 2
    check events[0]["type"].getStr("") == "m.presence"
    check events[0]["sender"].getStr("") == "@alice:localhost"
    check events[0]["content"]["displayname"].getStr("") == "Alice"
    check events[1]["sender"].getStr("") == "@bob:localhost"

    let noDelta = state.presenceEventsForSync("@alice:localhost", bobPresence.streamPos, false)
    check noDelta.len == 0

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.presence["@alice:localhost"].presence == "online"
    check loaded.presence["@bob:localhost"].presence == "unavailable"

  test "profile fields include blurhash timezone custom keys and persistence":
    let statePath = getTempDir() / "tuwunel-entrypoint-profile-fields.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    var user = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/avatar",
      blurhash: "LKO2?U%2Tw=w]~RBVZRi};RPxuwH",
      timezone: "Europe/Stockholm",
      profileFields: initTable[string, JsonNode]()
    )
    user.setUserProfileField("com.example.status", %*{"com.example.status": "coding"})
    state.users[user.userId] = user

    let profile = userProfilePayload(state.users[user.userId])
    check profile["displayname"].getStr("") == "Alice"
    check profile["avatar_url"].getStr("") == "mxc://localhost/avatar"
    check profile["blurhash"].getStr("") == "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"
    check profile["m.tz"].getStr("") == "Europe/Stockholm"
    check profile["com.example.status"].getStr("") == "coding"

    let avatar = profileFieldPayload(state.users[user.userId], "avatar_url")
    check avatar.ok
    check avatar.payload["avatar_url"].getStr("") == "mxc://localhost/avatar"
    check avatar.payload["blurhash"].getStr("") == "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"

    var editable = state.users[user.userId]
    editable.setUserProfileField("m.tz", %*{"m.tz": "UTC"})
    editable.deleteUserProfileField("com.example.status")
    state.users[user.userId] = editable
    check profileFieldPayload(state.users[user.userId], "m.tz").payload["m.tz"].getStr("") == "UTC"
    check not profileFieldPayload(state.users[user.userId], "com.example.status").ok

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.users[user.userId].timezone == "UTC"
    check loaded.users[user.userId].blurhash == "LKO2?U%2Tw=w]~RBVZRi};RPxuwH"

  test "account data is persisted and tombstones sync as deltas":
    let statePath = getTempDir() / "tuwunel-entrypoint-account-data.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    let first = state.setAccountDataLocked(
      "",
      "@alice:localhost",
      "m.direct",
      %*{"@bob:localhost": ["!room:localhost"]}
    )
    check first.streamPos == 1
    let fetched = state.getAccountDataLocked("", "@alice:localhost", "m.direct")
    check fetched.ok
    check fetched.content["@bob:localhost"][0].getStr("") == "!room:localhost"
    state.savePersistentState()

    let loaded = loadPersistentState(statePath)
    let loadedFetched = loaded.accountData[accountDataKey("", "@alice:localhost", "m.direct")]
    check loadedFetched.content["@bob:localhost"][0].getStr("") == "!room:localhost"

    discard state.setAccountDataLocked(
      "!room:localhost",
      "@alice:localhost",
      "m.tag",
      %*{"tags": {"u.work": {"order": 0.5}}}
    )
    check state.accountDataEventsForSync("@alice:localhost", "!room:localhost", 0, true).len == 1
    discard state.setAccountDataLocked("!room:localhost", "@alice:localhost", "m.tag", newJObject())
    let delta = state.accountDataEventsForSync("@alice:localhost", "!room:localhost", 2, false)
    check delta.len == 1
    check delta[0]["type"].getStr("") == "m.tag"
    check delta[0]["content"].kind == JObject
    check delta[0]["content"].len == 0
    check state.accountDataEventsForSync("@alice:localhost", "!room:localhost", 0, true).len == 0

  test "filters are persisted per user and filter id":
    let statePath = getTempDir() / "tuwunel-entrypoint-filters.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.filters[filterKey("@alice:localhost", "abcd")] = %*{
      "event_fields": ["type", "content.body"],
      "room": {"timeline": {"limit": 10}}
    }
    state.savePersistentState()

    let loaded = loadPersistentState(statePath)
    let filter = loaded.filters[filterKey("@alice:localhost", "abcd")]
    check filter["event_fields"][1].getStr("") == "content.body"
    check filter["room"]["timeline"]["limit"].getInt() == 10

  test "tags are backed by m.tag account data and sync deltas":
    let statePath = getTempDir() / "tuwunel-entrypoint-tags.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    let first = state.setRoomTagLocked(
      "!room:localhost",
      "@alice:localhost",
      "u.work",
      %*{"order": 0.25}
    )
    check first.eventType == "m.tag"
    let tags = state.roomTagsContentLocked("!room:localhost", "@alice:localhost")
    check tags["tags"]["u.work"]["order"].getFloat() == 0.25

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    let loadedTag = loaded.accountData[accountDataKey("!room:localhost", "@alice:localhost", "m.tag")]
    check loadedTag.content["tags"]["u.work"]["order"].getFloat() == 0.25

    discard state.deleteRoomTagLocked("!room:localhost", "@alice:localhost", "u.work")
    let delta = state.accountDataEventsForSync("@alice:localhost", "!room:localhost", first.streamPos, false)
    check delta.len == 1
    check delta[0]["type"].getStr("") == "m.tag"
    check delta[0]["content"]["tags"].len == 0

  test "device path parsers cover collection, detail, and bulk delete":
    let collection = devicePathParts("/_matrix/client/v3/devices")
    check collection.ok
    check collection.collection
    let detail = devicePathParts("/_matrix/client/r0/devices/DEV%201")
    check detail.ok
    check not detail.collection
    check detail.deviceId == "DEV 1"
    check deleteDevicesPath("/_matrix/client/v3/delete_devices")

  test "device metadata follows token lifecycle and persists":
    let statePath = getTempDir() / "tuwunel-entrypoint-devices.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    let token = state.addTokenForUser("@alice:localhost", "DEV1", "Alice laptop")
    check token.len > 0
    let key = deviceKey("@alice:localhost", "DEV1")
    check key in state.devices
    check state.devices[key].displayName == "Alice laptop"
    check state.devices[key].lastSeenTs > 0

    discard state.upsertDeviceLocked("@alice:localhost", "DEV2", "Alice phone")
    let payload = state.listDevicesPayloadLocked("@alice:localhost")
    check payload["devices"].len == 2
    check payload["devices"][0]["device_id"].getStr("") == "DEV1"
    check payload["devices"][1]["device_id"].getStr("") == "DEV2"

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.devices[deviceKey("@alice:localhost", "DEV1")].displayName == "Alice laptop"

    state.removeDeviceLocked("@alice:localhost", "DEV1")
    check key notin state.devices
    check token notin state.tokens

  test "client compatibility path parsers cover remaining local route families":
    check isJoinedRoomsPath("/_matrix/client/v3/joined_rooms")
    check isThirdPartyProtocolsPath("/_matrix/client/v3/thirdparty/protocols")
    check isTurnServerPath("/_matrix/client/v3/voip/turnServer")
    check isRtcTransportsPath("/_matrix/client/unstable/org.matrix.msc4143/rtc/transports")
    check isNotificationsPath("/_matrix/client/v3/notifications")
    check isPushersPath("/_matrix/client/v3/pushers")
    check isPushersSetPath("/_matrix/client/v3/pushers/set")
    check isPushRulesPath("/_matrix/client/v3/pushrules/global")
    let pushRule = pushRulePathParts("/_matrix/client/v3/pushrules/global/content/.m.rule.contains_user_name/enabled")
    check pushRule.ok
    check pushRule.scope == "global"
    check pushRule.kind == "content"
    check pushRule.ruleId == ".m.rule.contains_user_name"
    check pushRule.attr == "enabled"
    check isKeysUploadPath("/_matrix/client/v3/keys/upload")
    check isKeysQueryPath("/_matrix/client/v3/keys/query")
    check isKeysClaimPath("/_matrix/client/v3/keys/claim")
    check isKeysChangesPath("/_matrix/client/v3/keys/changes?from=s1&to=s2")
    check isSigningKeyUploadPath("/_matrix/client/v3/keys/device_signing/upload")
    check isSearchPath("/_matrix/client/v3/search")
    check isUserDirectorySearchPath("/_matrix/client/v3/user_directory/search")
    check roomKeysPathKind("/_matrix/client/v3/room_keys/version") == "version"
    check roomKeysPathKind("/_matrix/client/v3/room_keys/keys/%21room%3Alocalhost") == "keys"
    let backupSession = roomKeysPathParts("/_matrix/client/v3/room_keys/keys/%21room%3Alocalhost/session%2Fone")
    check backupSession.ok
    check backupSession.kind == "keys"
    check backupSession.roomId == "!room:localhost"
    check backupSession.sessionId == "session/one"
    check dehydratedDevicePathParts("/_matrix/client/unstable/org.matrix.msc2697.v2/dehydrated_device").ok

    let openId = openIdPathParts("/_matrix/client/v3/user/%40alice%3Alocalhost/openid/request_token")
    check openId.ok
    check openId.userId == "@alice:localhost"

    let toDevice = sendToDevicePathParts("/_matrix/client/v3/sendToDevice/m.room.encrypted/txn1")
    check toDevice.ok
    check toDevice.eventType == "m.room.encrypted"
    check toDevice.txnId == "txn1"

    let alias = directoryAliasPathParts("/_matrix/client/v3/directory/room/%23room%3Alocalhost")
    check alias.ok
    check alias.alias == "#room:localhost"

    let visibility = roomVisibilityPathParts("/_matrix/client/v3/directory/list/room/%21room%3Alocalhost")
    check visibility.ok
    check visibility.roomId == "!room:localhost"

    let reportEvent = reportPathParts("/_matrix/client/v3/rooms/%21room%3Alocalhost/report/%24event")
    check reportEvent.ok
    check reportEvent.roomId == "!room:localhost"
    check reportEvent.eventId == "$event"

    check knockTargetFromPath("/_matrix/client/v3/knock/%21room%3Alocalhost") == "!room:localhost"
    check roomInitialSyncId("/_matrix/client/v3/rooms/%21room%3Alocalhost/initialSync") == "!room:localhost"
    check unstableSummaryRoomId("/_matrix/client/unstable/im.nheko.summary/rooms/%21room%3Alocalhost/summary") == "!room:localhost"
    check relationRoomId("/_matrix/client/v3/rooms/%21room%3Alocalhost/relations/%24event/m.annotation") == "!room:localhost"
    check threadsRoomId("/_matrix/client/v3/rooms/%21room%3Alocalhost/threads") == "!room:localhost"
    check hierarchyRoomId("/_matrix/client/v3/rooms/%21space%3Alocalhost/hierarchy") == "!space:localhost"
    check upgradeRoomId("/_matrix/client/v3/rooms/%21room%3Alocalhost/upgrade") == "!room:localhost"
    check mutualRoomsUserId("/_matrix/client/v3/user/%40bob%3Alocalhost/mutual_rooms") == "@bob:localhost"

  test "client compatibility payloads return Matrix-shaped empty or local state":
    let statePath = getTempDir() / "tuwunel-entrypoint-client-compat-payloads.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/alice",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    discard state.upsertDeviceLocked("@alice:localhost", "DEV1", "Alice laptop")
    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: {"@alice:localhost": "join"}.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.name", "", %*{"name": "Lobby"})
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.join_rules", "", %*{"join_rule": "public"})

    let publicRooms = publicRoomsPayload(state)
    check publicRooms["chunk"].len == 1
    check publicRooms["chunk"][0]["room_id"].getStr("") == "!room:localhost"
    check publicRooms["chunk"][0]["name"].getStr("") == "Lobby"

    let directory = userDirectorySearchPayload(state, %*{"search_term": "ali", "limit": 5})
    check directory["results"].len == 1
    check directory["results"][0]["user_id"].getStr("") == "@alice:localhost"

    check thirdPartyProtocolsPayload().len == 0
    check accountThreepidsPayload()["threepids"].len == 0

    var wellKnownCfg = initFlatConfig()
    check not wellKnownClientPayload(wellKnownCfg).ok
    check not wellKnownSupportPayload(wellKnownCfg).ok
    check not wellKnownServerPayload(wellKnownCfg).ok
    wellKnownCfg["well_known.client"] = newStringValue("https://client.example")
    wellKnownCfg["support_page"] = newStringValue("https://support.example")
    wellKnownCfg["support_role"] = newStringValue("m.role.admin")
    wellKnownCfg["support_email"] = newStringValue("admin@example.test")
    wellKnownCfg["well_known.server"] = newStringValue("matrix.example:443")
    wellKnownCfg["well_known.livekit_url"] = newStringValue("https://rtc.example")
    check wellKnownClientPayload(wellKnownCfg).payload["m.homeserver"]["base_url"].getStr("") == "https://client.example"
    check wellKnownClientPayload(wellKnownCfg).payload["org.matrix.msc4143.rtc_foci"][0]["type"].getStr("") == "livekit"
    check wellKnownClientPayload(wellKnownCfg).payload["org.matrix.msc4143.rtc_foci"][0]["livekit_service_url"].getStr("") == "https://rtc.example"
    check wellKnownSupportPayload(wellKnownCfg).payload["contacts"][0]["email_address"].getStr("") == "admin@example.test"
    check wellKnownServerPayload(wellKnownCfg).payload["m.server"].getStr("") == "matrix.example:443"
    let serverKeys = serverKeysPayload(state)
    check serverKeys.ok
    check serverKeys.payload["verify_keys"].len == 1
    check not ($serverKeys.payload).contains("native-nim-placeholder-signature")

    var turnCfg = initFlatConfig()
    check not turnServerPayload(turnCfg, "localhost", "@alice:localhost").ok
    turnCfg["turn_uris"] = newArrayValue(@[newStringValue("turn:turn.example:3478?transport=udp")])
    turnCfg["turn_username"] = newStringValue("turn-user")
    turnCfg["turn_password"] = newStringValue("turn-pass")
    turnCfg["turn_ttl"] = newIntValue(600)
    let staticTurn = turnServerPayload(turnCfg, "localhost", "@alice:localhost")
    check staticTurn.ok
    check staticTurn.payload["uris"][0].getStr("") == "turn:turn.example:3478?transport=udp"
    check staticTurn.payload["username"].getStr("") == "turn-user"
    check staticTurn.payload["password"].getStr("") == "turn-pass"
    check staticTurn.payload["ttl"].getInt() == 600
    turnCfg["turn_secret"] = newStringValue("secret")
    let secretTurn = turnServerPayload(turnCfg, "localhost", "@alice:localhost")
    check secretTurn.ok
    check secretTurn.payload["username"].getStr("").endsWith(":@alice:localhost")
    check secretTurn.payload["password"].getStr("").len > 0

    var rtcCfg = initFlatConfig()
    rtcCfg["rtc_transports"] = newArrayValue(@[
      newStringValue("{\"type\":\"livekit\",\"livekit_service_url\":\"https://custom.example\"}")
    ])
    check client_rtc.rtcTransportsPayload(rtcCfg)["rtc_transports"][0]["livekit_service_url"].getStr("") == "https://custom.example"

    let keyQuery = keysQueryPayload(state, %*{"device_keys": {"@alice:localhost": ["DEV1"]}})
    check keyQuery["device_keys"]["@alice:localhost"]["DEV1"]["user_id"].getStr("") == "@alice:localhost"

    let initial = roomInitialSyncPayload(state.rooms["!room:localhost"], 10)
    check initial["room_id"].getStr("") == "!room:localhost"
    check initial["state"].len >= 1

    let summary = roomSummaryPayload(state.rooms["!room:localhost"])
    check summary["name"].getStr("") == "Lobby"
    check summary["joined_member_count"].getInt() == 1

  test "room initial sync and summary expose visible local state":
    let statePath = getTempDir() / "tuwunel-entrypoint-room-summary-initial.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.users["@alice:localhost"] = UserProfile(userId: "@alice:localhost", username: "alice", password: "", displayName: "Alice", avatarUrl: "", blurhash: "", timezone: "", profileFields: initTable[string, JsonNode]())
    state.users["@bob:localhost"] = UserProfile(userId: "@bob:localhost", username: "bob", password: "", displayName: "Bob", avatarUrl: "", blurhash: "", timezone: "", profileFields: initTable[string, JsonNode]())
    state.rooms["!room:localhost"] = RoomData(roomId: "!room:localhost", creator: "@alice:localhost", isDirect: false, members: initTable[string, string](), timeline: @[], stateByKey: initTable[string, MatrixEventRecord]())
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.create", "", %*{"creator": "@alice:localhost", "room_version": "11"})
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.name", "", %*{"name": "Lobby"})
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.topic", "", %*{"topic": "General"})
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.canonical_alias", "", aliasContentWith(state.rooms["!room:localhost"], "#lobby:localhost"))
    discard state.setAccountDataLocked("!room:localhost", "@alice:localhost", "m.tag", %*{"tags": {"m.favourite": {}}})

    let privateInitial = state.roomInitialSyncPayload(state.rooms["!room:localhost"], "@alice:localhost", 50)
    check privateInitial["membership"].getStr("") == "join"
    check privateInitial["visibility"].getStr("") == "private"
    check privateInitial["account_data"].len == 1
    check privateInitial["state"].len >= 4
    check state.roomVisibleToUser("!room:localhost", "@alice:localhost")
    check not state.roomVisibleToUser("!room:localhost", "@bob:localhost")

    let privateSummary = roomSummaryPayload(state.rooms["!room:localhost"], "@alice:localhost")
    check privateSummary["name"].getStr("") == "Lobby"
    check privateSummary["topic"].getStr("") == "General"
    check privateSummary["canonical_alias"].getStr("") == "#lobby:localhost"
    check privateSummary["membership"].getStr("") == "join"
    check privateSummary["join_rule"].getStr("") == "invite"
    check privateSummary["room_version"].getStr("") == "11"

    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.join_rules", "", %*{"join_rule": "public"})
    check state.roomVisibleToUser("!room:localhost", "@bob:localhost")
    let publicSummary = roomSummaryPayload(state.rooms["!room:localhost"], "@bob:localhost")
    check publicSummary["join_rule"].getStr("") == "public"
    check publicSummary["membership"].getStr("") == "leave"

  test "space hierarchy and room upgrade use local room graph state":
    let statePath = getTempDir() / "tuwunel-entrypoint-hierarchy-upgrade.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.rooms["!space:localhost"] = RoomData(roomId: "!space:localhost", creator: "@alice:localhost", isDirect: false, members: initTable[string, string](), timeline: @[], stateByKey: initTable[string, MatrixEventRecord]())
    state.rooms["!child:localhost"] = RoomData(roomId: "!child:localhost", creator: "@alice:localhost", isDirect: false, members: initTable[string, string](), timeline: @[], stateByKey: initTable[string, MatrixEventRecord]())
    discard state.appendEventLocked("!space:localhost", "@alice:localhost", "m.room.create", "", %*{"creator": "@alice:localhost", "type": "m.space", "room_version": "10"})
    discard state.appendEventLocked("!space:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!space:localhost", "@alice:localhost", "m.room.name", "", %*{"name": "Space"})
    discard state.appendEventLocked("!space:localhost", "@alice:localhost", "m.space.child", "!child:localhost", %*{"via": ["localhost"], "suggested": true})
    discard state.appendEventLocked("!child:localhost", "@alice:localhost", "m.room.create", "", %*{"creator": "@alice:localhost", "room_version": "10"})
    discard state.appendEventLocked("!child:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!child:localhost", "@alice:localhost", "m.room.name", "", %*{"name": "Child"})
    discard state.appendEventLocked("!child:localhost", "@alice:localhost", "m.room.topic", "", %*{"topic": "Old topic"})

    let hierarchy = state.roomHierarchyPayload("!space:localhost", "@alice:localhost")
    check hierarchy.ok
    check hierarchy.payload["rooms"].len == 2
    check hierarchy.payload["rooms"][0]["room_id"].getStr("") == "!space:localhost"
    check hierarchy.payload["rooms"][0]["children_state"].len == 1
    check hierarchy.payload["rooms"][1]["room_id"].getStr("") == "!child:localhost"

    let forbiddenHierarchy = state.roomHierarchyPayload("!space:localhost", "@bob:localhost")
    check not forbiddenHierarchy.ok
    check forbiddenHierarchy.forbidden

    let upgraded = state.upgradeRoomLocked("!child:localhost", "@alice:localhost", "11")
    check upgraded.ok
    check not upgraded.forbidden
    check upgraded.replacementRoom != "!child:localhost"
    check upgraded.replacementRoom in state.rooms
    check state.rooms[upgraded.replacementRoom].stateByKey[stateKey("m.room.create", "")].content["room_version"].getStr("") == "11"
    check state.rooms[upgraded.replacementRoom].stateByKey[stateKey("m.room.topic", "")].content["topic"].getStr("") == "Old topic"
    check state.rooms["!child:localhost"].stateByKey[stateKey("m.room.tombstone", "")].content["replacement_room"].getStr("") == upgraded.replacementRoom
    check state.rooms[upgraded.replacementRoom].members["@alice:localhost"] == "join"
    check state.upgradeRoomLocked("!child:localhost", "@bob:localhost", "11").forbidden

  test "federation read helpers expose local room user and key state":
    let statePath = getTempDir() / "tuwunel-entrypoint-federation-read.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/alice",
      blurhash: "hash",
      timezone: "Europe/Stockholm",
      profileFields: initTable[string, JsonNode]()
    )
    discard state.upsertDeviceLocked("@alice:localhost", "DEV1", "Alice Mac", "127.0.0.1")
    state.deviceKeys[deviceKey("@alice:localhost", "DEV1")] = DeviceKeyRecord(
      userId: "@alice:localhost",
      deviceId: "DEV1",
      keyData: %*{
        "user_id": "@alice:localhost",
        "device_id": "DEV1",
        "algorithms": ["m.olm.v1.curve25519-aes-sha2"],
        "keys": {"curve25519:DEV1": "curve-key"},
        "signatures": {}
      },
      streamPos: 1
    )
    state.rooms["!fed:localhost"] = RoomData(
      roomId: "!fed:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    let createEv = state.appendEventLocked("!fed:localhost", "@alice:localhost", "m.room.create", "", %*{"room_version": "11"})
    let memberEv = state.appendEventLocked("!fed:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!fed:localhost", "@alice:localhost", "m.room.join_rules", "", %*{"join_rule": "public"})
    discard state.appendEventLocked("!fed:localhost", "@alice:localhost", "m.room.canonical_alias", "", %*{"alias": "#fed:localhost"})
    let firstMessage = state.appendEventLocked("!fed:localhost", "@alice:localhost", "m.room.message", "", %*{"body": "first", "msgtype": "m.text"})
    let secondMessage = state.appendEventLocked("!fed:localhost", "@alice:localhost", "m.room.message", "", %*{"body": "second", "msgtype": "m.text"})

    check federationPathParts("/_matrix/federation/v1/state/%21fed%3Alocalhost") == @["state", "!fed:localhost"]
    check federationPathParts("/_matrix/federation/v1/query/edutypes") == @["query", "edutypes"]
    check federationVersionPayload()["server"]["version"].getStr("") == RustBaselineVersion

    var eduCfg = initFlatConfig()
    eduCfg["allow_incoming_presence"] = newBoolValue(false)
    eduCfg["allow_incoming_read_receipts"] = newBoolValue(true)
    eduCfg["allow_incoming_typing"] = newBoolValue(false)
    let eduTypes = server_edu_types.eduTypesPayload(eduCfg)
    check eduTypes["m.presence"].getBool(true) == false
    check eduTypes["m.receipt"].getBool(false) == true
    check eduTypes["m.typing"].getBool(true) == false

    let eventPayload = state.federationEventPayload(secondMessage.eventId)
    check eventPayload.ok
    check eventPayload.payload["pdu"]["event_id"].getStr("") == secondMessage.eventId
    check eventPayload.payload["pdu"]["content"]["body"].getStr("") == "second"

    let statePayload = state.federationRoomStatePayload("!fed:localhost", secondMessage.eventId, false)
    check statePayload.ok
    check statePayload.eventKnown
    check statePayload.payload["pdus"].len >= 3

    let stateIdsPayload = state.federationRoomStatePayload("!fed:localhost", secondMessage.eventId, true)
    check stateIdsPayload.ok
    check stateIdsPayload.payload["pdu_ids"].len >= 3
    var stateIds = initHashSet[string]()
    for node in stateIdsPayload.payload["pdu_ids"]:
      stateIds.incl(node.getStr(""))
    check createEv.eventId in stateIds

    let backfill = state.federationBackfillPayload("!fed:localhost", @[secondMessage.eventId], 1)
    check backfill.ok
    check backfill.payload["pdus"].len == 1
    check backfill.payload["pdus"][0]["event_id"].getStr("") == firstMessage.eventId

    let missing = state.federationMissingEventsPayload(
      "!fed:localhost",
      %*{"earliest_events": [memberEv.eventId], "latest_events": [secondMessage.eventId], "limit": 10}
    )
    check missing.ok
    var missingIds = initHashSet[string]()
    for node in missing.payload["events"]:
      missingIds.incl(node["event_id"].getStr(""))
    check firstMessage.eventId in missingIds

    let auth = state.federationEventAuthPayload("!fed:localhost", secondMessage.eventId)
    check auth.ok
    check auth.eventKnown
    check auth.payload["auth_chain"].len >= 1

    let directory = state.federationDirectoryPayload("#fed:localhost", "localhost")
    check directory.ok
    check directory.payload["room_id"].getStr("") == "!fed:localhost"
    check directory.payload["servers"][0].getStr("") == "localhost"

    let profile = state.federationProfilePayload("@alice:localhost", "")
    check profile.ok
    check profile.payload["displayname"].getStr("") == "Alice"
    check profile.payload["avatar_url"].getStr("") == "mxc://localhost/alice"

    let devices = state.federationUserDevicesPayload("@alice:localhost")
    check devices.ok
    check devices.payload["devices"].len == 1
    check devices.payload["devices"][0]["device_id"].getStr("") == "DEV1"
    check devices.payload["devices"][0]["keys"]["keys"]["curve25519:DEV1"].getStr("") == "curve-key"

    let keys = keysQueryPayload(state, %*{"device_keys": {"@alice:localhost": ["DEV1"]}})
    check keys["device_keys"]["@alice:localhost"]["DEV1"]["keys"]["curve25519:DEV1"].getStr("") == "curve-key"

  test "federation transaction and membership helpers mutate native room state":
    let statePath = getTempDir() / "tuwunel-entrypoint-federation-membership.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.rooms["!fedjoin:localhost"] = RoomData(
      roomId: "!fedjoin:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    discard state.appendEventLocked("!fedjoin:localhost", "@alice:localhost", "m.room.create", "", %*{"room_version": "11"})
    discard state.appendEventLocked("!fedjoin:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!fedjoin:localhost", "@alice:localhost", "m.room.join_rules", "", %*{"join_rule": "public"})
    discard state.upsertDeviceLocked("@alice:localhost", "ALICE1", "Alice laptop")
    discard state.upsertDeviceLocked("@alice:localhost", "ALICE2", "Alice phone")
    state.typingFederationTimeoutMs = 45000

    let joinTemplate = state.membershipTemplateEvent("!fedjoin:localhost", "@remote:remote.example", "join", "remote.example")
    check joinTemplate.ok
    check joinTemplate.payload["room_version"].getStr("") == "11"
    check joinTemplate.payload["event"]["content"]["membership"].getStr("") == "join"
    check joinTemplate.payload["event"]["state_key"].getStr("") == "@remote:remote.example"

    let joinResult = state.federationAcceptMembershipLocked(
      "!fedjoin:localhost",
      "$remote_join",
      "join",
      %*{
        "pdu": {
          "room_id": "!fedjoin:localhost",
          "sender": "@remote:remote.example",
          "type": "m.room.member",
          "state_key": "@remote:remote.example",
          "origin_server_ts": 1,
          "content": {"membership": "join"}
        }
      }
    )
    check joinResult.ok
    check joinResult.payload["state"].len >= 3
    check joinResult.payload["event"]["event_id"].getStr("") == "$remote_join"
    check state.rooms["!fedjoin:localhost"].members["@remote:remote.example"] == "join"

    let beforeTxnMs = nowMs()
    let txn = state.federationSendTransactionLocked(
      "remote.example",
      "txn1",
      %*{
        "origin": "remote.example",
        "pdus": [
          {
            "event_id": "$remote_msg",
            "room_id": "!fedjoin:localhost",
            "sender": "@remote:remote.example",
            "type": "m.room.message",
            "origin_server_ts": 2,
            "content": {"msgtype": "m.text", "body": "from federation"}
          }
        ],
        "edus": [
          {
            "edu_type": "m.typing",
            "content": {
              "room_id": "!fedjoin:localhost",
              "user_id": "@remote:remote.example",
              "typing": true
            }
          },
          {
            "edu_type": "m.receipt",
            "content": {
              "receipts": {
                "!fedjoin:localhost": {
                  "m.read": {
                    "@remote:remote.example": {
                      "event_ids": ["$remote_msg"],
                      "data": {"ts": 123456, "thread_id": "$thread"}
                    },
                    "@evil:evil.example": {
                      "event_ids": ["$remote_msg"],
                      "data": {"ts": 7}
                    }
                  }
                }
              }
            }
          },
          {
            "edu_type": "m.presence",
            "content": {
              "push": [
                {
                  "user_id": "@remote:remote.example",
                  "presence": "online",
                  "currently_active": false,
                  "last_active_ago": 5000,
                  "status_msg": "available"
                },
                {
                  "user_id": "@evil:evil.example",
                  "presence": "online",
                  "status_msg": "wrong origin"
                }
              ]
            }
          },
          {
            "edu_type": "m.direct_to_device",
            "content": {
              "sender": "@remote:remote.example",
              "type": "m.room.encrypted",
              "message_id": "remote-msg-1",
              "messages": {
                "@alice:localhost": {
                  "ALICE1": {"ciphertext": "direct"},
                  "*": {"ciphertext": "wildcard"}
                }
              }
            }
          },
          {
            "edu_type": "m.direct_to_device",
            "content": {
              "sender": "@evil:evil.example",
              "type": "m.room.encrypted",
              "message_id": "evil-msg-1",
              "messages": {
                "@alice:localhost": {
                  "ALICE1": {"ciphertext": "ignored"}
                }
              }
            }
          },
          {
            "edu_type": "m.signing_key_update",
            "content": {
              "user_id": "@remote:remote.example",
              "master_key": {
                "user_id": "@remote:remote.example",
                "usage": ["master"],
                "keys": {"ed25519:REMOTE_MASTER": "remote-master-key"}
              },
              "self_signing_key": {
                "user_id": "@remote:remote.example",
                "usage": ["self_signing"],
                "keys": {"ed25519:REMOTE_SELF": "remote-self-key"}
              }
            }
          },
          {
            "edu_type": "m.device_list_update",
            "content": {
              "user_id": "@remote:remote.example"
            }
          },
          {
            "edu_type": "m.device_list_update",
            "content": {
              "user_id": "@evil:evil.example"
            }
          }
        ]
      }
    )
    check txn["pdus"]["$remote_msg"].kind == JObject
    check state.rooms["!fedjoin:localhost"].timeline[^1].eventId == "$remote_msg"
    check state.typing.hasKey(typingKey("!fedjoin:localhost", "@remote:remote.example"))
    let remoteTyping = state.typing[typingKey("!fedjoin:localhost", "@remote:remote.example")]
    check remoteTyping.expiresAtMs >= beforeTxnMs + 45000
    check remoteTyping.expiresAtMs <= nowMs() + 45000
    let receiptKeyValue = receiptKey("!fedjoin:localhost", "$remote_msg", "m.read", "@remote:remote.example", "$thread")
    check state.receipts.hasKey(receiptKeyValue)
    check state.receipts[receiptKeyValue].ts == 123456
    check not state.receipts.hasKey(receiptKey("!fedjoin:localhost", "$remote_msg", "m.read", "@evil:evil.example", ""))
    let receiptSync = state.receiptEventsForSync("!fedjoin:localhost", 0, true)
    check receiptSync[0]["content"]["$remote_msg"]["m.read"]["@remote:remote.example"]["thread_id"].getStr("") == "$thread"
    check state.presence["@remote:remote.example"].statusMsg == "available"
    check not state.presence["@remote:remote.example"].currentlyActive
    check nowMs() - state.presence["@remote:remote.example"].lastActiveTs >= 5000
    let remotePresenceEvent = state.presenceEventJson(state.presence["@remote:remote.example"])
    check not remotePresenceEvent["content"]["currently_active"].getBool(true)
    check remotePresenceEvent["content"]["last_active_ago"].getInt(0) >= 5000
    check not state.presence.hasKey("@evil:evil.example")
    let remoteToDeviceLimit = state.streamPos
    let aliceOneToDevice = state.toDeviceEventsForSync("@alice:localhost", "ALICE1", 0, remoteToDeviceLimit)
    check aliceOneToDevice.len == 2
    check aliceOneToDevice[0]["sender"].getStr("") == "@remote:remote.example"
    check aliceOneToDevice[0]["type"].getStr("") == "m.room.encrypted"
    check aliceOneToDevice[0]["content"]["ciphertext"].getStr("") == "direct"
    check aliceOneToDevice[1]["content"]["ciphertext"].getStr("") == "wildcard"
    let aliceTwoToDevice = state.toDeviceEventsForSync("@alice:localhost", "ALICE2", 0, remoteToDeviceLimit)
    check aliceTwoToDevice.len == 1
    check aliceTwoToDevice[0]["content"]["ciphertext"].getStr("") == "wildcard"
    check toDeviceTxnKey("@remote:remote.example", "", "remote-msg-1") in state.toDeviceTxnIds
    check toDeviceTxnKey("@evil:evil.example", "", "evil-msg-1") notin state.toDeviceTxnIds
    check state.crossSigningKeys[crossSigningKey("@remote:remote.example", "master")].keyData["keys"]["ed25519:REMOTE_MASTER"].getStr("") == "remote-master-key"
    check state.crossSigningKeys[crossSigningKey("@remote:remote.example", "self_signing")].keyData["keys"]["ed25519:REMOTE_SELF"].getStr("") == "remote-self-key"
    check state.deviceListUpdates.hasKey("@remote:remote.example")
    check not state.deviceListUpdates.hasKey("@evil:evil.example")
    let fedKeyChanges = state.keyChangesPayloadLocked("s0", encodeSinceToken(state.streamPos))
    check fedKeyChanges["changed"].len == 1
    check fedKeyChanges["changed"][0].getStr("") == "@remote:remote.example"
    state.savePersistentState()
    let loadedFederationState = loadPersistentState(statePath)
    check loadedFederationState.deviceListUpdates.hasKey("@remote:remote.example")

    let queuedBeforeDuplicate = state.toDeviceEvents.len
    discard state.federationSendTransactionLocked(
      "remote.example",
      "txn1-duplicate",
      %*{
        "edus": [
          {
            "edu_type": "m.direct_to_device",
            "content": {
              "sender": "@remote:remote.example",
              "type": "m.room.encrypted",
              "message_id": "remote-msg-1",
              "messages": {
                "@alice:localhost": {
                  "ALICE1": {"ciphertext": "duplicate"}
                }
              }
            }
          }
        ]
      }
    )
    check state.toDeviceEvents.len == queuedBeforeDuplicate

    let leaveResult = state.federationAcceptMembershipLocked(
      "!fedjoin:localhost",
      "$remote_leave",
      "leave",
      %*{
        "pdu": {
          "room_id": "!fedjoin:localhost",
          "sender": "@remote:remote.example",
          "type": "m.room.member",
          "state_key": "@remote:remote.example",
          "content": {"membership": "leave"}
        }
      }
    )
    check leaveResult.ok
    check state.rooms["!fedjoin:localhost"].members["@remote:remote.example"] == "leave"

    let inviteResult = state.federationAcceptMembershipLocked(
      "!fedjoin:localhost",
      "$remote_invite",
      "invite",
      %*{
        "event": {
          "room_id": "!fedjoin:localhost",
          "sender": "@remote:remote.example",
          "type": "m.room.member",
          "state_key": "@localinvite:localhost",
          "content": {"membership": "invite"}
        }
      }
    )
    check inviteResult.ok
    check inviteResult.payload["event"]["event_id"].getStr("") == "$remote_invite"
    check state.rooms["!fedjoin:localhost"].members["@localinvite:localhost"] == "invite"

  test "room directory aliases visibility public rooms and joined rooms persist":
    let statePath = getTempDir() / "tuwunel-entrypoint-directory-state.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.name", "", %*{"name": "Lobby"})

    check state.joinedRoomsForUser("@alice:localhost") == @["!room:localhost"]
    check publicRoomsPayload(state)["chunk"].len == 0

    discard state.appendEventLocked(
      "!room:localhost",
      "@alice:localhost",
      "m.room.canonical_alias",
      "",
      aliasContentWith(state.rooms["!room:localhost"], "#lobby:localhost")
    )
    check state.findRoomByAliasLocked("#lobby:localhost") == "!room:localhost"
    check state.rooms["!room:localhost"].roomAliasesPayload()["aliases"][0].getStr("") == "#lobby:localhost"

    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.join_rules", "", %*{"join_rule": "public"})
    let publicRooms = publicRoomsPayload(state)
    check publicRooms["chunk"].len == 1
    check publicRooms["chunk"][0]["room_id"].getStr("") == "!room:localhost"
    check publicRooms["chunk"][0]["canonical_alias"].getStr("") == "#lobby:localhost"

    let filtered = publicRoomsPayload(state, %*{"filter": {"generic_search_term": "lob"}, "limit": 1})
    check filtered["chunk"].len == 1
    check filtered["total_room_count_estimate"].getInt() == 1
    check publicRoomsPayload(state, %*{"filter": {"generic_search_term": "missing"}})["chunk"].len == 0

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.rooms["!room:localhost"].roomHasAlias("#lobby:localhost")
    check loaded.rooms["!room:localhost"].roomIsPublic()

    discard state.appendEventLocked(
      "!room:localhost",
      "@alice:localhost",
      "m.room.canonical_alias",
      "",
      aliasContentWithout(state.rooms["!room:localhost"], "#lobby:localhost")
    )
    check state.findRoomByAliasLocked("#lobby:localhost") == ""

    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.join_rules", "", %*{"join_rule": "invite"})
    check not state.rooms["!room:localhost"].roomIsPublic()
    check publicRoomsPayload(state)["chunk"].len == 0

  test "room membership actions persist kick ban unban knock and forget":
    let statePath = getTempDir() / "tuwunel-entrypoint-membership-actions.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@bob:localhost", membershipContent("join"))

    let kick = state.setRoomMembershipLocked("!room:localhost", "@alice:localhost", "@bob:localhost", "leave")
    check kick.ok
    check state.rooms["!room:localhost"].members["@bob:localhost"] == "leave"
    check "!room:localhost" notin state.joinedRoomsForUser("@bob:localhost")

    let ban = state.setRoomMembershipLocked("!room:localhost", "@alice:localhost", "@bob:localhost", "ban")
    check ban.ok
    check state.rooms["!room:localhost"].members["@bob:localhost"] == "ban"

    let unban = state.setRoomMembershipLocked("!room:localhost", "@alice:localhost", "@bob:localhost", "leave")
    check unban.ok
    check state.rooms["!room:localhost"].members["@bob:localhost"] == "leave"

    let knock = state.setRoomMembershipLocked("!room:localhost", "@carol:localhost", "@carol:localhost", "knock")
    check knock.ok
    check state.rooms["!room:localhost"].members["@carol:localhost"] == "knock"
    check "!room:localhost" notin state.joinedRoomsForUser("@carol:localhost")

    let activeForget = state.forgetRoomLocked("@alice:localhost", "!room:localhost")
    check not activeForget.ok
    check activeForget.errcode == "M_UNKNOWN"
    check state.rooms["!room:localhost"].members["@alice:localhost"] == "join"

    let leaveBeforeForget = state.setRoomMembershipLocked("!room:localhost", "@alice:localhost", "@alice:localhost", "leave")
    check leaveBeforeForget.ok

    let forgotten = state.forgetRoomLocked("@alice:localhost", "!room:localhost")
    check forgotten.ok
    check state.rooms["!room:localhost"].members["@alice:localhost"] == "leave"
    check "!room:localhost" notin state.joinedRoomsForUser("@alice:localhost")
    check not state.forgetRoomLocked("@alice:localhost", "!missing:localhost").ok

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.rooms["!room:localhost"].members["@alice:localhost"] == "leave"
    check loaded.rooms["!room:localhost"].members["@bob:localhost"] == "leave"
    check loaded.rooms["!room:localhost"].members["@carol:localhost"] == "knock"

  test "mutual rooms payload reflects shared joined membership":
    let statePath = getTempDir() / "tuwunel-entrypoint-mutual-rooms.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.users["@alice:localhost"] = UserProfile(userId: "@alice:localhost", username: "alice", password: "", displayName: "Alice", avatarUrl: "", blurhash: "", timezone: "", profileFields: initTable[string, JsonNode]())
    state.users["@bob:localhost"] = UserProfile(userId: "@bob:localhost", username: "bob", password: "", displayName: "Bob", avatarUrl: "", blurhash: "", timezone: "", profileFields: initTable[string, JsonNode]())
    state.rooms["!shared:localhost"] = RoomData(roomId: "!shared:localhost", creator: "@alice:localhost", isDirect: false, members: initTable[string, string](), timeline: @[], stateByKey: initTable[string, MatrixEventRecord]())
    state.rooms["!alice-only:localhost"] = RoomData(roomId: "!alice-only:localhost", creator: "@alice:localhost", isDirect: false, members: initTable[string, string](), timeline: @[], stateByKey: initTable[string, MatrixEventRecord]())
    discard state.appendEventLocked("!shared:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    discard state.appendEventLocked("!shared:localhost", "@alice:localhost", "m.room.member", "@bob:localhost", membershipContent("join"))
    discard state.appendEventLocked("!alice-only:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))

    let mutual = state.mutualRoomsPayloadLocked("@alice:localhost", "@bob:localhost")
    check mutual["joined"].len == 1
    check mutual["joined"][0].getStr("") == "!shared:localhost"
    check mutual["next_batch_token"].kind == JNull
    check state.mutualRoomsPayloadLocked("@alice:localhost", "@missing:localhost")["joined"].len == 0

  test "user directory search and OpenID token payloads use local state":
    let statePath = getTempDir() / "tuwunel-entrypoint-directory-openid.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.users["@alice:localhost"] = UserProfile(
      userId: "@alice:localhost",
      username: "alice",
      password: "",
      displayName: "Alice",
      avatarUrl: "mxc://localhost/alice",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    state.users["@alicia:localhost"] = UserProfile(
      userId: "@alicia:localhost",
      username: "alicia",
      password: "",
      displayName: "Alicia",
      avatarUrl: "",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )
    state.users["@bob:localhost"] = UserProfile(
      userId: "@bob:localhost",
      username: "bob",
      password: "",
      displayName: "Bob",
      avatarUrl: "",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )

    let limited = userDirectorySearchPayload(state, %*{"search_term": "ali", "limit": 1})
    check limited["limited"].getBool(false)
    check limited["results"].len == 1
    check limited["results"][0]["user_id"].getStr("") == "@alice:localhost"
    check limited["results"][0]["display_name"].getStr("") == "Alice"
    check limited["results"][0]["avatar_url"].getStr("") == "mxc://localhost/alice"

    let bob = userDirectorySearchPayload(state, %*{"search_term": "bob", "limit": 10})
    check not bob["limited"].getBool(true)
    check bob["results"].len == 1
    check bob["results"][0]["user_id"].getStr("") == "@bob:localhost"

    let token = openIdTokenPayload("localhost")
    check token["access_token"].getStr("").startsWith("oidc_")
    check token["token_type"].getStr("") == "Bearer"
    check token["matrix_server_name"].getStr("") == "localhost"
    check token["expires_in"].getInt() == 3600

    let issued = state.createOpenIdTokenPayload("@alice:localhost", "localhost")
    check issued["access_token"].getStr("").startsWith("oidc_")
    let userInfo = state.federationOpenIdUserInfoPayload(issued["access_token"].getStr(""))
    check userInfo.ok
    check userInfo.payload["sub"].getStr("") == "@alice:localhost"
    check state.openIdTokens.len == 1

  test "room and event reports persist native report records":
    let statePath = getTempDir() / "tuwunel-entrypoint-reports.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@alice:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    discard state.appendEventLocked("!room:localhost", "@alice:localhost", "m.room.member", "@alice:localhost", membershipContent("join"))
    let message = state.appendEventLocked("!room:localhost", "@bob:localhost", "m.room.message", "", %*{"body": "spam"})

    let roomReport = state.appendReportLocked("@alice:localhost", "!room:localhost", "", "room spam", 0)
    check roomReport.eventId == ""
    check roomReport.reporterUserId == "@alice:localhost"
    check roomReport.roomId == "!room:localhost"
    check roomReport.reason == "room spam"

    let eventReport = state.appendReportLocked("@alice:localhost", "!room:localhost", message.eventId, "event spam", -100)
    check eventReport.eventId == message.eventId
    check eventReport.score == -100
    check state.roomJoinedForUser("!room:localhost", "@alice:localhost")
    check roomEventIndex(state.rooms["!room:localhost"], message.eventId) >= 0

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.reports.len == 2
    check loaded.reports[0].reason == "room spam"
    check loaded.reports[1].eventId == message.eventId
    check loaded.reports[1].score == -100

  test "E2EE device and one-time keys persist query claim and changes":
    let statePath = getTempDir() / "tuwunel-entrypoint-e2ee-keys.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    discard state.upsertDeviceLocked("@alice:localhost", "DEV1", "Alice laptop")
    let upload = state.uploadE2eeKeysLocked(
      "@alice:localhost",
      "DEV1",
      %*{
        "device_keys": {
          "user_id": "@mallory:localhost",
          "device_id": "WRONG",
          "algorithms": ["m.olm.v1.curve25519-aes-sha2"],
          "keys": {"curve25519:DEV1": "curve-key"},
          "signatures": {}
        },
        "one_time_keys": {
          "signed_curve25519:AAAA": {"key": "otk-a"},
          "signed_curve25519:BBBB": {"key": "otk-b"}
        },
        "fallback_keys": {
          "signed_curve25519:FALL": {"key": "fallback"}
        }
      }
    )
    check upload.ok
    check upload.payload["one_time_key_counts"]["signed_curve25519"].getInt() == 2
    check upload.payload["device_unused_fallback_key_types"][0].getStr("") == "signed_curve25519"

    let queried = keysQueryPayload(state, %*{"device_keys": {"@alice:localhost": ["DEV1"]}})
    check queried["device_keys"]["@alice:localhost"]["DEV1"]["user_id"].getStr("") == "@alice:localhost"
    check queried["device_keys"]["@alice:localhost"]["DEV1"]["device_id"].getStr("") == "DEV1"
    check queried["device_keys"]["@alice:localhost"]["DEV1"]["keys"]["curve25519:DEV1"].getStr("") == "curve-key"

    let changed = state.keyChangesPayloadLocked("s0", encodeSinceToken(state.streamPos))
    check changed["changed"].len == 1
    check changed["changed"][0].getStr("") == "@alice:localhost"

    let firstClaim = state.claimE2eeKeysLocked(%*{
      "one_time_keys": {
        "@alice:localhost": {"DEV1": "signed_curve25519"}
      }
    })
    check firstClaim["one_time_keys"]["@alice:localhost"]["DEV1"].hasKey("signed_curve25519:AAAA")
    check state.oneTimeKeyCountsLocked("@alice:localhost", "DEV1")["signed_curve25519"].getInt() == 1

    discard state.claimE2eeKeysLocked(%*{
      "one_time_keys": {
        "@alice:localhost": {"DEV1": "signed_curve25519"}
      }
    })
    let fallbackClaim = state.claimE2eeKeysLocked(%*{
      "one_time_keys": {
        "@alice:localhost": {"DEV1": "signed_curve25519"}
      }
    })
    check fallbackClaim["one_time_keys"]["@alice:localhost"]["DEV1"].hasKey("signed_curve25519:FALL")
    check state.unusedFallbackKeyTypesLocked("@alice:localhost", "DEV1").len == 0

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.deviceKeys[deviceKey("@alice:localhost", "DEV1")].keyData["keys"]["curve25519:DEV1"].getStr("") == "curve-key"
    check loaded.oneTimeKeys.len == 0
    check loaded.fallbackKeys[oneTimeKeyStoreKey("@alice:localhost", "DEV1", "signed_curve25519", "FALL")].used

  test "cross-signing keys persist query signatures and key changes":
    let statePath = getTempDir() / "tuwunel-entrypoint-cross-signing.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    discard state.upsertDeviceLocked("@alice:localhost", "DEV1", "Alice laptop")
    let deviceUpload = state.uploadE2eeKeysLocked(
      "@alice:localhost",
      "DEV1",
      %*{
        "device_keys": {
          "user_id": "@alice:localhost",
          "device_id": "DEV1",
          "algorithms": ["m.olm.v1.curve25519-aes-sha2"],
          "keys": {"ed25519:DEV1": "device-ed-key"},
          "signatures": {}
        }
      }
    )
    check deviceUpload.ok

    let signingUpload = state.uploadSigningKeysLocked(
      "@alice:localhost",
      %*{
        "master_key": {
          "user_id": "@wrong:localhost",
          "usage": ["master"],
          "keys": {"ed25519:MASTER": "master-key"},
          "signatures": {}
        },
        "self_signing_key": {
          "user_id": "@alice:localhost",
          "usage": ["self_signing"],
          "keys": {"ed25519:SELF": "self-key"},
          "signatures": {}
        },
        "user_signing_key": {
          "user_id": "@alice:localhost",
          "usage": ["user_signing"],
          "keys": {"ed25519:USER": "user-key"},
          "signatures": {}
        }
      }
    )
    check signingUpload.ok

    let queried = keysQueryPayload(state, %*{"device_keys": {"@alice:localhost": []}})
    check queried["master_keys"]["@alice:localhost"]["user_id"].getStr("") == "@alice:localhost"
    check queried["master_keys"]["@alice:localhost"]["keys"]["ed25519:MASTER"].getStr("") == "master-key"
    check queried["self_signing_keys"]["@alice:localhost"]["keys"]["ed25519:SELF"].getStr("") == "self-key"
    check queried["user_signing_keys"]["@alice:localhost"]["keys"]["ed25519:USER"].getStr("") == "user-key"

    let signatureResponse = state.uploadKeySignaturesLocked(%*{
      "@alice:localhost": {
        "ed25519:MASTER": {
          "signatures": {
            "@alice:localhost": {"ed25519:DEV1": "sig-master"}
          }
        },
        "DEV1": {
          "signatures": {
            "@alice:localhost": {"ed25519:SELF": "sig-device"}
          }
        }
      }
    })
    check signatureResponse["failures"].len == 0
    check state.crossSigningKeys[crossSigningKey("@alice:localhost", "master")].keyData["signatures"]["@alice:localhost"]["ed25519:DEV1"].getStr("") == "sig-master"
    check state.deviceKeys[deviceKey("@alice:localhost", "DEV1")].keyData["signatures"]["@alice:localhost"]["ed25519:SELF"].getStr("") == "sig-device"

    let changed = state.keyChangesPayloadLocked("s0", encodeSinceToken(state.streamPos))
    check changed["changed"].len == 1
    check changed["changed"][0].getStr("") == "@alice:localhost"

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.crossSigningKeys[crossSigningKey("@alice:localhost", "master")].keyData["keys"]["ed25519:MASTER"].getStr("") == "master-key"
    check loaded.deviceKeys[deviceKey("@alice:localhost", "DEV1")].keyData["signatures"]["@alice:localhost"]["ed25519:SELF"].getStr("") == "sig-device"

  test "to-device messages persist deliver in sync order and cleanup by token":
    let statePath = getTempDir() / "tuwunel-entrypoint-to-device.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    discard state.upsertDeviceLocked("@bob:localhost", "BOB1", "Bob laptop")
    discard state.upsertDeviceLocked("@bob:localhost", "BOB2", "Bob phone")

    let queued = state.queueToDeviceMessagesLocked(
      "@alice:localhost",
      "ALICE1",
      "m.room.encrypted",
      "txn1",
      %*{
        "messages": {
          "@bob:localhost": {
            "BOB1": {"ciphertext": "direct"},
            "*": {"ciphertext": "wildcard"}
          }
        }
      }
    )
    check queued.ok
    check queued.queuedCount == 3

    let duplicate = state.queueToDeviceMessagesLocked(
      "@alice:localhost",
      "ALICE1",
      "m.room.encrypted",
      "txn1",
      %*{
        "messages": {
          "@bob:localhost": {
            "BOB1": {"ciphertext": "duplicate"}
          }
        }
      }
    )
    check duplicate.ok
    check duplicate.queuedCount == 0

    let syncLimit = state.streamPos
    let bobOne = state.toDeviceEventsForSync("@bob:localhost", "BOB1", 0, syncLimit)
    check bobOne.len == 2
    check bobOne[0]["sender"].getStr("") == "@alice:localhost"
    check bobOne[0]["type"].getStr("") == "m.room.encrypted"
    check bobOne[0]["content"]["ciphertext"].getStr("") == "direct"
    check bobOne[1]["content"]["ciphertext"].getStr("") == "wildcard"

    let bobTwo = state.toDeviceEventsForSync("@bob:localhost", "BOB2", 0, syncLimit)
    check bobTwo.len == 1
    check bobTwo[0]["content"]["ciphertext"].getStr("") == "wildcard"

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.toDeviceEvents.len == 3
    check toDeviceTxnKey("@alice:localhost", "ALICE1", "txn1") in loaded.toDeviceTxnIds

    check state.removeToDeviceEventsLocked("@bob:localhost", "BOB1", syncLimit)
    check state.toDeviceEventsForSync("@bob:localhost", "BOB1", 0, syncLimit).len == 0
    check state.toDeviceEventsForSync("@bob:localhost", "BOB2", 0, syncLimit).len == 1

  test "dehydrated devices persist per user and parse event routes":
    let statePath = getTempDir() / "tuwunel-entrypoint-dehydrated-device.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    let parts = dehydratedDevicePathParts(
      "/_matrix/client/unstable/org.matrix.msc2697.v2/dehydrated_device/DEHYD123/events"
    )
    check parts.ok
    check parts.events
    check parts.deviceId == "DEHYD123"

    let stored = state.putDehydratedDeviceLocked(
      "@alice:localhost",
      %*{
        "device_id": "DEHYD123",
        "device_data": {
          "algorithm": "m.megolm.v1.aes-sha2",
          "account": "opaque"
        }
      }
    )
    check stored.deviceId == "DEHYD123"
    check dehydratedDevicePayload(stored)["device_data"]["account"].getStr("") == "opaque"
    state.savePersistentState()

    let loaded = loadPersistentState(statePath)
    check loaded.dehydratedDevices["@alice:localhost"].deviceId == "DEHYD123"
    check loaded.dehydratedDevices["@alice:localhost"].deviceData["algorithm"].getStr("") == "m.megolm.v1.aes-sha2"

    state.deleteDehydratedDeviceLocked("@alice:localhost")
    check "@alice:localhost" notin state.dehydratedDevices

  test "pushers and push rules persist Matrix client appstate":
    let statePath = getTempDir() / "tuwunel-entrypoint-push-appstate.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    let pusherBody = %*{
      "kind": "http",
      "app_id": "com.example.beenim",
      "pushkey": "push-key-1",
      "app_display_name": "Beenim",
      "device_display_name": "Mac",
      "lang": "en",
      "data": {"url": "https://push.example/notify"}
    }
    let pusherResult = state.setPusherLocked("@alice:localhost", pusherBody)
    check pusherResult.ok
    let pusherPayload = state.listPushersPayload("@alice:localhost")
    check pusherPayload["pushers"].len == 1
    check pusherPayload["pushers"][0]["app_id"].getStr("") == "com.example.beenim"
    check pusherPayload["pushers"][0]["pushkey"].getStr("") == "push-key-1"

    let ruleResult = state.putPushRuleLocked(
      "@alice:localhost",
      "global",
      "content",
      ".m.rule.contains_display_name",
      %*{"pattern": "Alice", "actions": ["notify"]},
    )
    check ruleResult.ok
    let enabledResult = state.updatePushRuleAttrLocked(
      "@alice:localhost",
      "global",
      "content",
      ".m.rule.contains_display_name",
      "enabled",
      %*{"enabled": false},
    )
    check enabledResult.ok
    let actionsResult = state.updatePushRuleAttrLocked(
      "@alice:localhost",
      "global",
      "content",
      ".m.rule.contains_display_name",
      "actions",
      %*{"actions": ["dont_notify"]},
    )
    check actionsResult.ok

    let rule = state.getPushRuleLocked(
      "@alice:localhost",
      "global",
      "content",
      ".m.rule.contains_display_name",
    )
    check rule.isSome
    check not rule.get["enabled"].getBool(true)
    check rule.get["actions"][0].getStr("") == "dont_notify"
    let allRules = state.pushRulesPayload("@alice:localhost")
    check allRules["global"]["content"].len == 1

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.pushers.len == 1
    check loaded.pushRules.len == 1
    check loaded.pushRules[
      pushRuleKey("@alice:localhost", "global", "content", ".m.rule.contains_display_name")
    ]["pattern"].getStr("") == "Alice"

    let deleteResult = state.setPusherLocked("@alice:localhost", %*{
      "kind": nil,
      "app_id": "com.example.beenim",
      "pushkey": "push-key-1"
    })
    check deleteResult.ok
    check state.listPushersPayload("@alice:localhost")["pushers"].len == 0

  test "room key backups persist versions sessions counts and replacement policy":
    let statePath = getTempDir() / "tuwunel-entrypoint-key-backups.json"
    if fileExists(statePath):
      removeFile(statePath)
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)
      if fileExists(statePath):
        removeFile(statePath)

    let versionRecord = state.createBackupVersionLocked(
      "@alice:localhost",
      %*{
        "algorithm": "m.megolm_backup.v1.curve25519-aes-sha2",
        "auth_data": {"public_key": "curve-key"}
      }
    )
    let version = versionRecord.version
    check version == "1"
    check state.latestBackupVersionLocked("@alice:localhost") == version
    check state.backupVersionPayloadLocked(versionRecord)["auth_data"]["public_key"].getStr("") == "curve-key"

    let firstPut = state.putBackupSessionLocked(
      "@alice:localhost",
      version,
      "!room:localhost",
      "sess1",
      %*{
        "first_message_index": 5,
        "forwarded_count": 1,
        "is_verified": false,
        "session_data": {"ciphertext": "old"}
      },
      preferBest = false,
    )
    check firstPut.ok

    let ignoredWorse = state.putBackupSessionLocked(
      "@alice:localhost",
      version,
      "!room:localhost",
      "sess1",
      %*{
        "first_message_index": 8,
        "forwarded_count": 9,
        "is_verified": false,
        "session_data": {"ciphertext": "worse"}
      },
      preferBest = true,
    )
    check ignoredWorse.ok
    check state.getBackupSessionLocked("@alice:localhost", version, "!room:localhost", "sess1").payload["session_data"]["ciphertext"].getStr("") == "old"

    let betterVerified = state.putBackupSessionLocked(
      "@alice:localhost",
      version,
      "!room:localhost",
      "sess1",
      %*{
        "first_message_index": 8,
        "forwarded_count": 9,
        "is_verified": true,
        "session_data": {"ciphertext": "verified"}
      },
      preferBest = true,
    )
    check betterVerified.ok
    check state.getBackupSessionLocked("@alice:localhost", version, "!room:localhost", "sess1").payload["session_data"]["ciphertext"].getStr("") == "verified"

    let secondPut = state.putBackupSessionLocked(
      "@alice:localhost",
      version,
      "!room:localhost",
      "sess2",
      %*{
        "first_message_index": 1,
        "forwarded_count": 0,
        "is_verified": false,
        "session_data": {"ciphertext": "second"}
      },
      preferBest = false,
    )
    check secondPut.ok
    check state.backupMutationPayloadLocked("@alice:localhost", version)["count"].getInt() == 2
    let roomsPayload = state.backupRoomsPayloadLocked("@alice:localhost", version)
    check roomsPayload["rooms"]["!room:localhost"]["sessions"]["sess1"]["session_data"]["ciphertext"].getStr("") == "verified"
    check state.backupRoomSessionsPayloadLocked("@alice:localhost", version, "!room:localhost")["sessions"].len == 2

    state.savePersistentState()
    let loaded = loadPersistentState(statePath)
    check loaded.backupCounter == 1
    check loaded.backupVersions[backupVersionKey("@alice:localhost", version)].authData["public_key"].getStr("") == "curve-key"
    check loaded.backupSessions[backupSessionKey("@alice:localhost", version, "!room:localhost", "sess2")].sessionData["session_data"]["ciphertext"].getStr("") == "second"

    state.deleteBackupSessionsLocked("@alice:localhost", version, "!room:localhost", "sess1")
    check state.backupMutationPayloadLocked("@alice:localhost", version)["count"].getInt() == 1
    state.deleteBackupVersionLocked("@alice:localhost", version)
    check not state.backupVersionExistsLocked("@alice:localhost", version)
    check state.backupKeyCountLocked("@alice:localhost", version) == 0

  test "appservice delivery uses bearer auth instead of query token":
    let delivery = AppserviceDelivery(
      registrationId: "whatsapp",
      registrationUrl: "http://127.0.0.1:29336",
      hsToken: "hs-secret",
      txnId: "t123",
      payload: %*{"events": []},
      attempt: 0
    )

    let url = appserviceDeliveryUrl(delivery)
    let headers = appserviceDeliveryHeaders(delivery)

    check url == "http://127.0.0.1:29336/_matrix/app/v1/transactions/t123"
    check "access_token=" notin url
    check headers.hasKey("Authorization")
    check headers["Authorization"] == "Bearer hs-secret"
    check headers["Content-Type"] == "application/json"

  test "appservice namespace matching covers sender state-key alias and room rules":
    let yaml = """id: bridge
url: http://127.0.0.1:29999
as_token: as-secret
hs_token: hs-secret
sender_localpart: bridgebot
device_management: true
receive_ephemeral: true
namespaces:
  users:
    - regex: ^@bridge_.*:localhost$
      exclusive: true
  aliases:
    - regex: ^#bridge_.*:localhost$
      exclusive: true
  rooms:
    - regex: ^!special:localhost$
      exclusive: false
"""
    let parsed = parseRegistrationYaml(yaml)
    check parsed.isSome
    let reg = parsed.get()
    check reg.deviceManagement
    check reg.receiveEphemeral
    check reg.userRegexes == @["^@bridge_.*:localhost$"]
    check reg.exclusiveUserRegexes == @["^@bridge_.*:localhost$"]
    check reg.aliasRegexes == @["^#bridge_.*:localhost$"]
    check reg.exclusiveAliasRegexes == @["^#bridge_.*:localhost$"]
    check reg.roomRegexes == @["^!special:localhost$"]
    check reg.appserviceUserMatches("@bridge_alice:localhost", "localhost")
    check reg.appserviceUserMatches(resolveAppserviceSender(reg, "localhost"), "localhost")
    check reg.appserviceExclusiveUserMatches("@bridge_alice:localhost", "localhost")
    check not reg.appserviceUserMatches("@bridge_alice:remote", "localhost")

    proc compatEvent(roomId, sender, eventType, stateKeyValue: string; content: JsonNode): MatrixEventRecord =
      MatrixEventRecord(
        streamPos: 1,
        eventId: "$event",
        roomId: roomId,
        sender: sender,
        eventType: eventType,
        stateKey: stateKeyValue,
        redacts: "",
        originServerTs: 1,
        content: content
      )

    var room = RoomData(
      roomId: "!room:localhost",
      creator: "@creator:localhost",
      isDirect: false,
      members: initTable[string, string](),
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    check reg.matchesAppserviceInterest(
      compatEvent("!room:localhost", "@bridge_alice:localhost", "m.room.message", "", %*{}),
      room,
      "localhost"
    )
    check not reg.matchesAppserviceInterest(
      compatEvent("!room:localhost", "@bridge_alice:remote", "m.room.message", "", %*{}),
      room,
      "localhost"
    )
    check reg.matchesAppserviceInterest(
      compatEvent("!room:localhost", "@creator:localhost", "m.room.member", "@bridge_bob:localhost", %*{"membership": "invite"}),
      room,
      "localhost"
    )
    room.stateByKey[stateKey("m.room.canonical_alias", "")] =
      compatEvent("!room:localhost", "@creator:localhost", "m.room.canonical_alias", "", %*{"alias": "#bridge_room:localhost"})
    check reg.matchesAppserviceInterest(
      compatEvent("!room:localhost", "@creator:localhost", "m.room.message", "", %*{}),
      room,
      "localhost"
    )
    room.roomId = "!special:localhost"
    room.stateByKey.clear()
    check reg.matchesAppserviceInterest(
      compatEvent("!special:localhost", "@creator:localhost", "m.room.message", "", %*{}),
      room,
      "localhost"
    )

  test "appservice auth honors masqueraded device_id assertions":
    let statePath = getTempDir() / "tuwunel-entrypoint-appservice-device.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    let reg = AppserviceRegistration(
      id: "bridge",
      url: "http://127.0.0.1:29999",
      asToken: "as-secret",
      hsToken: "hs-secret",
      senderLocalpart: "bridgebot",
      deviceManagement: false,
      userRegexes: @["^@bridge_.*:localhost$"],
      exclusiveUserRegexes: @["^@bridge_.*:localhost$"],
      aliasRegexes: @[],
      exclusiveAliasRegexes: @[],
      roomRegexes: @[],
      exclusiveRoomRegexes: @[],
      receiveEphemeral: false
    )
    state.appserviceByAsToken[reg.asToken] = reg

    var missingDevice = state.getSessionFromToken(
      "as-secret",
      "@bridge_alice:localhost",
      "BRIDGEDEV"
    )
    check not missingDevice.ok
    check missingDevice.errcode == "M_INVALID_PARAM"
    check missingDevice.message == "Unknown device for user."

    state.devices[deviceKey("@bridge_alice:localhost", "BRIDGEDEV")] = DeviceRecord(
      userId: "@bridge_alice:localhost",
      deviceId: "BRIDGEDEV",
      displayName: "Bridge device",
      lastSeenIp: "",
      lastSeenTs: 0
    )

    let masqueraded = state.getSessionFromToken(
      "as-secret",
      "@bridge_alice:localhost",
      "BRIDGEDEV"
    )
    check masqueraded.ok
    check masqueraded.session.isAppservice
    check masqueraded.session.userId == "@bridge_alice:localhost"
    check masqueraded.session.deviceId == "BRIDGEDEV"

    let defaultSender = state.getSessionFromToken("as-secret", "", "")
    check defaultSender.ok
    check defaultSender.session.userId == "@bridgebot:localhost"
    check defaultSender.session.deviceId == "appservice"

    let forbidden = state.getSessionFromToken(
      "as-secret",
      "@not_bridge:localhost",
      ""
    )
    check not forbidden.ok
    check forbidden.errcode == "M_FORBIDDEN"

  test "appservice login resolves body identifier user instead of sender bot":
    let statePath = getTempDir() / "tuwunel-entrypoint-appservice-login.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    let reg = AppserviceRegistration(
      id: "bridge",
      url: "http://127.0.0.1:29999",
      asToken: "as-secret",
      hsToken: "hs-secret",
      senderLocalpart: "bridgebot",
      deviceManagement: false,
      userRegexes: @["^@bridge_.*:localhost$"],
      exclusiveUserRegexes: @["^@bridge_.*:localhost$"],
      aliasRegexes: @[],
      exclusiveAliasRegexes: @[],
      roomRegexes: @[],
      exclusiveRoomRegexes: @[],
      receiveEphemeral: false
    )
    state.appserviceRegs = @[reg]
    state.appserviceByAsToken[reg.asToken] = reg
    state.users["@bridge_alice:localhost"] = UserProfile(
      userId: "@bridge_alice:localhost",
      username: "bridge_alice",
      password: "",
      displayName: "Bridge Alice",
      avatarUrl: "",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )

    let bodyIdentifier = %*{
      "type": "m.login.application_service",
      "identifier": {
        "type": "m.id.user",
        "user": "@bridge_alice:localhost"
      },
      "device_id": "APPDEV"
    }
    let resolved = state.resolveAppserviceLoginLocked(
      "as-secret",
      bodyIdentifier,
      "",
      ""
    )
    check resolved.ok
    check resolved.userId == "@bridge_alice:localhost"

    let bodyLegacyUser = %*{
      "type": "m.login.application_service",
      "user": "bridge_alice"
    }
    check appserviceLoginUserIdFromBody(bodyLegacyUser, "", "localhost") ==
      "@bridge_alice:localhost"

    let fallbackQuery = state.resolveAppserviceLoginLocked(
      "as-secret",
      %*{"type": "m.login.application_service"},
      "@bridge_alice:localhost",
      ""
    )
    check fallbackQuery.ok
    check fallbackQuery.userId == "@bridge_alice:localhost"

    let outsideNamespace = state.resolveAppserviceLoginLocked(
      "as-secret",
      %*{"type": "m.login.application_service", "user": "@alice:localhost"},
      "",
      ""
    )
    check not outsideNamespace.ok
    check outsideNamespace.errcode == "M_EXCLUSIVE"

    let missingUser = state.resolveAppserviceLoginLocked(
      "as-secret",
      %*{"type": "m.login.application_service", "user": "@bridge_missing:localhost"},
      "",
      ""
    )
    check not missingUser.ok
    check missingUser.errcode == "M_INVALID_PARAM"

  test "registration availability enforces appservice namespace ownership":
    let statePath = getTempDir() / "tuwunel-entrypoint-register-availability.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    let reg = AppserviceRegistration(
      id: "bridge",
      url: "http://127.0.0.1:29999",
      asToken: "as-secret",
      hsToken: "hs-secret",
      senderLocalpart: "bridgebot",
      deviceManagement: false,
      userRegexes: @["^@bridge_.*:localhost$"],
      exclusiveUserRegexes: @["^@bridge_.*:localhost$"],
      aliasRegexes: @[],
      exclusiveAliasRegexes: @[],
      roomRegexes: @[],
      exclusiveRoomRegexes: @[],
      receiveEphemeral: false
    )
    state.appserviceRegs = @[reg]
    state.appserviceByAsToken[reg.asToken] = reg
    state.users["@taken:localhost"] = UserProfile(
      userId: "@taken:localhost",
      username: "taken",
      password: "",
      displayName: "Taken",
      avatarUrl: "",
      blurhash: "",
      timezone: "",
      profileFields: initTable[string, JsonNode]()
    )

    let normalized = state.registrationAvailabilityLocked("Alice", "", "")
    check normalized.ok
    check normalized.userId == "@alice:localhost"
    check normalized.username == "alice"

    let invalid = state.registrationAvailabilityLocked("bad name", "", "")
    check not invalid.ok
    check invalid.errcode == "M_INVALID_USERNAME"

    let taken = state.registrationAvailabilityLocked("taken", "", "")
    check not taken.ok
    check taken.errcode == "M_USER_IN_USE"

    let reserved = state.registrationAvailabilityLocked("bridge_alice", "", "")
    check not reserved.ok
    check reserved.errcode == "M_EXCLUSIVE"

    let appserviceOwned = state.registrationAvailabilityLocked("bridge_alice", "as-secret", "")
    check appserviceOwned.ok
    check appserviceOwned.userId == "@bridge_alice:localhost"

    let outsideNamespace = state.registrationAvailabilityLocked("alice", "as-secret", "")
    check not outsideNamespace.ok
    check outsideNamespace.errcode == "M_EXCLUSIVE"

    let unknownToken = state.registrationAvailabilityLocked("bridge_bob", "bad-secret", "")
    check not unknownToken.ok
    check unknownToken.errcode == "M_UNKNOWN_TOKEN"

  test "appservice device management can create masqueraded devices when enabled":
    let statePath = getTempDir() / "tuwunel-entrypoint-appservice-device-mgmt.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    let disabledReg = AppserviceRegistration(
      id: "disabled-bridge",
      url: "http://127.0.0.1:29998",
      asToken: "as-disabled",
      hsToken: "hs-disabled",
      senderLocalpart: "disabledbot",
      deviceManagement: false,
      userRegexes: @["^@bridge_.*:localhost$"],
      exclusiveUserRegexes: @["^@bridge_.*:localhost$"],
      aliasRegexes: @[],
      exclusiveAliasRegexes: @[],
      roomRegexes: @[],
      exclusiveRoomRegexes: @[],
      receiveEphemeral: false
    )
    state.appserviceByAsToken[disabledReg.asToken] = disabledReg
    let disabledSession = state.getSessionFromToken(
      "as-disabled",
      "@bridge_alice:localhost",
      ""
    )
    check disabledSession.ok
    let denied = state.putDeviceMetadataForSessionLocked(
      disabledSession.session,
      "BRIDGEDEV",
      "Bridge device",
      true
    )
    check not denied.ok
    check denied.message == "Device not found."
    check deviceKey("@bridge_alice:localhost", "BRIDGEDEV") notin state.devices

    let enabledReg = AppserviceRegistration(
      id: "enabled-bridge",
      url: "http://127.0.0.1:29999",
      asToken: "as-enabled",
      hsToken: "hs-enabled",
      senderLocalpart: "enabledbot",
      deviceManagement: true,
      userRegexes: @["^@bridge_.*:localhost$"],
      exclusiveUserRegexes: @["^@bridge_.*:localhost$"],
      aliasRegexes: @[],
      exclusiveAliasRegexes: @[],
      roomRegexes: @[],
      exclusiveRoomRegexes: @[],
      receiveEphemeral: false
    )
    state.appserviceByAsToken[enabledReg.asToken] = enabledReg
    let enabledSession = state.getSessionFromToken(
      "as-enabled",
      "@bridge_alice:localhost",
      ""
    )
    check enabledSession.ok
    let created = state.putDeviceMetadataForSessionLocked(
      enabledSession.session,
      "BRIDGEDEV",
      "Bridge device",
      true
    )
    let key = deviceKey("@bridge_alice:localhost", "BRIDGEDEV")
    check created.ok
    check created.created
    check key in state.devices
    check state.devices[key].userId == "@bridge_alice:localhost"
    check state.devices[key].deviceId == "BRIDGEDEV"
    check state.devices[key].displayName == "Bridge device"

    let asserted = state.getSessionFromToken(
      "as-enabled",
      "@bridge_alice:localhost",
      "BRIDGEDEV"
    )
    check asserted.ok
    check asserted.session.deviceId == "BRIDGEDEV"

  test "appservice ephemeral delivery honors receive_ephemeral and room interest":
    let statePath = getTempDir() / "tuwunel-entrypoint-appservice-edus.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    proc compatEvent(roomId, sender, eventType, stateKeyValue: string; content: JsonNode): MatrixEventRecord =
      MatrixEventRecord(
        streamPos: 1,
        eventId: "$alias",
        roomId: roomId,
        sender: sender,
        eventType: eventType,
        stateKey: stateKeyValue,
        redacts: "",
        originServerTs: 1,
        content: content
      )

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@creator:localhost",
      isDirect: false,
      members: {
        "@creator:localhost": "join",
        "@bridge_alice:localhost": "join"
      }.toTable,
      timeline: @[],
      stateByKey: {
        stateKey("m.room.canonical_alias", ""): compatEvent(
          "!room:localhost",
          "@creator:localhost",
          "m.room.canonical_alias",
          "",
          %*{"alias": "#bridge_room:localhost"}
        )
      }.toTable
    )
    state.appserviceRegs = @[
      AppserviceRegistration(
        id: "user-bridge",
        url: "http://127.0.0.1:29340",
        asToken: "as-user",
        hsToken: "hs-user",
        senderLocalpart: "userbridgebot",
        deviceManagement: false,
        userRegexes: @["^@bridge_.*:localhost$"],
        exclusiveUserRegexes: @[],
        aliasRegexes: @[],
        exclusiveAliasRegexes: @[],
        roomRegexes: @[],
        exclusiveRoomRegexes: @[],
        receiveEphemeral: true
      ),
      AppserviceRegistration(
        id: "no-edu",
        url: "http://127.0.0.1:29341",
        asToken: "as-no-edu",
        hsToken: "hs-no-edu",
        senderLocalpart: "noedubot",
        deviceManagement: false,
        userRegexes: @["^@bridge_.*:localhost$"],
        exclusiveUserRegexes: @[],
        aliasRegexes: @[],
        exclusiveAliasRegexes: @[],
        roomRegexes: @[],
        exclusiveRoomRegexes: @[],
        receiveEphemeral: false
      ),
      AppserviceRegistration(
        id: "alias-bridge",
        url: "http://127.0.0.1:29342",
        asToken: "as-alias",
        hsToken: "hs-alias",
        senderLocalpart: "aliasbridgebot",
        deviceManagement: false,
        userRegexes: @[],
        exclusiveUserRegexes: @[],
        aliasRegexes: @["^#bridge_.*:localhost$"],
        exclusiveAliasRegexes: @[],
        roomRegexes: @[],
        exclusiveRoomRegexes: @[],
        receiveEphemeral: true
      ),
      AppserviceRegistration(
        id: "unrelated",
        url: "http://127.0.0.1:29343",
        asToken: "as-unrelated",
        hsToken: "hs-unrelated",
        senderLocalpart: "unrelatedbot",
        deviceManagement: false,
        userRegexes: @["^@other_.*:localhost$"],
        exclusiveUserRegexes: @[],
        aliasRegexes: @[],
        exclusiveAliasRegexes: @[],
        roomRegexes: @[],
        exclusiveRoomRegexes: @[],
        receiveEphemeral: true
      )
    ]

    state.setTypingLocked("!room:localhost", "@creator:localhost", true, 30000)
    check state.pendingDeliveries.len == 2
    check state.pendingDeliveries[0].registrationId == "user-bridge"
    check state.pendingDeliveries[1].registrationId == "alias-bridge"
    let typingPayload = state.pendingDeliveries[0].payload
    check typingPayload["events"].len == 0
    check typingPayload["to_device"].len == 0
    check typingPayload["ephemeral"][0]["type"].getStr("") == "m.typing"
    check typingPayload["ephemeral"][0]["room_id"].getStr("") == "!room:localhost"
    check typingPayload["ephemeral"][0]["content"]["user_ids"][0].getStr("") == "@creator:localhost"

    discard state.setReceiptLocked("!room:localhost", "$event", "m.read", "@creator:localhost", "$thread")
    check state.pendingDeliveries.len == 4
    let receiptPayload = state.pendingDeliveries[2].payload
    let receiptEvent = receiptPayload["ephemeral"][0]
    check receiptEvent["type"].getStr("") == "m.receipt"
    check receiptEvent["room_id"].getStr("") == "!room:localhost"
    check receiptEvent["content"]["$event"]["m.read"]["@creator:localhost"]["thread_id"].getStr("") == "$thread"

  test "appservice delivery payload includes top-level redacts":
    let statePath = getTempDir() / "tuwunel-entrypoint-redact-delivery.json"
    var state = newCompatState(statePath)
    defer:
      deinitLock(state.lock)

    state.rooms["!room:localhost"] = RoomData(
      roomId: "!room:localhost",
      creator: "@creator:localhost",
      isDirect: true,
      members: {
        "@creator:localhost": "join",
        "@whatsapp_46707749265:localhost": "join"
      }.toTable,
      timeline: @[],
      stateByKey: initTable[string, MatrixEventRecord]()
    )
    state.appserviceRegs = @[
      AppserviceRegistration(
        id: "whatsapp",
        url: "http://127.0.0.1:29336",
        asToken: "as-secret",
        hsToken: "hs-secret",
        senderLocalpart: "whatsappbot",
        deviceManagement: false,
        userRegexes: @["^@whatsapp_.*:localhost$"],
        exclusiveUserRegexes: @[],
        aliasRegexes: @[],
        exclusiveAliasRegexes: @[],
        roomRegexes: @[],
        exclusiveRoomRegexes: @[],
        receiveEphemeral: false
      )
    ]

    let ev = state.appendEventLocked(
      "!room:localhost",
      "@creator:localhost",
      "m.room.redaction",
      "",
      %*{"reason": "Removed in Beenim", "redacts": "$target"},
      redacts = "$target"
    )
    state.enqueueEventDeliveries(ev)

    check state.pendingDeliveries.len == 1
    let delivered = state.pendingDeliveries[0].payload["events"][0]
    check delivered["type"].getStr("") == "m.room.redaction"
    check delivered["redacts"].getStr("") == "$target"
