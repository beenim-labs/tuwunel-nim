## Core error types for tuwunel-nim.
##
## Ported from Rust core/error/mod.rs — provides the unified Error type,
## Matrix error kinds (errcode), HTTP status code derivation, and message
## formatting. This is the foundation that all service and API modules use
## for error handling.

import std/[strformat, strutils, options]

const
  RustPath* = "core/error/mod.rs"
  RustCrate* = "core"

type
  ## Matrix error codes (M_* errcodes from the spec).
  ErrorKind* = enum
    ekUnknown = "M_UNKNOWN"
    ekForbidden = "M_FORBIDDEN"
    ekGuestAccessForbidden = "M_GUEST_ACCESS_FORBIDDEN"
    ekMissingToken = "M_MISSING_TOKEN"
    ekUnknownToken = "M_UNKNOWN_TOKEN"
    ekUnauthorized = "M_UNAUTHORIZED"
    ekBadJson = "M_BAD_JSON"
    ekNotJson = "M_NOT_JSON"
    ekNotFound = "M_NOT_FOUND"
    ekLimitExceeded = "M_LIMIT_EXCEEDED"
    ekTooLarge = "M_TOO_LARGE"
    ekUnrecognized = "M_UNRECOGNIZED"
    ekExclusive = "M_EXCLUSIVE"
    ekUserInUse = "M_USER_IN_USE"
    ekInvalidUsername = "M_INVALID_USERNAME"
    ekRoomInUse = "M_ROOM_IN_USE"
    ekThreepidAuthFailed = "M_THREEPID_AUTH_FAILED"
    ekThreepidDenied = "M_THREEPID_DENIED"
    ekThreepidNotFound = "M_THREEPID_NOT_FOUND"
    ekUserDeactivated = "M_USER_DEACTIVATED"
    ekInvalidParam = "M_INVALID_PARAM"
    ekMissingParam = "M_MISSING_PARAM"
    ekNotYetImplemented = "M_NOT_YET_IMPLEMENTED"
    ekFeatureDisabled = "M_FEATURE_DISABLED"
    ekCannotLeaveServerNoticeRoom = "M_CANNOT_LEAVE_SERVER_NOTICE_ROOM"
    ekResourceLimitExceeded = "M_RESOURCE_LIMIT_EXCEEDED"
    ekWrongRoomKeysVersion = "M_WRONG_ROOM_KEYS_VERSION"
    ekWeakPassword = "M_WEAK_PASSWORD"
    ekIncompatibleRoomVersion = "M_INCOMPATIBLE_ROOM_VERSION"
    ekServerNotTrusted = "M_SERVER_NOT_TRUSTED"
    ekUnsupportedRoomVersion = "M_UNSUPPORTED_ROOM_VERSION"
    ekNotImplemented = "M_NOT_IMPLEMENTED"

  ## Error variant enum — categorizes the error source.
  ErrorVariant* = enum
    evErr              ## Generic / untyped error
    evRequest          ## Matrix client/server API error with ErrorKind
    evDatabase         ## Database layer error
    evIo               ## I/O error
    evJson             ## JSON serialization/deserialization error
    evConfig           ## Configuration error
    evFederation       ## Federation (remote server) error
    evBadServerResponse ## Invalid response from remote server
    evArithmetic       ## Arithmetic overflow / underflow
    evConflict         ## Resource conflict (e.g. room alias exists)
    evFeatureDisabled  ## Feature not available
    evCanonicalJson    ## Canonical JSON error
    evMxid             ## Matrix ID parse error
    evUrlParse         ## URL parse error
    evPanic            ## Panic capture
    evSerdeDe          ## Deserialization error
    evSerdeSer         ## Serialization error
    evLdap             ## LDAP error
    evUiaa             ## UIAA interactive auth response
    evInconsistentRoom ## Inconsistent room state
    evRedaction        ## Redaction error
    evSignatures       ## Signature verification error

  ## The unified Error type.
  Error* = ref object of CatchableError
    variant*: ErrorVariant
    errKind*: ErrorKind
    httpStatus*: int
    detail*: string
    configDirective*: string     ## For Config errors
    federationOrigin*: string    ## For Federation errors
    roomId*: string              ## For InconsistentRoom errors

proc `$`*(e: Error): string =
  e.msg

# ---------------------------------------------------------------------------
# HTTP status code helpers ported from core/error/response.rs
# ---------------------------------------------------------------------------

proc badRequestCode*(kind: ErrorKind): int =
  ## Derive HTTP status code from ErrorKind for BAD_REQUEST-class errors.
  case kind
  of ekLimitExceeded: 429
  of ekTooLarge: 413
  of ekUnrecognized: 405
  of ekNotFound, ekNotImplemented, ekFeatureDisabled: 404
  of ekGuestAccessForbidden, ekThreepidAuthFailed, ekUserDeactivated,
     ekThreepidDenied, ekWrongRoomKeysVersion, ekForbidden: 403
  of ekUnknownToken, ekMissingToken, ekUnauthorized: 401
  else: 400

