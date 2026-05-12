const
  RustPath* = "service/sending/dest.rs"
  RustCrate* = "service"

type
  DestinationKind* = enum
    dkFederation,
    dkAppservice,
    dkPush

  Destination* = object
    kind*: DestinationKind
    serverName*: string
    appserviceId*: string
    userId*: string
    pushkey*: string

const Separator* = char(0xFF)

proc federationDestination*(serverName: string): Destination =
  Destination(kind: dkFederation, serverName: serverName)

proc appserviceDestination*(appserviceId: string): Destination =
  Destination(kind: dkAppservice, appserviceId: appserviceId)

proc pushDestination*(userId, pushkey: string): Destination =
  Destination(kind: dkPush, userId: userId, pushkey: pushkey)

proc getPrefix*(dest: Destination): string =
  case dest.kind
  of dkFederation:
    dest.serverName & $Separator
  of dkAppservice:
    "+" & dest.appserviceId & $Separator
  of dkPush:
    "$" & dest.userId & $Separator & dest.pushkey & $Separator

proc destinationId*(dest: Destination): string =
  case dest.kind
  of dkFederation:
    "federation:" & dest.serverName
  of dkAppservice:
    "appservice:" & dest.appserviceId
  of dkPush:
    "push:" & dest.userId & ":" & dest.pushkey
