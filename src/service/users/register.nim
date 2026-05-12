const
  RustPath* = "service/users/register.rs"
  RustCrate* = "service"

import std/options

import service/users/[device, profile]

type
  RegisterRequest* = object
    userId*: string
    username*: string
    password*: string
    origin*: string
    isAppservice*: bool
    isGuest*: bool
    grantFirstUserAdmin*: bool
    displayName*: string
    omitDisplayNameSuffix*: bool
    displayNameSuffix*: string

proc fullRegister*(service: var UserService; request: RegisterRequest): UserResult =
  let userId =
    if request.userId.len > 0:
      request.userId
    elif request.username.len > 0:
      "@" & request.username & ":localhost"
    else:
      ""
  if userId.len == 0:
    return userError("M_INVALID_PARAM", "Either userId or username is required.")

  let created = service.createUser(
    userId,
    username = request.username,
    password = request.password,
    origin = request.origin,
    isGuest = request.isGuest,
    isAppservice = request.isAppservice,
  )
  if not created.ok:
    return created

  var display = request.displayName
  if display.len == 0:
    display = localpart(userId)
  if request.displayNameSuffix.len > 0 and not request.omitDisplayNameSuffix:
    display.add(" " & request.displayNameSuffix)
  service.setDisplayName(userId, some(display))
  okResult()
