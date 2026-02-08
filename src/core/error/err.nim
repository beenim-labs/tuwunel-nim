## Error construction helpers.
##
## Ported from Rust core/error/err.rs — provides convenience templates
## for creating errors succinctly. The Rust version uses complex macros
## that integrate with tracing; the Nim version provides simple templates
## that achieve the same API surface.

import mod as errormod

const
  RustPath* = "core/error/err.rs"
  RustCrate* = "core"

template requestError*(kind: ErrorKind; message: string): Error =
  ## Create a Request error with the given ErrorKind and message.
  newRequestError(kind, message)

template forbiddenError*(message: string): Error =
  ## Create a Forbidden request error.
  newRequestError(ekForbidden, message)

template notFoundError*(message: string): Error =
  ## Create a NotFound request error.
  newRequestError(ekNotFound, message, 404)

template unauthorizedError*(message: string): Error =
  ## Create an Unauthorized request error.
  newRequestError(ekUnauthorized, message, 401)

template missingTokenError*(message: string): Error =
  ## Create a MissingToken request error.
  newRequestError(ekMissingToken, message, 401)

template badJsonError*(message: string): Error =
  ## Create a BadJson request error.
  newRequestError(ekBadJson, message, 400)

template databaseError*(message: string): Error =
  ## Create a Database error.
  newDatabaseError(message)

template configError*(directive, message: string): Error =
  ## Create a Config error.
  newConfigError(directive, message)

template federationError*(origin, message: string): Error =
  ## Create a Federation error.
  newFederationError(origin, message)

template genericError*(message: string): Error =
  ## Create a generic error.
  newGenericError(message)
