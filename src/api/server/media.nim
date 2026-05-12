const
  RustPath* = "api/server/media.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

proc mediaPathParts*(
    federationParts: openArray[string]
): tuple[ok: bool, thumbnail: bool, mediaId: string] =
  if federationParts.len == 3 and federationParts[0] == "media" and
      federationParts[1] in ["download", "thumbnail"] and federationParts[2].len > 0:
    return (true, federationParts[1] == "thumbnail", federationParts[2])
  (false, false, "")
