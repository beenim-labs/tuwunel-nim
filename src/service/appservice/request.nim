const
  RustPath* = "service/appservice/request.rs"
  RustCrate* = "service"

import std/[httpcore, json, strutils, tables]

import service/appservice/registration_info

type
  AppserviceRequest* = object
    skipped*: bool
    registrationId*: string
    httpMethod*: string
    url*: string
    headers*: Table[string, string]
    body*: JsonNode

proc joinUrl(baseUrl, path: string): string =
  let base = baseUrl.strip(trailing = true, chars = {'/'})
  let suffix =
    if path.startsWith("/"):
      path
    else:
      "/" & path
  base & suffix

proc buildAppserviceRequest*(
  registration: AppserviceRegistration;
  path: string;
  body: JsonNode = newJObject();
  httpMethod = "PUT";
): AppserviceRequest =
  if registration.url.len == 0 or registration.url == "null":
    return AppserviceRequest(skipped: true, registrationId: registration.id)

  var headers = initTable[string, string]()
  headers["Authorization"] = "Bearer " & registration.hsToken
  headers["Content-Type"] = "application/json"

  AppserviceRequest(
    skipped: false,
    registrationId: registration.id,
    httpMethod: httpMethod,
    url: joinUrl(registration.url, path),
    headers: headers,
    body: if body.isNil: newJObject() else: body.copy(),
  )

proc appserviceResponsePolicy*(status: HttpCode; validBody = true): tuple[ok: bool, message: string] =
  if ord(status) < 200 or ord(status) >= 300:
    return (false, "unsuccessful appservice HTTP response")
  if not validBody:
    return (false, "invalid appservice response body")
  (true, "")
