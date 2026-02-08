## Test suite for core error types.
##
## Validates the error type system ported from Rust: error creation,
## HTTP status code derivation, ErrorKind mapping, and message formatting.

import unittest
import ../src/core/error/`mod`

suite "Core Error Types":

  test "Generic error creation":
    let e = newGenericError("something went wrong")
    check e.message() == "something went wrong"
    check e.variant == evErr
    check e.kind() == ekUnknown
    check e.statusCode() == 500

  test "Request error with Forbidden":
    let e = newRequestError(ekForbidden, "access denied", 403)
    check e.message() == "access denied"
    check e.kind() == ekForbidden
    check e.statusCode() == 403
    check e.errcode() == "M_FORBIDDEN"

  test "Request error with NotFound":
    let e = newRequestError(ekNotFound, "room not found", 404)
    check e.isNotFound()
    check e.kind() == ekNotFound
    check e.errcode() == "M_NOT_FOUND"

  test "Database error sanitization":
    let e = newDatabaseError("table corrupted at offset 0x42")
    check e.sanitizedMessage() == "Database error occurred."
    check e.message() == "table corrupted at offset 0x42"
    check e.statusCode() == 500

  test "IO error sanitization":
    let e = newIoError("disk full")
    check e.sanitizedMessage() == "I/O error occurred."
    check e.message() == "disk full"

  test "Config error formatting":
    let e = newConfigError("max_request_size", "value too large")
    check "max_request_size" in e.message()
    check "value too large" in e.message()

  test "Federation error formatting":
    let e = newFederationError("matrix.org", "rate limited")
    check "matrix.org" in e.message()
    check "rate limited" in e.message()

  test "Feature disabled error":
    let e = newFeatureDisabledError("spaces")
    check "spaces" in e.message()
    check e.kind() == ekFeatureDisabled
    check e.statusCode() == 404

  test "Conflict error":
    let e = newConflictError("room alias already exists")
    check e.statusCode() == 409
    check e.variant == evConflict

  test "badRequestCode mapping - LimitExceeded":
    check badRequestCode(ekLimitExceeded) == 429

  test "badRequestCode mapping - TooLarge":
    check badRequestCode(ekTooLarge) == 413

  test "badRequestCode mapping - Forbidden":
    check badRequestCode(ekForbidden) == 403

  test "badRequestCode mapping - Unauthorized":
    check badRequestCode(ekUnauthorized) == 401

  test "badRequestCode mapping - Unknown (default)":
    check badRequestCode(ekUnknown) == 400

  test "isNotFound helper":
    let found = newRequestError(ekUnknown, "exists", 200)
    let notFound = newRequestError(ekNotFound, "missing", 404)
    check not found.isNotFound()
    check notFound.isNotFound()

  test "isPanic helper":
    let normal = newGenericError("normal error")
    check not normal.isPanic()

  test "JSON error body":
    let e = newRequestError(ekForbidden, "not allowed")
    let body = e.toJsonBody()
    check "M_FORBIDDEN" in body
    check "not allowed" in body

  test "Error is catchable exception":
    var caught = false
    try:
      raise newGenericError("test exception")
    except CatchableError as e:
      caught = true
      check "test exception" in e.msg
    check caught
