const
  RustPath* = "service/appservice/registration_info.rs"
  RustCrate* = "service"

import std/strutils

import service/appservice/namespace_regex

type
  AppserviceRegistration* = object
    id*: string
    url*: string
    asToken*: string
    hsToken*: string
    senderLocalpart*: string
    receiveEphemeral*: bool
    deviceManagement*: bool
    aliases*: seq[AppserviceNamespace]
    users*: seq[AppserviceNamespace]
    rooms*: seq[AppserviceNamespace]

  RegistrationInfo* = object
    aliases*: NamespaceRegex
    users*: NamespaceRegex
    rooms*: NamespaceRegex
    sender*: string
    registration*: AppserviceRegistration

proc serverNameFromUserId*(userId: string): string =
  let idx = userId.rfind(':')
  if idx < 0 or idx >= userId.high:
    return ""
  userId[idx + 1 .. ^1]

proc senderUserId*(registration: AppserviceRegistration; serverName: string): string =
  let localpart =
    if registration.senderLocalpart.len > 0:
      registration.senderLocalpart
    else:
      registration.id & "bot"
  "@" & localpart & ":" & serverName

proc newRegistrationInfo*(registration: AppserviceRegistration; serverName: string): RegistrationInfo =
  RegistrationInfo(
    aliases: initNamespaceRegex(false, registration.aliases),
    users: initNamespaceRegex(false, registration.users),
    rooms: initNamespaceRegex(true, registration.rooms),
    sender: registration.senderUserId(serverName),
    registration: registration,
  )

proc isUserMatch*(info: RegistrationInfo; userId: string): bool =
  userId == info.sender or
    (info.users.isMatch(userId) and serverNameFromUserId(userId) == serverNameFromUserId(info.sender))

proc isExclusiveUserMatch*(info: RegistrationInfo; userId: string): bool =
  userId == info.sender or
    (info.users.isExclusiveMatch(userId) and serverNameFromUserId(userId) == serverNameFromUserId(info.sender))
