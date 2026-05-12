const
  RustPath* = "service/registration_tokens/mod.rs"
  RustCrate* = "service"
  RandomTokenLength* = 16

import std/[algorithm, random, sets, times]

import service/registration_tokens/data

export data

type
  ValidTokenSourceKind* = enum
    vtsConfigFile
    vtsDatabase

  ValidTokenSource* = object
    kind*: ValidTokenSourceKind
    info*: DatabaseTokenInfo

  ValidToken* = object
    token*: string
    source*: ValidTokenSource

  RegistrationTokenResult* = tuple[ok: bool, token: string, info: DatabaseTokenInfo, err: string]

  RegistrationTokenService* = object
    db*: RegistrationTokenData
    configTokens*: HashSet[string]

var randomized = false

proc ensureRandomized() =
  if not randomized:
    randomize()
    randomized = true

proc randomTokenString(length: int): string =
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  ensureRandomized()
  result = newString(max(length, 0))
  for idx in 0 ..< result.len:
    result[idx] = alphabet[rand(alphabet.high)]

proc initRegistrationTokenService*(configTokens: openArray[string] = []): RegistrationTokenService =
  result = RegistrationTokenService(
    db: initRegistrationTokenData(),
    configTokens: initHashSet[string](),
  )
  for token in configTokens:
    if token.len > 0:
      result.configTokens.incl(token)

proc sourceConfig*(): ValidTokenSource =
  ValidTokenSource(kind: vtsConfigFile)

proc sourceDatabase*(info: DatabaseTokenInfo): ValidTokenSource =
  ValidTokenSource(kind: vtsDatabase, info: info)

proc `$`*(source: ValidTokenSource): string =
  case source.kind
  of vtsConfigFile:
    "Token defined in config."
  of vtsDatabase:
    $source.info

proc `$`*(token: ValidToken): string =
  "`" & token.token & "` --- " & $token.source

proc issueToken*(
  service: var RegistrationTokenService;
  expires: TokenExpires;
): RegistrationTokenResult =
  let token = randomTokenString(RandomTokenLength)
  let saved = service.db.saveToken(token, expires)
  if not saved.ok:
    return (false, "", DatabaseTokenInfo(), saved.err)
  (true, token, saved.info, "")

proc isTokenValid*(
  service: var RegistrationTokenService;
  token: string;
  nowUnix = getTime().toUnix();
): bool =
  token in service.configTokens or service.db.checkToken(token, consume = false, nowUnix = nowUnix)

proc tryConsume*(
  service: var RegistrationTokenService;
  token: string;
  nowUnix = getTime().toUnix();
): bool =
  token in service.configTokens or service.db.checkToken(token, consume = true, nowUnix = nowUnix)

proc revokeToken*(
  service: var RegistrationTokenService;
  token: string;
): RegistrationTokenResult =
  if token in service.configTokens:
    return (
      false,
      "",
      DatabaseTokenInfo(),
      "The token set in the config file cannot be revoked. Edit the config file to change it.",
    )
  let revoked = service.db.revokeToken(token)
  if not revoked.ok:
    return (false, "", DatabaseTokenInfo(), revoked.err)
  (true, token, revoked.info, "")

proc iterateTokens*(
  service: var RegistrationTokenService;
  nowUnix = getTime().toUnix();
): seq[ValidToken] =
  result = @[]
  var configTokens: seq[string] = @[]
  for token in service.configTokens:
    configTokens.add(token)
  configTokens.sort(system.cmp[string])
  for token in configTokens:
    result.add(ValidToken(token: token, source: sourceConfig()))

  for entry in service.db.iterateAndCleanTokens(nowUnix):
    result.add(ValidToken(token: entry.token, source: sourceDatabase(entry.info)))

proc isEnabled*(
  service: var RegistrationTokenService;
  nowUnix = getTime().toUnix();
): bool =
  service.iterateTokens(nowUnix).len > 0
