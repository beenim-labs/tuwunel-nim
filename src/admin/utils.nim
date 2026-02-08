## admin/utils — admin module.
##
## Ported from Rust admin/utils.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "admin/utils.rs"
  RustCrate* = "admin"

proc escapeHtml*(s: string): string =
  ## Ported from `escape_html`.
  ""

proc getRoomInfo*(services: Services; roomId: string): (string, uint64, string) =
  ## Ported from `get_room_info`.
  discard

proc parseUserId*(services: Services; userId: string): string =
  ## Ported from `parse_user_id`.
  ""

proc parseLocalUserId*(services: Services; userId: string): string =
  ## Ported from `parse_local_user_id`.
  ""

proc parseActiveLocalUserId*(services: Services; userId: string): string =
  ## Ported from `parse_active_local_user_id`.
  ""
