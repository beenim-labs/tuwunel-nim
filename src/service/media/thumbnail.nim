const
  RustPath* = "service/media/thumbnail.rs"
  RustCrate* = "service"

type
  ThumbnailMethod* = enum
    tmScale = "scale"
    tmCrop = "crop"

  Dim* = object
    width*: uint32
    height*: uint32
    methodKind*: ThumbnailMethod

proc initDim*(width, height: uint32; methodKind = tmScale): Dim =
  Dim(width: width, height: height, methodKind: methodKind)

proc defaultDim*(): Dim =
  initDim(0'u32, 0'u32, tmScale)

proc crop*(dim: Dim): bool =
  dim.methodKind == tmCrop

proc normalized*(dim: Dim): Dim =
  if dim.width <= 32'u32 and dim.height <= 32'u32:
    initDim(32'u32, 32'u32, tmCrop)
  elif dim.width <= 96'u32 and dim.height <= 96'u32:
    initDim(96'u32, 96'u32, tmCrop)
  elif dim.width <= 320'u32 and dim.height <= 240'u32:
    initDim(320'u32, 240'u32, tmScale)
  elif dim.width <= 640'u32 and dim.height <= 480'u32:
    initDim(640'u32, 480'u32, tmScale)
  elif dim.width <= 800'u32 and dim.height <= 600'u32:
    initDim(800'u32, 600'u32, tmScale)
  else:
    defaultDim()

proc scaled*(requested, image: Dim): tuple[ok: bool, dim: Dim, message: string] =
  if image.width == 0'u32 or image.height == 0'u32:
    return (false, defaultDim(), "image dimensions must be non-zero")

  let width = min(requested.width, image.width)
  let height = min(requested.height, image.height)
  let useWidth =
    uint64(width) * uint64(image.height) <
    uint64(height) * uint64(image.width)

  var x = width
  var y = height
  if useWidth:
    x = uint32((uint64(height) * uint64(image.width)) div uint64(image.height))
  else:
    y = uint32((uint64(width) * uint64(image.height)) div uint64(image.width))

  (true, initDim(x, y, tmScale), "")
