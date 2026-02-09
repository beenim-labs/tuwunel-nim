import std/[algorithm, options, parseutils, sequtils, strutils, tables]
export tables

type
  ConfigValueKind* = enum
    cvNull
    cvBool
    cvInt
    cvFloat
    cvString
    cvArray

  ConfigValue* = object
    case kind*: ConfigValueKind
    of cvBool:
      b*: bool
    of cvInt:
      i*: int64
    of cvFloat:
      f*: float64
    of cvString:
      s*: string
    of cvArray:
      items*: seq[ConfigValue]
    else:
      discard

  FlatConfig* = Table[string, ConfigValue]

proc newNullValue*(): ConfigValue =
  ConfigValue(kind: cvNull)

proc newBoolValue*(v: bool): ConfigValue =
  ConfigValue(kind: cvBool, b: v)

proc newIntValue*(v: int64): ConfigValue =
  ConfigValue(kind: cvInt, i: v)

proc newFloatValue*(v: float64): ConfigValue =
  ConfigValue(kind: cvFloat, f: v)

proc newStringValue*(v: string): ConfigValue =
  ConfigValue(kind: cvString, s: v)

proc newArrayValue*(v: seq[ConfigValue]): ConfigValue =
  ConfigValue(kind: cvArray, items: v)

proc initFlatConfig*(): FlatConfig =
  initTable[string, ConfigValue]()

proc `$`*(v: ConfigValue): string =
  case v.kind
  of cvNull:
    "null"
  of cvBool:
    if v.b: "true" else: "false"
  of cvInt:
    $v.i
  of cvFloat:
    $v.f
  of cvString:
    "\"" & v.s.replace("\\", "\\\\").replace("\"", "\\\"") & "\""
  of cvArray:
    "[" & v.items.mapIt($it).join(", ") & "]"

proc renderFlatConfig*(cfg: FlatConfig): string =
  var keys: seq[string] = @[]
  for k in cfg.keys:
    keys.add(k)
  keys.sort(system.cmp[string])

  result = ""
  for i, k in keys:
    if i > 0:
      result.add("\n")
    result.add(k & "=" & $cfg[k])

proc mergeFlatConfig*(dst: var FlatConfig; src: FlatConfig) =
  for k, v in src:
    dst[k] = v

proc setValue*(cfg: var FlatConfig; key: string; value: ConfigValue) =
  cfg[key] = value

proc containsKey*(cfg: FlatConfig; key: string): bool =
  key in cfg

proc getValue*(cfg: FlatConfig; key: string): Option[ConfigValue] =
  if key in cfg:
    return some(cfg[key])
  none(ConfigValue)

proc appendStringValue*(cfg: var FlatConfig; key, value: string) =
  let added = newStringValue(value)
  if key notin cfg:
    cfg[key] = newArrayValue(@[added])
    return

  let existing = cfg[key]
  if existing.kind == cvArray:
    var arr = existing.items
    arr.add(added)
    cfg[key] = newArrayValue(arr)
  else:
    cfg[key] = newArrayValue(@[existing, added])

proc parseQuotedString(raw: string): tuple[ok: bool, err: string, value: string] =
  if raw.len < 2:
    return (false, "Invalid quoted string", "")

  let quote = raw[0]
  if raw[^1] != quote:
    return (false, "Unterminated quoted string", "")

  let inner = raw[1 .. ^2]
  if quote == '\'':
    return (true, "", inner)

  var buffer = newStringOfCap(inner.len)
  var i = 0
  while i < inner.len:
    let c = inner[i]
    if c != '\\':
      buffer.add(c)
      inc i
      continue

    if i + 1 >= inner.len:
      return (false, "Invalid escape sequence", "")

    let n = inner[i + 1]
    case n
    of '\\':
      buffer.add('\\')
    of '"':
      buffer.add('"')
    of 'n':
      buffer.add('\n')
    of 'r':
      buffer.add('\r')
    of 't':
      buffer.add('\t')
    else:
      buffer.add(n)
    i += 2

  (true, "", buffer)

