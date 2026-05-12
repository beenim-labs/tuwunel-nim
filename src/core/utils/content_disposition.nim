import std/[algorithm, strutils]

const
  RustPath* = "core/utils/content_disposition.rs"
  RustCrate* = "core"

  AllowedInlineContentTypes* = [
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

proc baseContentType*(contentType: string): string =
  contentType.split(';', 1)[0].strip().toLowerAscii()

proc contentDispositionType*(contentType: string): string =
  let base = baseContentType(contentType)
  if base.len > 0 and binarySearch(AllowedInlineContentTypes, base) >= 0:
    "inline"
  else:
    "attachment"

proc sanitiseFilename*(filename: string): string =
  result = ""
  for ch in filename:
    case ch
    of '\0'..'\31', '\127', '"', '\\', '/', ':', ';':
      result.add('_')
    else:
      result.add(ch)

proc contentDispositionHeader*(
    contentType: string;
    filename = "";
    requestedFilename = ""
): string =
  result = contentDispositionType(contentType)
  let selected = if requestedFilename.len > 0: requestedFilename else: filename
  if selected.len > 0:
    result.add("; filename=\"")
    result.add(sanitiseFilename(selected))
    result.add("\"")
