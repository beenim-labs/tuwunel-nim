const
  RustPath* = "service/registration_tokens/data.rs"
  RustCrate* = "service"

import std/[algorithm, options, strutils, tables, times]

type
  TokenExpires* = object
    maxUses*: Option[uint64]
    maxAgeUnix*: Option[int64]

  DatabaseTokenInfo* = object
    uses*: uint64
    expires*: TokenExpires

  TokenDataResult* = tuple[ok: bool, info: DatabaseTokenInfo, err: string]

  RegistrationTokenData* = object
    tokens*: Table[string, DatabaseTokenInfo]

proc initRegistrationTokenData*(): RegistrationTokenData =
  RegistrationTokenData(tokens: initTable[string, DatabaseTokenInfo]())

proc tokenExpires*(maxUses = none(uint64); maxAgeUnix = none(int64)): TokenExpires =
  TokenExpires(maxUses: maxUses, maxAgeUnix: maxAgeUnix)

proc newDatabaseTokenInfo*(expires: TokenExpires): DatabaseTokenInfo =
  DatabaseTokenInfo(uses: 0'u64, expires: expires)

proc currentUnix(): int64 =
  getTime().toUnix()

proc isValid*(info: DatabaseTokenInfo; nowUnix = currentUnix()): bool =
  if info.expires.maxUses.isSome and info.uses >= info.expires.maxUses.get():
    return false
  if info.expires.maxAgeUnix.isSome and nowUnix > info.expires.maxAgeUnix.get():
    return false
  true

proc `$`*(expires: TokenExpires): string =
  var parts: seq[string] = @[]
  if expires.maxUses.isSome:
    parts.add("after " & $expires.maxUses.get() & " uses")
  if expires.maxAgeUnix.isSome:
    let remaining = expires.maxAgeUnix.get() - currentUnix()
    if remaining < 0:
      return "Expired at " & $expires.maxAgeUnix.get()
    parts.add("in " & $remaining & " seconds (" & $expires.maxAgeUnix.get() & ")")
  if parts.len == 0:
    "Never expires."
  else:
    "Expires " & parts.join(" or ") & "."

proc `$`*(info: DatabaseTokenInfo): string =
  "Token used " & $info.uses & " times. " & $info.expires

proc saveToken*(
  data: var RegistrationTokenData;
  token: string;
  expires: TokenExpires;
): TokenDataResult =
  if token in data.tokens:
    return (false, DatabaseTokenInfo(), "Registration token already exists")
  let info = newDatabaseTokenInfo(expires)
  data.tokens[token] = info
  (true, info, "")

proc revokeToken*(data: var RegistrationTokenData; token: string): TokenDataResult =
  if token notin data.tokens:
    return (false, DatabaseTokenInfo(), "Registration token not found")
  let info = data.tokens[token]
  data.tokens.del(token)
  (true, info, "")

proc checkToken*(
  data: var RegistrationTokenData;
  token: string;
  consume = false;
  nowUnix = currentUnix();
): bool =
  if token notin data.tokens:
    return false

  var info = data.tokens[token]
  if not info.isValid(nowUnix):
    data.tokens.del(token)
    return false

  if consume:
    if info.uses < high(uint64):
      inc info.uses
    if info.isValid(nowUnix):
      data.tokens[token] = info
    else:
      data.tokens.del(token)

  true

proc iterateAndCleanTokens*(
  data: var RegistrationTokenData;
  nowUnix = currentUnix();
): seq[tuple[token: string, info: DatabaseTokenInfo]] =
  result = @[]
  var expired: seq[string] = @[]
  for token, info in data.tokens:
    if info.isValid(nowUnix):
      result.add((token, info))
    else:
      expired.add(token)
  for token in expired:
    data.tokens.del(token)
  result.sort(proc(a, b: tuple[token: string, info: DatabaseTokenInfo]): int = cmp(a.token, b.token))