proc splitArrayItems(raw: string): seq[string] =
  result = @[]
  var cur = newStringOfCap(raw.len)
  var depth = 0
  var inSingle = false
  var inDouble = false
  var escaped = false

  for ch in raw:
    if escaped:
      cur.add(ch)
      escaped = false
      continue

    if ch == '\\' and inDouble:
      cur.add(ch)
      escaped = true
      continue

    if ch == '\'' and not inDouble:
      inSingle = not inSingle
      cur.add(ch)
      continue

    if ch == '"' and not inSingle:
      inDouble = not inDouble
      cur.add(ch)
      continue

    if not inSingle and not inDouble:
      if ch == '[':
        inc depth
      elif ch == ']':
        dec depth
      elif ch == ',' and depth == 0:
        result.add(cur.strip())
        cur.setLen(0)
        continue

    cur.add(ch)

  if cur.len > 0 or raw.strip().len == 0:
    result.add(cur.strip())

proc parseTomlValue*(raw: string): tuple[ok: bool, err: string, value: ConfigValue] =
  let text = raw.strip()
  if text.len == 0:
    return (false, "TOML value cannot be empty", newNullValue())

  if (text[0] == '"' and text[^1] == '"') or (text[0] == '\'' and text[^1] == '\''):
    let parsed = parseQuotedString(text)
    if not parsed.ok:
      return (false, parsed.err, newNullValue())
    return (true, "", newStringValue(parsed.value))

  let lower = text.toLowerAscii()
  if lower == "null":
    return (true, "", newNullValue())
  if lower == "true":
    return (true, "", newBoolValue(true))
  if lower == "false":
    return (true, "", newBoolValue(false))

  if text[0] == '[' and text[^1] == ']':
    let inner = text[1 .. ^2].strip()
    if inner.len == 0:
      return (true, "", newArrayValue(@[]))

    var vals: seq[ConfigValue] = @[]
    for item in splitArrayItems(inner):
      let parsed = parseTomlValue(item)
      if not parsed.ok:
        return (false, parsed.err, newNullValue())
      vals.add(parsed.value)
    return (true, "", newArrayValue(vals))

  var i64v: BiggestInt = 0
  if parseBiggestInt(text, i64v) == text.len:
    return (true, "", newIntValue(int64(i64v)))

  var f64v = 0.0
  if parseFloat(text, f64v) == text.len:
    return (true, "", newFloatValue(f64v))

  (true, "", newStringValue(text))

proc valueFromEnvLiteral*(raw: string): ConfigValue =
  let parsed = parseTomlValue(raw)
  if parsed.ok:
    return parsed.value
  newStringValue(raw)

proc stripInlineComment(line: string): string =
  var inSingle = false
  var inDouble = false
  var escaped = false

  for i, ch in line:
    if escaped:
      escaped = false
      continue

    if ch == '\\' and inDouble:
      escaped = true
      continue

    if ch == '\'' and not inDouble:
      inSingle = not inSingle
      continue

    if ch == '"' and not inSingle:
      inDouble = not inDouble
      continue

    if ch == '#' and not inSingle and not inDouble:
      return line[0 ..< i]

  line

proc parseTomlDocument*(content: string; source = "<inline>"): tuple[
    ok: bool, err: string, data: FlatConfig] =
  result = (true, "", initFlatConfig())
  var section = ""

  for lineno, rawLine in pairs(content.splitLines()):
    let line = stripInlineComment(rawLine).strip()
    if line.len == 0:
      continue

    if line.startsWith("[") and line.endsWith("]"):
      section = line[1 .. ^2].strip()
      continue

    let sep = line.find('=')
    if sep < 0:
      return (
        false,
        source & ":" & $(lineno + 1) & ": expected key=value entry",
        initFlatConfig(),
      )

    let key = line[0 ..< sep].strip()
    if key.len == 0:
      return (
        false,
        source & ":" & $(lineno + 1) & ": missing key before '='",
        initFlatConfig(),
      )

    let valueRaw = if sep + 1 <= line.high: line[sep + 1 .. ^1].strip() else: ""
    let parsed = parseTomlValue(valueRaw)
    if not parsed.ok:
      return (
        false,
        source & ":" & $(lineno + 1) & ": " & parsed.err,
        initFlatConfig(),
      )

    let fullKey = if section.len > 0: section & "." & key else: key
    result.data[fullKey] = parsed.value
