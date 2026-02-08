## sending/mod — service module.
##
## Ported from Rust service/sending/mod.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/sending/mod.rs"
  RustCrate* = "service"

type
  SendingEvent* = enum
    pdu
    rawpduid
    edu
    edubuf
    flush

type
  Service* = ref object
    db*: Data

proc build*(args: crate::Args<'_>) =
  ## Ported from `build`.
  discard

proc worker*(self: Service) =
  ## Ported from `worker`.
  discard

proc interrupt*(self: Service) =
  ## Ported from `interrupt`.
  discard

proc name*(self: Service): string =
  ## Ported from `name`.
  ""

proc unconstrained*(self: Service): bool =
  ## Ported from `unconstrained`.
  false

proc sendPduPush*(self: Service; pduId: RawPduId; user: string; pushkey: string) =
  ## Ported from `send_pdu_push`.
  discard

proc sendPduAppservice*(self: Service; appserviceId: string; pduId: RawPduId) =
  ## Ported from `send_pdu_appservice`.
  discard

proc sendPduRoom*(self: Service; roomId: string; pduId: RawPduId) =
  ## Ported from `send_pdu_room`.
  discard

proc sendEduServer*(self: Service; server: string; serialized: EduBuf) =
  ## Ported from `send_edu_server`.
  discard

proc sendEduRoom*(self: Service; roomId: string; serialized: EduBuf) =
  ## Ported from `send_edu_room`.
  discard

proc flushRoom*(self: Service; roomId: string) =
  ## Ported from `flush_room`.
  discard

proc cleanupEvents*(self: Service; appserviceId: Option[string]; userId: Option[string]; pushKey: Option[string]) =
  ## Ported from `cleanup_events`.
  discard

proc dispatch*(self: Service; msg: Msg) =
  ## Ported from `dispatch`.
  discard

proc shardId*(self: Service; dest: Destination): int =
  ## Ported from `shard_id`.
  0

proc numSenders*(args: crate::Args<'_>): int =
  ## Ported from `num_senders`.
  0
