## federation/execute — service module.
##
## Ported from Rust service/federation/execute.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "service/federation/execute.rs"
  RustCrate* = "service"

proc validateUrl*(url: Url) =
  ## Ported from `validate_url`.
  discard

proc intoHttpResponse*(dest: string; actual: ActualDest; method: Method; url: Url; response: Response): http::Response<Bytes> =
  ## Ported from `into_http_response`.
  discard

proc handleError*(dest: string; actual: ActualDest; method: Method; url: Url; e: reqwest::Error) =
  ## Ported from `handle_error`.
  discard

proc signRequest*(httpRequest: mut http::Request<seq[u8]>; dest: string) =
  ## Ported from `sign_request`.
  discard
