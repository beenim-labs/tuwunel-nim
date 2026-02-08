## uiaa/mod — service module.
##
## Ported from Rust service/uiaa/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/uiaa/mod.rs"
  RustCrate* = "service"

type
  Service* = ref object
    discard

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc create*(self: Service; userId: string; deviceId: DeviceId; uiaainfo: UiaaInfo; jsonBody: CanonicalJsonValue) =
  ## Ported from `create`.
  discard

proc tryAuth*(self: Service; userId: string; deviceId: DeviceId; auth: AuthData; uiaainfo: UiaaInfo): (bool =
  ## Ported from `try_auth`.
  discard

proc setUiaaRequest*(self: Service; userId: string; deviceId: DeviceId; session: string; request: CanonicalJsonValue) =
  ## Ported from `set_uiaa_request`.
  discard

proc getUiaaRequest*(self: Service; userId: string; deviceId: Option[DeviceId]; session: string): Option[CanonicalJsonValue] =
  ## Ported from `get_uiaa_request`.
  none(CanonicalJsonValue)

proc updateUiaaSession*(self: Service; userId: string; deviceId: DeviceId; session: string; uiaainfo: Option[UiaaInfo]) =
  ## Ported from `update_uiaa_session`.
  discard

proc getUiaaSession*(self: Service; userId: string; deviceId: DeviceId; session: string): UiaaInfo =
  ## Ported from `get_uiaa_session`.
  discard
