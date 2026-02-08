## Serde (serialization/deserialization) error integration.
##
## Ported from Rust core/error/serde.rs — provides serialization and
## deserialization error constructors.

import mod as errormod

const
  RustPath* = "core/error/serde.rs"
  RustCrate* = "core"

proc serdeDeError*(message: string): Error =
  ## Create a deserialization error.
  newSerdeDeError(message)

proc serdeSerError*(message: string): Error =
  ## Create a serialization error.
  newSerdeSerError(message)
