## Error response helpers — HTTP status code mapping.
##
## Ported from Rust core/error/response.rs — provides the mapping from
## ErrorKind to HTTP status codes and helpers for generating Matrix-spec
## JSON error response bodies.

import std/[json, strformat]
import mod as errormod

const
  RustPath* = "core/error/response.rs"
  RustCrate* = "core"

proc errorBodyJson*(kind: ErrorKind; message: string): JsonNode =
  ## Create a Matrix-spec error body JSON object.
  %*{"errcode": $kind, "error": message}

proc errorResponseBody*(e: Error): JsonNode =
  ## Convert an Error into a Matrix-spec error response body.
  errorBodyJson(e.kind(), e.sanitizedMessage())

proc statusCodeForKind*(kind: ErrorKind; hint: int = 400): int =
  ## Derive HTTP status code from an ErrorKind with an optional hint.
  if hint == 400:
    badRequestCode(kind)
  else:
    hint

proc ioErrorCode*(errorKind: string): int =
  ## Map I/O error kind string to HTTP status code.
  ## (Nim doesn't have typed I/O error kinds like Rust, so we use strings.)
  case errorKind
  of "InvalidInput": 400
  of "PermissionDenied": 403
  of "NotFound": 404
  of "TimedOut": 504
  of "FileTooLarge": 413
  of "StorageFull": 507
  of "Interrupted": 503
  else: 500
