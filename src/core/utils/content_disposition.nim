## Content-Disposition utilities — MSC2702 inline/attachment logic.
##
## Ported from Rust core/utils/content_disposition.rs

import std/[strutils, algorithm]

const
  RustPath* = "core/utils/content_disposition.rs"
  RustCrate* = "core"

type
  ContentDispositionType* = enum
    cdtInline
    cdtAttachment

## As defined by MSC2702 — content types safe to display inline
const ALLOWED_INLINE_CONTENT_TYPES*: array[26, string] = [
  "application/json",
  "application/ld+json",
  "audio/aac",
  "audio/flac",
  "audio/mp4",
  "audio/mpeg",
  "audio/ogg",
  "audio/wav",
  "audio/wave",
  "audio/webm",
  "audio/x-flac",
  "audio/x-pn-wav",
  "audio/x-wav",
  "image/apng",
  "image/avif",
  "image/gif",
  "image/jpeg",
  "image/png",
  "image/webp",
  "text/css",
  "text/csv",
  "text/plain",
  "video/mp4",
  "video/ogg",
  "video/quicktime",
  "video/webm",
]

proc contentDispositionType*(contentType: string): ContentDispositionType =
  ## Returns Inline or Attachment based on whether the content type is
  ## in the MSC2702 safe-inline list.
  if contentType.len == 0:
    return cdtAttachment
  # Strip parameters (e.g., "text/plain; charset=utf-8" → "text/plain")
  let ct = contentType.split(';')[0].strip().toLowerAscii()
  if ALLOWED_INLINE_CONTENT_TYPES.binarySearch(ct) >= 0:
    cdtInline
  else:
    cdtAttachment

proc sanitiseFilename*(filename: string): string =
  ## Sanitise a filename for Content-Disposition.
  ## Removes path separators, control characters, and common dangerous patterns.
  if filename.len == 0:
    return ""
  result = ""
  for ch in filename:
    case ch
    of '/', '\\', '\x00'..'\x1F', '\x7F':
      discard  # skip control chars and path separators
    of '<', '>', ':', '"', '|', '?', '*':
      discard  # skip Windows-unsafe chars
    else:
      result.add ch
  # Remove leading dots (hidden files) and trailing dots/spaces (Windows)
  while result.len > 0 and result[0] == '.':
    result = result[1..^1]
  while result.len > 0 and result[^1] in {'.', ' '}:
    result = result[0..^2]

proc makeContentDisposition*(
  contentType: string;
  filename: string = "";
): tuple[dispositionType: ContentDispositionType; filename: string] =
  ## Create a Content-Disposition header value.
  let dt = contentDispositionType(contentType)
  let fn = if filename.len > 0: sanitiseFilename(filename) else: ""
  (dt, fn)
