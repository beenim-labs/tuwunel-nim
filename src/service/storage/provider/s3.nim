## Native S3 storage provider parity wrapper.
##
## The implementation lives in service/storage/provider.nim so local and S3
## providers share the Rust-compatible Provider surface.

const
  RustPath* = "service/storage/provider/s3.rs"
  RustCrate* = "service"

import ../provider

export initS3Provider