proc deriveStatusCode(variant: ErrorVariant; kind: ErrorKind; hint: int): int =
  ## Resolve the HTTP status code based on error variant and kind.
  case variant
  of evConflict: 409
  of evRequest:
    if hint == 400:
      badRequestCode(kind)
    else:
      hint
  of evFederation: hint
  of evFeatureDisabled, evCanonicalJson, evJson: badRequestCode(kind)
  of evIo: 500
  of evDatabase: 500
  else:
    if hint != 0: hint
    else: 500

# ---------------------------------------------------------------------------
# Constructors — equivalent to Rust err!() macro patterns
# ---------------------------------------------------------------------------

proc newError*(variant: ErrorVariant; kind: ErrorKind; message: string;
               httpStatus: int = 0): Error =
  ## General Error constructor.
  result = Error(
    variant: variant,
    errKind: kind,
    detail: message,
    httpStatus: deriveStatusCode(variant, kind,
      if httpStatus != 0: httpStatus else: 400),
  )
  result.msg = message

proc newRequestError*(kind: ErrorKind; message: string;
                      httpStatus: int = 400): Error =
  ## Create a Request error (the most common kind).
  newError(evRequest, kind, message, httpStatus)

proc newDatabaseError*(message: string): Error =
  newError(evDatabase, ekUnknown, message, 500)

proc newIoError*(message: string): Error =
  newError(evIo, ekUnknown, message, 500)

proc newJsonError*(message: string): Error =
  newError(evJson, ekNotJson, message, 400)

proc newConfigError*(directive, message: string): Error =
  result = newError(evConfig, ekUnknown,
    fmt"There was a problem with the '{directive}' directive in your configuration: {message}", 500)
  result.configDirective = directive

proc newFederationError*(origin, message: string; httpStatus: int = 500): Error =
  result = newError(evFederation, ekUnknown,
    fmt"Remote server {origin} responded with: {message}", httpStatus)
  result.federationOrigin = origin

proc newBadServerResponse*(message: string): Error =
  newError(evBadServerResponse, ekUnknown, message, 500)

proc newArithmeticError*(message: string): Error =
  newError(evArithmetic, ekUnknown,
    fmt"Arithmetic operation failed: {message}", 500)

proc newConflictError*(message: string): Error =
  newError(evConflict, ekUnknown, message, 409)

proc newFeatureDisabledError*(feature: string): Error =
  newError(evFeatureDisabled, ekFeatureDisabled,
    fmt"Feature '{feature}' is not available on this server.", 404)

proc newInconsistentRoomError*(what: string; roomId: string): Error =
  result = newError(evInconsistentRoom, ekUnknown,
    fmt"{what} in {roomId}", 500)
  result.roomId = roomId

proc newSerdeDeError*(message: string): Error =
  newError(evSerdeDe, ekUnknown, message, 400)

proc newSerdeSerError*(message: string): Error =
  newError(evSerdeSer, ekUnknown, message, 500)

proc newGenericError*(message: string): Error =
  newError(evErr, ekUnknown, message, 500)

# ---------------------------------------------------------------------------
# Methods — ported from Error impl in Rust
# ---------------------------------------------------------------------------

proc statusCode*(e: Error): int =
  ## Returns the HTTP status code for this error.
  e.httpStatus

proc kind*(e: Error): ErrorKind =
  ## Returns the Matrix error code / error kind.
  case e.variant
  of evFeatureDisabled: ekFeatureDisabled
  of evCanonicalJson, evJson: ekNotJson
  of evRequest: e.errKind
  of evFederation: e.errKind
  else: ekUnknown

proc message*(e: Error): string =
  ## Generate the error message string.
  e.detail

proc sanitizedMessage*(e: Error): string =
  ## Sanitizes public-facing errors that can leak sensitive information.
  case e.variant
  of evDatabase: "Database error occurred."
  of evIo: "I/O error occurred."
  else: e.message()

proc isNotFound*(e: Error): bool =
  ## Returns true for "not found" errors.
  e.httpStatus == 404

proc isPanic*(e: Error): bool =
  ## Check if the Error is trafficking a panic.
  e.variant == evPanic

proc errcode*(e: Error): string =
  ## Returns the Matrix errcode string (e.g. "M_FORBIDDEN").
  $e.kind()

proc toJsonBody*(e: Error): string =
  ## Serialize the error to a Matrix-spec JSON error body.
  let ec = e.errcode()
  let msg = e.sanitizedMessage().replace("\"", "\\\"")
  fmt"""{{"errcode":"{ec}","error":"{msg}"}}"""
