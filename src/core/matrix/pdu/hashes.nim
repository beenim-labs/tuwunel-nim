## PDU content hashes.
##
## Ported from Rust core/matrix/pdu/hashes.rs — defines the EventHashes
## type for storing PDU content hashes (SHA-256).

const
  RustPath* = "core/matrix/pdu/hashes.rs"
  RustCrate* = "core"

  ## Maximum length of a URL-safe base64 SHA-256 hash (43 chars).
  Sha256Len* = 43

type
  ## Content hashes of a PDU.
  EventHashes* = object
    sha256*: string  ## SHA-256 hash, URL-safe base64 encoded (max 43 chars)

proc newEventHashes*(sha256: string = ""): EventHashes =
  ## Create new EventHashes.
  EventHashes(sha256: sha256)

proc isEmpty*(h: EventHashes): bool =
  ## Check if hashes are empty.
  h.sha256.len == 0
