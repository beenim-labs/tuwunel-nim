const
  RustPath* = "api/client/session/jwt.rs"
  RustCrate* = "api"

import std/strutils

import api/client/session/password

type
  JwtLoginResult* = tuple[ok: bool, userId: string, errcode: string, message: string]

proc jwtLoginPolicy*(enabled: bool): tuple[ok: bool, errcode: string, message: string] =
  if not enabled:
    return (false, "M_UNAUTHORIZED", "JWT login is not enabled.")
  (true, "", "")

proc jwtSubjectUserId*(subject, serverName: string): JwtLoginResult =
  let local = subject.strip().toLowerAscii()
  if local.len == 0:
    return (false, "", "M_INVALID_USERNAME", "JWT subject is not a valid user MXID.")
  let parsed = userIdWithServer(local, serverName)
  if not parsed.ok:
    return (false, "", parsed.errcode, parsed.message)
  (true, parsed.userId, "", "")

proc jwtUnknownUserPolicy*(userExists, registerUser: bool; userId: string): tuple[ok: bool, errcode: string, message: string] =
  if not userExists and not registerUser:
    return (false, "M_NOT_FOUND", "User " & userId & " is not registered on this server.")
  (true, "", "")
