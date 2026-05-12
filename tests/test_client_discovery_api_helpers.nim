import std/[json, unittest]

import api/client/capabilities as client_capabilities
import api/client/thirdparty as client_thirdparty
import api/client/utils as client_utils
import api/client/well_known as client_well_known
import core/config_values

suite "Client discovery API helpers":
  test "capabilities expose Rust room version and feature flags":
    var cfg = initFlatConfig()
    cfg["default_room_version"] = newStringValue("12")
    cfg["allow_unstable_room_versions"] = newBoolValue(false)
    cfg["login_via_existing_session"] = newBoolValue(false)
    cfg["login_with_password"] = newBoolValue(false)
    cfg["forget_forced_upon_leave"] = newBoolValue(true)

    let payload = client_capabilities.capabilitiesPayload(cfg, isAdmin = true)
    let caps = payload["capabilities"]
    check caps["m.room_versions"]["default"].getStr == "12"
    check caps["m.room_versions"]["available"].hasKey("12")
    check not caps["m.room_versions"]["available"].hasKey("3")
    check not caps["m.change_password"]["enabled"].getBool
    check not caps["m.get_login_token"]["enabled"].getBool
    check caps["m.3pid_changes"]["enabled"].getBool == false
    check caps["m.profile_fields"]["enabled"].getBool
    check caps["org.matrix.msc4267.forget_forced_upon_leave"]["enabled"].getBool
    check caps["m.account_moderation"]["suspend"].getBool
    check caps["m.account_moderation"]["lock"].getBool

  test "well-known client and support payloads enforce configured Matrix discovery shape":
    var cfg = initFlatConfig()
    check not client_well_known.wellKnownClientPayload(cfg).ok
    check not client_well_known.wellKnownSupportPayload(cfg).ok

    cfg["well_known.client"] = newStringValue("https://client.example")
    cfg["well_known.livekit_url"] = newStringValue("https://rtc.example")
    let clientPayload = client_well_known.wellKnownClientPayload(cfg)
    check clientPayload.ok
    check clientPayload.payload["m.homeserver"]["base_url"].getStr == "https://client.example"
    check clientPayload.payload["org.matrix.msc4143.rtc_foci"][0]["type"].getStr == "livekit"

    cfg["support_role"] = newStringValue("m.role.admin")
    check not client_well_known.wellKnownSupportPayload(cfg).ok
    cfg["support_email"] = newStringValue("admin@example.test")
    cfg["support_page"] = newStringValue("https://support.example")
    let supportPayload = client_well_known.wellKnownSupportPayload(cfg)
    check supportPayload.ok
    check supportPayload.payload["contacts"][0]["role"].getStr == "m.role.admin"
    check supportPayload.payload["contacts"][0]["email_address"].getStr == "admin@example.test"
    check supportPayload.payload["support_page"].getStr == "https://support.example"

  test "third-party protocols and invite policy preserve empty and forbidden Rust paths":
    check client_thirdparty.thirdPartyProtocolsPayload().len == 0
    check client_thirdparty.getProtocolsResponse()["protocols"].len == 0

    check client_utils.inviteCheck(false, false).ok
    let blocked = client_utils.inviteCheck(true, false)
    check not blocked.ok
    check blocked.errcode == "M_FORBIDDEN"
    check blocked.message == "Invites are not allowed on this server."

    var cfg = initFlatConfig()
    cfg["block_non_admin_invites"] = newBoolValue(true)
    check not client_utils.inviteCheck(cfg, senderIsAdmin = false).ok
    check client_utils.inviteCheck(cfg, senderIsAdmin = true).ok
