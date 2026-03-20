import std/[json, unittest]
import main/entrypoint

suite "Appservice ping compatibility":
  test "loaded registration responds to ping with duration":
    let yaml = """id: whatsapp
url: http://127.0.0.1:29336
as_token: beenim-local-bridge-secret
hs_token: beenim-local-bridge-secret
sender_localpart: whatsappbot
rate_limited: false
namespaces:
  users:
    - regex: ^@whatsappbot:localhost$
      exclusive: true
"""
    let response = appservicePingTestResponse(
      @[yaml],
      "whatsapp",
      "beenim-local-bridge-secret"
    )
    check response.status == 200
    check response.payload["duration_ms"].getInt() == 0

  test "missing registration returns not found":
    let yaml = """id: whatsapp
url: http://127.0.0.1:29336
as_token: beenim-local-bridge-secret
hs_token: beenim-local-bridge-secret
sender_localpart: whatsappbot
"""
    let response = appservicePingTestResponse(
      @[yaml],
      "discord",
      "beenim-local-bridge-secret"
    )
    check response.status == 404
    check response.payload["errcode"].getStr() == "M_NOT_FOUND"

  test "wrong token is rejected":
    let yaml = """id: whatsapp
url: http://127.0.0.1:29336
as_token: beenim-local-bridge-secret
hs_token: beenim-local-bridge-secret
sender_localpart: whatsappbot
"""
    let response = appservicePingTestResponse(
      @[yaml],
      "whatsapp",
      "wrong-token"
    )
    check response.status == 401
    check response.payload["errcode"].getStr() == "M_UNKNOWN_TOKEN"
