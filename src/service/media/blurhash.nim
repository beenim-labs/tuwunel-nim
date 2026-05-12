import std/options

const
  RustPath* = "service/media/blurhash.rs"
  RustCrate* = "service"

type
  BlurhashConfig* = object
    componentsX*: uint32
    componentsY*: uint32
    sizeLimit*: uint64
    enabled*: bool

proc initBlurhashConfig*(
  componentsX = 4'u32;
  componentsY = 3'u32;
  sizeLimit = 0'u64;
  enabled = false;
): BlurhashConfig =
  BlurhashConfig(
    componentsX: componentsX,
    componentsY: componentsY,
    sizeLimit: sizeLimit,
    enabled: enabled,
  )

proc createBlurhash*(
  config: BlurhashConfig;
  file: openArray[byte];
  contentType: Option[string] = none(string);
  fileName: Option[string] = none(string);
): tuple[ok: bool, blurhash: Option[string], message: string] =
  discard contentType
  discard fileName
  if not config.enabled or config.sizeLimit == 0'u64:
    return (true, none(string), "")
  if uint64(file.len) >= config.sizeLimit:
    return (false, none(string), "Image was too large to blurhash")
  (true, none(string), "blurhashing backend is not enabled in the Nim runtime")
