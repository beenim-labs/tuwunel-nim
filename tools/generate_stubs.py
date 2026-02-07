#!/usr/bin/env python3
"""Generate Nim stubs and constants from extracted parity inventory."""

from __future__ import annotations

import ast
import json
import re
from collections import Counter
from pathlib import Path
from typing import Dict, List, Tuple

ROOT = Path(__file__).resolve().parents[1]
PARITY = ROOT / "docs" / "parity"
SRC = ROOT / "src"

CODE_TOKEN_RE = re.compile(r"\b(proc|func|method|iterator|template|macro|type|converter)\b")
PLACEHOLDER_HINT_RE = re.compile(r"\b(placeholder|not implemented|todo|stub)\b", re.IGNORECASE)
AUTH_HINT_RE = re.compile(r"\b(auth|token|forbidden|unauthorized)\b", re.IGNORECASE)
ERROR_HINT_RE = re.compile(r"\b(error|errcode|status|matrixerror)\b", re.IGNORECASE)

PUBLIC_CLIENT_ROUTE_NAMES = {
    "appservice_ping",
    "check_registration_token_validity",
    "get_login_types_route",
    "get_register_available_route",
    "get_supported_versions_route",
    "login_route",
    "login_token_route",
    "refresh_token_route",
    "register_route",
    "request_3pid_management_token_via_email_route",
    "request_3pid_management_token_via_msisdn_route",
    "sso_callback_route",
    "sso_login_route",
    "sso_login_with_provider_route",
    "third_party_route",
}

DEFAULT_RUNTIME_EXTRA_IMPLEMENTED_ROUTE_NAMES = {
    "/.well-known/matrix/server",
    "/_matrix/key/v2/server",
    "/_matrix/key/v2/server/{key_id}",
    "/_tuwunel/server_version",
    "get_server_version_route",
    "logout_all_route",
    "logout_route",
    "well_known_client",
    "well_known_server",
    "whoami_route",
}

DEFAULT_RUNTIME_SERVER_FALLBACK_ROUTE_NAMES = set()

DEFAULT_RUNTIME_MANUAL_FALLBACK_ROUTE_NAMES = {
}

DEFAULT_RUNTIME_CLIENT_FALLBACK_ROUTE_NAMES = {
}

PUBLIC_MANUAL_ROUTE_TOKENS = [
    ".well-known",
    "download",
    "thumbnail",
    "preview_url",
    "versions",
    "publicrooms",
]

NIM_RESERVED_WORDS = {
    "addr",
    "and",
    "as",
    "asm",
    "bind",
    "block",
    "break",
    "case",
    "cast",
    "concept",
    "const",
    "continue",
    "converter",
    "defer",
    "discard",
    "distinct",
    "div",
    "do",
    "elif",
    "else",
    "end",
    "enum",
    "except",
    "export",
    "finally",
    "for",
    "from",
    "func",
    "if",
    "import",
    "in",
    "include",
    "interface",
    "is",
    "isnot",
    "iterator",
    "let",
    "macro",
    "method",
    "mixin",
    "mod",
    "nil",
    "not",
    "notin",
    "object",
    "of",
    "or",
    "out",
    "proc",
    "ptr",
    "raise",
    "ref",
    "return",
    "shl",
    "shr",
    "static",
    "template",
    "try",
    "tuple",
    "type",
    "using",
    "var",
    "when",
    "while",
    "xor",
    "yield",
}


def load_json(name: str) -> Dict[str, object]:
    return json.loads((PARITY / name).read_text(encoding="utf-8"))


def write_json(path: Path, data: Dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=False) + "\n", encoding="utf-8")


def nim_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def snake_to_pascal(s: str) -> str:
    parts = [p for p in s.strip("_").split("_") if p]
    if not parts:
        return "Unnamed"
    return "".join(p[:1].upper() + p[1:] for p in parts)


def write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def normalized_lines(text: str) -> List[str]:
    lines: List[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("##"):
            continue
        lines.append(line)
    return lines


def is_metadata_scaffold(text: str) -> bool:
    lines = normalized_lines(text)
    if len(lines) > 8:
        return False
    if "RustPath*" not in text or "RustCrate*" not in text or "GeneratedAt*" not in text:
        return False
    return not CODE_TOKEN_RE.search(text)


def classify_module_status(path: Path) -> str:
    if not path.exists():
        return "missing"

    text = read_text(path)
    if is_metadata_scaffold(text):
        return "scaffold"

    has_code_tokens = bool(CODE_TOKEN_RE.search(text))
    non_empty = len(normalized_lines(text))
    has_placeholder_hints = bool(PLACEHOLDER_HINT_RE.search(text))
    if has_code_tokens and non_empty >= 25 and not has_placeholder_hints:
        return "implemented"

    return "partial"


def nim_field_name(key: str) -> str:
    ident = re.sub(r"[^A-Za-z0-9_]", "_", key)
    if not ident:
        ident = "field_value"
    if ident[0].isdigit():
        ident = "field_" + ident
    if ident in NIM_RESERVED_WORDS:
        ident = ident + "_field"
    return ident


def infer_manual_requires_auth(route_name: str) -> bool:
    lowered = route_name.lower()
    for token in PUBLIC_MANUAL_ROUTE_TOKENS:
        if token in lowered:
            return False
    return True


def default_runtime_implemented_routes(routes: Dict[str, object]) -> List[str]:
    implemented = set()
    client = list(routes["client_ruma_routes"])
    server = list(routes["server_ruma_routes"])
    manual = list(routes["manual_routes"])

    for name in client:
        if name not in DEFAULT_RUNTIME_CLIENT_FALLBACK_ROUTE_NAMES:
            implemented.add(name)

    for name in server:
        if name not in DEFAULT_RUNTIME_SERVER_FALLBACK_ROUTE_NAMES:
            implemented.add(name)

    for name in manual:
        if name not in DEFAULT_RUNTIME_MANUAL_FALLBACK_ROUTE_NAMES:
            implemented.add(name)

    for name in client + server + manual:
        if name in DEFAULT_RUNTIME_EXTRA_IMPLEMENTED_ROUTE_NAMES:
            implemented.add(name)

    return sorted(implemented)


def unquote(s: str) -> str:
    if len(s) >= 2 and ((s[0] == '"' and s[-1] == '"') or (s[0] == "'" and s[-1] == "'")):
        return s[1:-1]
    return s


def parse_rust_string_expr(expr: str) -> str:
    expr = expr.strip().rstrip(";")
    m = re.search(r'String::from\("((?:[^"\\]|\\.)*)"\)', expr)
    if m:
        return '"' + m.group(1) + '"'

    m = re.search(r'"((?:[^"\\]|\\.)*)"\s*\.to_owned\(\)', expr)
    if m:
        return '"' + m.group(1) + '"'

    m = re.search(r'"((?:[^"\\]|\\.)*)"\s*\.into\(\)', expr)
    if m:
        return '"' + m.group(1) + '"'

    m = re.search(r'Some\(\s*"((?:[^"\\]|\\.)*)"\s*(?:\.to_owned\(\)|\.into\(\))?\s*\)', expr)
    if m:
        return '"' + m.group(1) + '"'

    m = re.search(r'"((?:[^"\\]|\\.)*)"$', expr)
    if m:
        return '"' + m.group(1) + '"'

    return ""


def eval_numeric_expr(expr: str) -> str:
    src = expr.strip().replace("_", "")
    if not src:
        return ""
    if re.search(r"[A-Za-z]", src):
        return ""

    try:
        tree = ast.parse(src, mode="eval")
    except SyntaxError:
        return ""

    def walk(node):
        if isinstance(node, ast.Expression):
            return walk(node.body)
        if isinstance(node, ast.Constant):
            if isinstance(node.value, (int, float)):
                return node.value
            raise ValueError("non-numeric constant")
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd)):
            v = walk(node.operand)
            return -v if isinstance(node.op, ast.USub) else +v
        if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub, ast.Mult, ast.Div, ast.FloorDiv)):
            a = walk(node.left)
            b = walk(node.right)
            if isinstance(node.op, ast.Add):
                return a + b
            if isinstance(node.op, ast.Sub):
                return a - b
            if isinstance(node.op, ast.Mult):
                return a * b
            if isinstance(node.op, ast.Div):
                return a / b
            return a // b
        raise ValueError("unsupported expression")

    try:
        value = walk(tree)
    except ValueError:
        return ""

    if isinstance(value, float):
        if value.is_integer():
            return str(int(value))
        return str(value)
    return str(int(value))


def normalize_doc_default(raw: str) -> str:
    text = raw.strip().rstrip(".")
    if not text:
        return ""

    lowered = text.lower()
    if "varies by system" in lowered:
        return ""

    if lowered in {"true", "false", "null", "none"}:
        return "null" if lowered in {"null", "none"} else lowered

    if text in {"[]", "{}"}:
        return text

    if (text.startswith('"') and text.endswith('"')) or (text.startswith("'") and text.endswith("'")):
        return text

    number = text.replace("_", "").replace(",", "")
    if re.fullmatch(r"-?\d+", number):
        return number
    if re.fullmatch(r"-?\d+\.\d+", number):
        return number

    mib = re.fullmatch(r"(-?\d+)\s*MiB", text, re.IGNORECASE)
    if mib:
        return str(int(mib.group(1)) * 1024 * 1024)

    seconds = re.fullmatch(r"(-?\d+)\s*seconds?", text, re.IGNORECASE)
    if seconds:
        return str(int(seconds.group(1)))

    days = re.fullmatch(r"(-?\d+)\s*days?", text, re.IGNORECASE)
    if days:
        return str(int(days.group(1)) * 86400)

    return ""


def normalize_rust_type(rust_type: str) -> str:
    return re.sub(r"\s+", "", rust_type)


def infer_type_default(rust_type: str) -> str:
    rt = normalize_rust_type(rust_type)
    numeric_types = {
        "u8",
        "u16",
        "u32",
        "u64",
        "usize",
        "i8",
        "i16",
        "i32",
        "i64",
        "isize",
        "f32",
        "f64",
    }
    if rt == "bool":
        return "false"
    if rt in numeric_types:
        return "0"
    if rt == "String":
        return "\"\""
    if rt.startswith("Option<"):
        return "null"
    if (
        rt.startswith("Vec<")
        or rt.startswith("BTreeSet<")
        or rt.startswith("HashSet<")
        or rt.startswith("RegexSet")
    ):
        return "[]"
    if rt.startswith("BTreeMap<") or rt.startswith("HashMap<"):
        return "{}"
    if rt.endswith("Config") or rt.endswith("Namespace"):
        return "{}"
    return ""


def rust_default_to_toml(default_body: str, rust_type: str) -> str:
    body = default_body.strip().rstrip(";")
    if not body:
        return ""

    if "\n" not in body:
        if body in {"true", "false"}:
            return body
        if body == "None":
            return "null"
        some_num = re.fullmatch(r"Some\((.+)\)", body)
        if some_num:
            s = some_num.group(1).strip()
            str_expr = parse_rust_string_expr(s)
            if str_expr:
                return str_expr
            parsed = eval_numeric_expr(some_num.group(1).strip())
            if parsed:
                return parsed
        str_expr = parse_rust_string_expr(body)
        if str_expr:
            return str_expr
        room_ver = re.search(r"RoomVersionId::V(\d+)", body)
        if room_ver:
            return '"' + room_ver.group(1) + '"'
        numeric = eval_numeric_expr(body)
        if numeric:
            return numeric

    if "vec!" in body:
        str_items = re.findall(r'"((?:[^"\\]|\\.)*)"', body)
        if str_items:
            quoted = ", ".join('"' + item + '"' for item in str_items)
            return "[" + quoted + "]"

    if normalize_rust_type(rust_type).startswith("Option<") and "None" in body:
        return "null"

    return ""


def render_string_seq(name: str, values: List[str]) -> str:
    lines = [f"let {name}*: seq[string] = @["]
    for v in values:
        lines.append(f"  \"{nim_escape(v)}\",")
    lines.append("]")
    return "\n".join(lines)


def generate_route_inventory(routes: Dict[str, object]) -> None:
    client = list(routes["client_ruma_routes"])
    server = list(routes["server_ruma_routes"])
    manual = list(routes["manual_routes"])

    content = "\n".join(
        [
            "## Generated by tools/generate_stubs.py. Do not edit manually.",
            "",
            render_string_seq("ClientRumaRoutes", client),
            "",
            render_string_seq("ServerRumaRoutes", server),
            "",
            render_string_seq("ManualRoutes", manual),
            "",
            "const",
            f"  ClientRumaRouteCount* = {len(client)}",
            f"  ServerRumaRouteCount* = {len(server)}",
            f"  ManualRouteCount* = {len(manual)}",
            f"  TotalRouteCount* = {len(client) + len(server) + len(manual)}",
            "",
        ]
    )

    write(SRC / "api" / "generated_route_inventory.nim", content)


def generate_route_types(routes: Dict[str, object]) -> None:
    client = list(routes["client_ruma_routes"])
    server = list(routes["server_ruma_routes"])

    used = Counter()
    defs: List[Tuple[str, str, str]] = []

    for kind, names in [("Client", client), ("Server", server)]:
        for name in names:
            base = snake_to_pascal(name)
            key = base
            if used[key] > 0:
                base = kind + base
            used[key] += 1
            req = f"{base}Request"
            res = f"{base}Response"
            defs.append((name, req, res))

    lines = [
        "## Generated by tools/generate_stubs.py. Do not edit manually.",
        "",
        "type",
        "  RoutePlaceholder* = object",
        "    routeName*: string",
        "",
    ]

    for _name, req, res in defs:
        lines.append("type")
        lines.append(f"  {req}* = object")
        lines.append("    placeholder*: RoutePlaceholder")
        lines.append(f"  {res}* = object")
        lines.append("    placeholder*: RoutePlaceholder")
        lines.append("")

    for name, req, res in defs:
        handler = name + "_placeholder"
        lines.append(f"proc {handler}*(req: {req}): {res} =")
        lines.append("  discard req")
        lines.append(f"  {res}(placeholder: RoutePlaceholder(routeName: \"{nim_escape(name)}\"))")
        lines.append("")

    write(SRC / "api" / "generated_route_types.nim", "\n".join(lines).rstrip() + "\n")


def generate_route_runtime(routes: Dict[str, object]) -> None:
    client = list(routes["client_ruma_routes"])
    server = list(routes["server_ruma_routes"])
    manual = list(routes["manual_routes"])
    route_entries = client + server + manual

    public_client = sorted([name for name in client if name in PUBLIC_CLIENT_ROUTE_NAMES])
    runtime_implemented = default_runtime_implemented_routes(routes)
    runtime_implemented_set = set(runtime_implemented)
    runtime_implemented_entries = sum(1 for name in route_entries if name in runtime_implemented_set)
    runtime_fallback_entries = len(route_entries) - runtime_implemented_entries

    lines = [
        "## Generated by tools/generate_stubs.py. Do not edit manually.",
        "",
        "import std/[options, tables]",
        "",
        "type",
        "  RouteKind* = enum",
        "    rkUnknown",
        "    rkClient",
        "    rkServer",
        "    rkManual",
        "",
        "  RouteSpec* = object",
        "    name*: string",
        "    kind*: RouteKind",
        "    requiresAuth*: bool",
        "    federationOnly*: bool",
        "",
        "  RouteError* = object",
        "    status*: int",
        "    errcode*: string",
        "    error*: string",
        "",
        "  RouteDispatchResult* = object",
        "    routeName*: string",
        "    routeKind*: RouteKind",
        "    requiresAuth*: bool",
        "    federationOnly*: bool",
        "    authorized*: bool",
        "    status*: int",
        "    ok*: bool",
        "    error*: RouteError",
        "",
        "  RouteRegistry* = Table[string, RouteSpec]",
        "",
        render_string_seq("PublicClientRouteNames", public_client),
        "",
        render_string_seq("RuntimeImplementedRouteNames", runtime_implemented),
        "",
        "let RouteSpecs*: seq[RouteSpec] = @[",
    ]

    for name in client:
        requires_auth = name not in PUBLIC_CLIENT_ROUTE_NAMES
        lines.append(
            "  RouteSpec("
            + f"name: \"{nim_escape(name)}\", "
            + "kind: rkClient, "
            + f"requiresAuth: {str(requires_auth).lower()}, "
            + "federationOnly: false"
            + "),"
        )

    for name in server:
        lines.append(
            "  RouteSpec("
            + f"name: \"{nim_escape(name)}\", "
            + "kind: rkServer, "
            + "requiresAuth: true, "
            + "federationOnly: true"
            + "),"
        )

    for name in manual:
        requires_auth = infer_manual_requires_auth(name)
        lines.append(
            "  RouteSpec("
            + f"name: \"{nim_escape(name)}\", "
            + "kind: rkManual, "
            + f"requiresAuth: {str(requires_auth).lower()}, "
            + "federationOnly: false"
            + "),"
        )

    lines.extend(
        [
            "]",
            "",
            "proc routeRegistry*(): RouteRegistry =",
            "  result = initTable[string, RouteSpec]()",
            "  for spec in RouteSpecs:",
            "    result[spec.name] = spec",
            "",
            "proc lookupRoutes*(name: string): seq[RouteSpec] =",
            "  result = @[]",
            "  for spec in RouteSpecs:",
            "    if spec.name == name:",
            "      result.add(spec)",
            "",
            "proc lookupRoute*(name: string): Option[RouteSpec] =",
            "  let matches = lookupRoutes(name)",
            "  if matches.len > 0:",
            "    return some(matches[0])",
            "  none(RouteSpec)",
            "",
            "proc selectRouteSpec*(matches: openArray[RouteSpec]; accessTokenPresent, federationAuthenticated: bool): RouteSpec =",
            "  result = matches[0]",
            "  if federationAuthenticated:",
            "    for spec in matches:",
            "      if spec.federationOnly:",
            "        result = spec",
            "        return",
            "",
            "  if accessTokenPresent:",
            "    for spec in matches:",
            "      if spec.requiresAuth and not spec.federationOnly:",
            "        result = spec",
            "        return",
            "",
            "  for spec in matches:",
            "    if not spec.requiresAuth and not spec.federationOnly:",
            "      result = spec",
            "      return",
            "",
            "proc routeCountByKind*(kind: RouteKind): int =",
            "  result = 0",
            "  for spec in RouteSpecs:",
            "    if spec.kind == kind:",
            "      inc result",
            "",
            "proc authorizationState*(spec: RouteSpec; accessTokenPresent, federationAuthenticated: bool): bool =",
            "  if spec.federationOnly:",
            "    return federationAuthenticated",
            "  if spec.requiresAuth:",
            "    return accessTokenPresent",
            "  return true",
            "",
            "proc matrixError(status: int; errcode, message: string): RouteError =",
            "  RouteError(status: status, errcode: errcode, error: message)",
            "",
            "proc unrecognizedRouteError(routeName: string): RouteError =",
            "  matrixError(404, \"M_UNRECOGNIZED\", \"Unrecognized route: \" & routeName)",
            "",
            "proc unauthorizedRouteError(spec: RouteSpec): RouteError =",
            "  if spec.federationOnly:",
            "    return matrixError(401, \"M_UNAUTHORIZED\", \"Missing federation authentication\")",
            "  matrixError(401, \"M_UNAUTHORIZED\", \"Missing access token authentication\")",
            "",
            "proc notImplementedRouteError(spec: RouteSpec): RouteError =",
            "  matrixError(501, \"M_NOT_YET_IMPLEMENTED\", \"Route registered but not yet behaviorally ported: \" & spec.name)",
            "",
            "proc routeHasRuntimeHandler*(spec: RouteSpec): bool =",
            "  case spec.name",
        ]
    )

    for name in runtime_implemented:
        lines.append(f"  of \"{nim_escape(name)}\":")
        lines.append("    true")

    lines.extend(
        [
            "  else:",
            "    false",
            "",
            "proc okRouteResult(spec: RouteSpec): RouteDispatchResult =",
            "  RouteDispatchResult(",
            "    routeName: spec.name,",
            "    routeKind: spec.kind,",
            "    requiresAuth: spec.requiresAuth,",
            "    federationOnly: spec.federationOnly,",
            "    authorized: true,",
            "    status: 200,",
            "    ok: true,",
            "    error: matrixError(200, \"\", \"\"),",
            "  )",
            "",
            "proc dispatchRoute*(",
            "    routeName: string;",
            "    accessTokenPresent = false;",
            "    federationAuthenticated = false): RouteDispatchResult =",
            "  let matches = lookupRoutes(routeName)",
            "  if matches.len == 0:",
            "    let err = unrecognizedRouteError(routeName)",
            "    return RouteDispatchResult(",
            "      routeName: routeName,",
            "      routeKind: rkUnknown,",
            "      requiresAuth: false,",
            "      federationOnly: false,",
            "      authorized: false,",
            "      status: err.status,",
            "      ok: false,",
            "      error: err,",
            "    )",
            "",
            "  let spec = selectRouteSpec(matches, accessTokenPresent, federationAuthenticated)",
            "  let authorized = authorizationState(spec, accessTokenPresent, federationAuthenticated)",
            "  if not authorized:",
            "    let err = unauthorizedRouteError(spec)",
            "    return RouteDispatchResult(",
            "      routeName: spec.name,",
            "      routeKind: spec.kind,",
            "      requiresAuth: spec.requiresAuth,",
            "      federationOnly: spec.federationOnly,",
            "      authorized: false,",
            "      status: err.status,",
            "      ok: false,",
            "      error: err,",
            "    )",
            "",
            "  if routeHasRuntimeHandler(spec):",
            "    return okRouteResult(spec)",
            "",
            "  let err = notImplementedRouteError(spec)",
            "  RouteDispatchResult(",
            "    routeName: spec.name,",
            "    routeKind: spec.kind,",
            "    requiresAuth: spec.requiresAuth,",
            "    federationOnly: spec.federationOnly,",
            "    authorized: true,",
            "    status: err.status,",
            "    ok: false,",
            "    error: err,",
            "  )",
            "",
            "const",
            f"  RegisteredRouteCount* = {len(client) + len(server) + len(manual)}",
            f"  RuntimeImplementedRouteCount* = {runtime_implemented_entries}",
            f"  RuntimeFallbackRouteCount* = {runtime_fallback_entries}",
            "",
        ]
    )

    write(SRC / "api" / "generated_route_runtime.nim", "\n".join(lines))


def generate_config_keys(config: Dict[str, object]) -> None:
    keys = [f["key"] for f in config["fields"]]
    content = "\n".join(
        [
            "## Generated by tools/generate_stubs.py. Do not edit manually.",
            "",
            render_string_seq("ConfigKeys", keys),
            "",
            f"const ConfigKeyCount* = {len(keys)}",
            "",
        ]
    )
    write(SRC / "core" / "generated_config_keys.nim", content)


def generate_config_model(config: Dict[str, object]) -> None:
    fields = list(config["fields"])
    field_name_counts: Counter = Counter()
    mapping: List[Tuple[str, str]] = []
    for field in fields:
        key = field["key"]
        base_name = nim_field_name(key)
        field_name_counts[base_name] += 1
        suffix = field_name_counts[base_name]
        field_name = base_name if suffix == 1 else f"{base_name}_{suffix}"
        mapping.append((key, field_name))

    lines = [
        "## Generated by tools/generate_stubs.py. Do not edit manually.",
        "",
        "import std/tables",
        "import config_values",
        "",
        "type",
        "  ConfigModel* = object",
    ]

    for _key, field_name in mapping:
        lines.append(f"    {field_name}*: ConfigValue")

    lines.extend(
        [
            "",
            "proc defaultConfigModel*(): ConfigModel =",
            "  ConfigModel(",
        ]
    )

    for _key, field_name in mapping:
        lines.append(f"    {field_name}: newNullValue(),")

    lines.extend(
        [
            "  )",
            "",
            "proc toFlatConfig*(model: ConfigModel): FlatConfig =",
            "  result = initFlatConfig()",
        ]
    )

    for key, field_name in mapping:
        lines.append(f"  result[\"{nim_escape(key)}\"] = model.{field_name}")

    lines.extend(
        [
            "",
            "proc fromFlatConfig*(values: FlatConfig): ConfigModel =",
            "  result = defaultConfigModel()",
        ]
    )

    for key, field_name in mapping:
        lines.extend(
            [
                f"  if \"{nim_escape(key)}\" in values:",
                f"    result.{field_name} = values[\"{nim_escape(key)}\"]",
            ]
        )

    lines.extend(
        [
            "",
            render_string_seq("ConfigModelKeys", [k for k, _ in mapping]),
            "",
            f"const ConfigModelKeyCount* = {len(mapping)}",
            "",
        ]
    )

    write(SRC / "core" / "generated_config_model.nim", "\n".join(lines))


def generate_config_defaults(config: Dict[str, object]) -> Dict[str, object]:
    fields = list(config.get("fields", []))
    default_functions = dict(config.get("default_functions", {}))
    entries: List[Dict[str, object]] = []
    applied_keys: List[str] = []
    applied_qualified_keys: List[str] = []
    expected_keys: List[str] = []
    expected_qualified_keys: List[str] = []
    expected_applied_keys: List[str] = []
    expected_applied_qualified_keys: List[str] = []

    for field in fields:
        key = field["key"]
        qualified_key = field.get("qualified_key", key)
        scope = field.get("scope", "")
        rust_type = field["rust_type"]
        default_doc = field.get("default_doc", "")
        provider = field.get("serde_default_provider", "")
        has_default = bool(field.get("serde_default_enabled", False))
        normalized_type = normalize_rust_type(rust_type)
        implicit_option_default = normalized_type.startswith("Option<")
        default_expected = has_default or bool(provider) or bool(default_doc) or implicit_option_default
        if default_expected:
            expected_keys.append(key)
            expected_qualified_keys.append(qualified_key)

        expr = ""
        source = ""
        if provider and provider in default_functions:
            expr = rust_default_to_toml(str(default_functions[provider]), rust_type)
            if expr:
                source = f"rust_fn:{provider}"

        if not expr and (has_default or implicit_option_default):
            expr = infer_type_default(rust_type)
            if expr:
                source = "type_default"

        if not expr and default_doc:
            expr = normalize_doc_default(default_doc)
            if expr:
                source = "doc_default"

        if not expr and has_default:
            expr = "{}"
            if expr:
                source = "serde_default_placeholder"

        parseable = bool(expr)
        if parseable:
            applied_keys.append(key)
            applied_qualified_keys.append(qualified_key)
        if parseable and default_expected:
            expected_applied_keys.append(key)
            expected_applied_qualified_keys.append(qualified_key)

        entries.append(
            {
                "key": key,
                "scope": scope,
                "qualified_key": qualified_key,
                "rust_type": rust_type,
                "default_expected": default_expected,
                "expr": expr,
                "source": source,
                "parseable": parseable,
            }
        )

    lines = [
        "## Generated by tools/generate_stubs.py. Do not edit manually.",
        "",
        "import config_values",
        "",
        "type",
        "  ConfigDefaultEntry* = object",
        "    key*: string",
        "    rustType*: string",
        "    source*: string",
        "    expr*: string",
        "    parseable*: bool",
        "",
        "let ConfigDefaultEntries*: seq[ConfigDefaultEntry] = @[",
    ]

    for item in entries:
        lines.append(
            "  ConfigDefaultEntry("
            + f"key: \"{nim_escape(item['key'])}\", "
            + f"rustType: \"{nim_escape(item['rust_type'])}\", "
            + f"source: \"{nim_escape(item['source'])}\", "
            + f"expr: \"{nim_escape(item['expr'])}\", "
            + f"parseable: {str(bool(item['parseable'])).lower()}"
            + "),"
        )

    lines.extend(
        [
            "]",
            "",
            "proc defaultConfigValues*(): FlatConfig =",
            "  result = initFlatConfig()",
            "  for entry in ConfigDefaultEntries:",
            "    if not entry.parseable:",
            "      continue",
            "    let parsed = parseTomlValue(entry.expr)",
            "    if parsed.ok:",
            "      result[entry.key] = parsed.value",
            "",
            f"const ConfigDefaultEntryCount* = {len(entries)}",
            f"const ConfigDefaultAppliedCount* = {len(applied_keys)}",
            f"const ConfigDefaultExpectedCount* = {len(expected_keys)}",
            f"const ConfigDefaultExpectedAppliedCount* = {len(expected_applied_keys)}",
            f"const ConfigDefaultMissingExpectedCount* = "
            f"{len(set(expected_qualified_keys) - set(expected_applied_qualified_keys))}",
            "",
        ]
    )

    missing_expected = sorted(set(expected_qualified_keys) - set(expected_applied_qualified_keys))
    lines.extend(
        [
            render_string_seq("ConfigDefaultMissingExpectedKeys", missing_expected),
            "",
        ]
    )

    write(SRC / "core" / "generated_config_defaults.nim", "\n".join(lines))

    report = {
        "total_keys": len(entries),
        "applied_count": len(applied_keys),
        "applied_keys": sorted(set(applied_keys)),
        "applied_qualified_keys": sorted(set(applied_qualified_keys)),
        "expected_default_count": len(expected_keys),
        "expected_applied_count": len(expected_applied_keys),
        "missing_expected_count": len(missing_expected),
        "expected_default_keys": sorted(set(expected_keys)),
        "expected_default_qualified_keys": sorted(set(expected_qualified_keys)),
        "expected_applied_keys": sorted(set(expected_applied_keys)),
        "expected_applied_qualified_keys": sorted(set(expected_applied_qualified_keys)),
        "missing_expected_keys": missing_expected,
        "entries": entries,
    }
    write_json(PARITY / "config_default_inventory.json", report)
    return report


def generate_db_cfs(db: Dict[str, object]) -> None:
    names = list(db["column_families"])
    content = "\n".join(
        [
            "## Generated by tools/generate_stubs.py. Do not edit manually.",
            "",
            render_string_seq("DatabaseColumnFamilies", names),
            "",
            f"const DatabaseColumnFamilyCount* = {len(names)}",
            "",
        ]
    )
    write(SRC / "database" / "generated_column_families.nim", content)


def generate_db_cf_descriptors(db: Dict[str, object]) -> None:
    descriptors = list(db.get("descriptors", []))
    required = list(db.get("required_column_families", []))

    lines = [
        "## Generated by tools/generate_stubs.py. Do not edit manually.",
        "",
        "type",
        "  DatabaseColumnFamilyDescriptor* = object",
        "    name*: string",
        "    dropped*: bool",
        "    ignored*: bool",
        "",
        "let DatabaseColumnFamilyDescriptors*: seq[DatabaseColumnFamilyDescriptor] = @[",
    ]

    for item in descriptors:
        lines.append(
            "  DatabaseColumnFamilyDescriptor("
            + f"name: \"{nim_escape(item['name'])}\", "
            + f"dropped: {str(bool(item.get('dropped', False))).lower()}, "
            + f"ignored: {str(bool(item.get('ignored', False))).lower()}"
            + "),"
        )

    lines.extend(
        [
            "]",
            "",
            render_string_seq("RequiredDatabaseColumnFamilies", required),
            "",
            f"const DatabaseColumnFamilyDescriptorCount* = {len(descriptors)}",
            f"const RequiredDatabaseColumnFamilyCount* = {len(required)}",
            "",
        ]
    )

    write(SRC / "database" / "generated_column_family_descriptors.nim", "\n".join(lines))


def generate_function_inventory(functions: Dict[str, object]) -> None:
    by_crate = list(functions["by_crate"])

    lines = [
        "## Generated by tools/generate_stubs.py. Do not edit manually.",
        "",
        "type",
        "  CrateFunctionCount* = object",
        "    crate*: string",
        "    functionCount*: int",
        "    fileCount*: int",
        "",
        "let RustCrateFunctionCounts*: seq[CrateFunctionCount] = @[",
    ]

    for item in by_crate:
        lines.append(
            "  CrateFunctionCount("
            + f"crate: \"{nim_escape(item['crate'])}\", "
            + f"functionCount: {int(item['function_count'])}, "
            + f"fileCount: {int(item['file_count'])}"
            + "),"
        )

    lines.extend(
        [
            "]",
            "",
            f"const RustFunctionTotal* = {int(functions['total_functions'])}",
            "",
        ]
    )

    write(SRC / "core" / "generated_function_inventory.nim", "\n".join(lines))


def generate_service_inventory(functions: Dict[str, object]) -> None:
    module_counts = Counter()
    for f in functions["files"]:
        if f["crate"] != "service":
            continue
        parts = f["rust_path"].split("/")
        module = parts[1] if len(parts) > 1 else "service"
        module_counts[module] += int(f["function_count"])

    lines = [
        "## Generated by tools/generate_stubs.py. Do not edit manually.",
        "",
        "type",
        "  ServiceModuleCount* = object",
        "    module*: string",
        "    functionCount*: int",
        "",
        "let ServiceModuleCounts*: seq[ServiceModuleCount] = @[",
    ]

    for module, count in sorted(module_counts.items()):
        lines.append(
            f"  ServiceModuleCount(module: \"{nim_escape(module)}\", functionCount: {int(count)}),"
        )

    lines.extend(
        [
            "]",
            "",
            f"const ServiceModuleCountTotal* = {len(module_counts)}",
            "",
        ]
    )

    write(SRC / "service" / "generated_service_inventory.nim", "\n".join(lines))


def generate_module_scaffold(module_map: Dict[str, object], baseline: Dict[str, object]) -> Dict[str, object]:
    generated_at = baseline.get("baseline", {}).get("generated_at_utc", "baseline-frozen")
    items = list(module_map["items"])
    mapped = len(items)

    for item in items:
        abs_path = ROOT / item["nim_path"]
        if abs_path.exists():
            continue

        content = "\n".join(
            [
                "## Generated by tools/generate_stubs.py. Do not edit manually.",
                "",
                "const",
                f"  RustPath* = \"{nim_escape(item['rust_path'])}\"",
                f"  RustCrate* = \"{nim_escape(item['crate'])}\"",
                f"  GeneratedAt* = \"{nim_escape(generated_at)}\"",
                "",
            ]
        )
        write(abs_path, content)

    missing_paths: List[str] = []
    for item in items:
        nim_path = item["nim_path"]
        if not (ROOT / nim_path).exists():
            missing_paths.append(nim_path)

    present = mapped - len(missing_paths)
    report = {
        "mapped": mapped,
        "present": present,
        "missing": len(missing_paths),
        "missing_paths": sorted(missing_paths),
    }
    write_json(PARITY / "module_coverage.json", report)
    return report


def generate_implementation_coverage(module_map: Dict[str, object]) -> Dict[str, object]:
    items = list(module_map["items"])
    summary = Counter()
    by_crate: Dict[str, Counter] = {}
    modules: List[Dict[str, object]] = []

    for item in items:
        crate = item["crate"]
        if crate not in by_crate:
            by_crate[crate] = Counter()

        nim_path = item["nim_path"]
        status = classify_module_status(ROOT / nim_path)
        summary[status] += 1
        by_crate[crate]["total"] += 1
        by_crate[crate][status] += 1

        modules.append(
            {
                "nim_path": nim_path,
                "rust_path": item["rust_path"],
                "crate": crate,
                "status": status,
            }
        )

    status_by_crate = []
    for crate in sorted(by_crate.keys()):
        counts = by_crate[crate]
        status_by_crate.append(
            {
                "crate": crate,
                "total": int(counts.get("total", 0)),
                "scaffold": int(counts.get("scaffold", 0)),
                "partial": int(counts.get("partial", 0)),
                "implemented": int(counts.get("implemented", 0)),
                "missing": int(counts.get("missing", 0)),
            }
        )

    total_modules = len(items)
    db_counts = by_crate.get("database", Counter())
    report = {
        "total_modules": total_modules,
        "summary": {
            "scaffold": int(summary.get("scaffold", 0)),
            "partial": int(summary.get("partial", 0)),
            "implemented": int(summary.get("implemented", 0)),
            "missing": int(summary.get("missing", 0)),
        },
        "status_by_crate": status_by_crate,
        "modules": modules,
        "thresholds": {
            "all_modules_implemented": int(summary.get("implemented", 0)) == total_modules and total_modules > 0,
            "database_modules_implemented": int(db_counts.get("implemented", 0)) == int(
                db_counts.get("total", 0)
            )
            and int(db_counts.get("total", 0)) > 0,
        },
    }

    write_json(PARITY / "implementation_coverage.json", report)
    return report


def route_api_source_texts() -> List[str]:
    texts: List[str] = []
    for base in [SRC / "api", SRC / "router"]:
        if not base.exists():
            continue

        for path in sorted(base.rglob("*.nim")):
            if path.name.startswith("generated_") and path.name != "generated_route_runtime.nim":
                continue
            text = read_text(path)
            if is_metadata_scaffold(text):
                continue
            texts.append(text.lower())

    return texts


def generate_route_behavior_coverage(routes: Dict[str, object]) -> Dict[str, object]:
    source_texts = route_api_source_texts()
    items: List[Dict[str, object]] = []

    summary = Counter()

    for kind, names in [
        ("client", list(routes["client_ruma_routes"])),
        ("server", list(routes["server_ruma_routes"])),
        ("manual", list(routes["manual_routes"])),
    ]:
        for name in names:
            token = name.lower()
            registered = False
            auth = False
            handler = False
            error_shape = False

            for text in source_texts:
                if token not in text:
                    continue
                registered = True
                auth = auth or bool(AUTH_HINT_RE.search(text))
                handler = handler or bool(CODE_TOKEN_RE.search(text))
                error_shape = error_shape or bool(ERROR_HINT_RE.search(text))

            if registered and auth and handler and error_shape:
                status = "implemented"
            elif registered or auth or handler or error_shape:
                status = "partial"
            else:
                status = "scaffold"

            items.append(
                {
                    "kind": kind,
                    "route": name,
                    "registered": registered,
                    "auth": auth,
                    "handler": handler,
                    "error_shape": error_shape,
                    "status": status,
                }
            )
            summary["total"] += 1
            summary["registered"] += int(registered)
            summary["auth"] += int(auth)
            summary["handler"] += int(handler)
            summary["error_shape"] += int(error_shape)

    total = int(summary.get("total", 0))
    report = {
        "summary": {
            "total_routes": total,
            "registered_routes": int(summary.get("registered", 0)),
            "auth_covered_routes": int(summary.get("auth", 0)),
            "handler_covered_routes": int(summary.get("handler", 0)),
            "error_shape_covered_routes": int(summary.get("error_shape", 0)),
        },
        "routes": items,
        "thresholds": {
            "all_routes_registered": int(summary.get("registered", 0)) == total and total > 0,
            "all_routes_behavioral": (
                int(summary.get("registered", 0)) == total
                and int(summary.get("auth", 0)) == total
                and int(summary.get("handler", 0)) == total
                and int(summary.get("error_shape", 0)) == total
                and total > 0
            ),
        },
    }

    write_json(PARITY / "route_behavior_coverage.json", report)
    return report


def generate_route_runtime_coverage(routes: Dict[str, object]) -> Dict[str, object]:
    client = list(routes["client_ruma_routes"])
    server = list(routes["server_ruma_routes"])
    manual = list(routes["manual_routes"])
    runtime_implemented = set(default_runtime_implemented_routes(routes))

    items: List[Dict[str, object]] = []
    summary = Counter()
    by_kind: Dict[str, Counter] = {
        "client": Counter(),
        "server": Counter(),
        "manual": Counter(),
    }

    for kind, names in [("client", client), ("server", server), ("manual", manual)]:
        for name in names:
            if kind == "client":
                requires_auth = name not in PUBLIC_CLIENT_ROUTE_NAMES
            elif kind == "server":
                requires_auth = True
            else:
                requires_auth = infer_manual_requires_auth(name)

            implemented = name in runtime_implemented
            status = "implemented" if implemented else "fallback"

            items.append(
                {
                    "kind": kind,
                    "route": name,
                    "requires_auth": requires_auth,
                    "status": status,
                }
            )

            summary["total"] += 1
            summary["implemented"] += int(implemented)
            summary["fallback"] += int(not implemented)
            summary["requires_auth"] += int(requires_auth)
            summary["public"] += int(not requires_auth)

            by_kind[kind]["total"] += 1
            by_kind[kind]["implemented"] += int(implemented)
            by_kind[kind]["fallback"] += int(not implemented)

    total = int(summary.get("total", 0))
    implemented_total = int(summary.get("implemented", 0))
    report = {
        "summary": {
            "total_routes": total,
            "implemented_routes": implemented_total,
            "fallback_routes": int(summary.get("fallback", 0)),
            "requires_auth_routes": int(summary.get("requires_auth", 0)),
            "public_routes": int(summary.get("public", 0)),
        },
        "by_kind": {
            kind: {
                "total": int(counts.get("total", 0)),
                "implemented": int(counts.get("implemented", 0)),
                "fallback": int(counts.get("fallback", 0)),
            }
            for kind, counts in by_kind.items()
        },
        "routes": items,
        "thresholds": {
            "has_runtime_dispatch": implemented_total > 0,
            "all_routes_runtime_implemented": implemented_total == total and total > 0,
        },
    }

    write_json(PARITY / "route_runtime_coverage.json", report)
    return report


def generate_config_behavior_coverage(
    config: Dict[str, object], defaults_report: Dict[str, object]
) -> Dict[str, object]:
    fields = list(config.get("fields", []))
    keys = [f["key"] for f in fields]
    qualified_keys = [f.get("qualified_key", f["key"]) for f in fields]

    config_mod_path = SRC / "core" / "config" / "mod.nim"
    config_mod_text = read_text(config_mod_path) if config_mod_path.exists() else ""
    config_mod_is_scaffold = is_metadata_scaffold(config_mod_text)

    generated_model_path = SRC / "core" / "generated_config_model.nim"
    generated_model_text = read_text(generated_model_path) if generated_model_path.exists() else ""
    default_key_set = set(defaults_report.get("applied_qualified_keys", []))
    expected_default_key_set = set(defaults_report.get("expected_default_qualified_keys", []))
    expected_default_applied_set = set(defaults_report.get("expected_applied_qualified_keys", []))

    loader_path = SRC / "core" / "config_loader.nim"
    merge_path = SRC / "core" / "config_merge.nim"
    args_update_path = SRC / "main" / "args_update.nim"
    loader_text = read_text(loader_path) if loader_path.exists() else ""
    merge_text = read_text(merge_path) if merge_path.exists() else ""
    args_update_text = read_text(args_update_path) if args_update_path.exists() else ""

    env_alias_support = (
        "mergeEnvPrefix" in loader_text
        and "CONDUIT_" in loader_text + merge_text
        and "CONDUWUIT_" in loader_text + merge_text
        and "TUWUNEL_" in loader_text + merge_text
    )
    option_override_support = "applyOptionOverrides" in args_update_text and "-O/--option" in args_update_text

    typed_key_set = set()
    if not config_mod_is_scaffold or generated_model_text:
        for key in keys:
            if re.search(rf"\b{re.escape(key)}\b", config_mod_text + "\n" + generated_model_text):
                typed_key_set.add(key)

    summary = Counter()
    entries = []
    for key, qualified_key in zip(keys, qualified_keys):
        typed = key in typed_key_set
        default = qualified_key in default_key_set
        default_expected = qualified_key in expected_default_key_set
        env_alias = env_alias_support
        override = option_override_support

        if typed and default and env_alias and override:
            status = "implemented"
        elif typed or default or env_alias or override:
            status = "partial"
        else:
            status = "scaffold"

        entries.append(
            {
                "key": key,
                "qualified_key": qualified_key,
                "typed": typed,
                "default": default,
                "default_expected": default_expected,
                "env_alias": env_alias,
                "override": override,
                "status": status,
            }
        )

        summary["total"] += 1
        summary["typed"] += int(typed)
        summary["default"] += int(default)
        summary["default_expected"] += int(default_expected)
        summary["env_alias"] += int(env_alias)
        summary["override"] += int(override)

    total = int(summary.get("total", 0))
    default_expected_total = int(summary.get("default_expected", 0))
    default_expected_applied = len(expected_default_applied_set)
    report = {
        "summary": {
            "total_keys": total,
            "typed_keys": int(summary.get("typed", 0)),
            "default_keys": int(summary.get("default", 0)),
            "default_expected_keys": default_expected_total,
            "default_expected_applied_keys": default_expected_applied,
            "env_alias_keys": int(summary.get("env_alias", 0)),
            "override_keys": int(summary.get("override", 0)),
        },
        "keys": entries,
        "thresholds": {
            "all_keys_typed": int(summary.get("typed", 0)) == total and total > 0,
            "all_keys_have_defaults": (
                default_expected_total == default_expected_applied and default_expected_total > 0
            ),
            "all_keys_env_alias_compatible": int(summary.get("env_alias", 0)) == total and total > 0,
            "all_keys_option_override_compatible": int(summary.get("override", 0)) == total and total > 0,
            "m2_ready": (
                int(summary.get("typed", 0)) == total
                and default_expected_total == default_expected_applied
                and default_expected_total > 0
                and int(summary.get("env_alias", 0)) == total
                and int(summary.get("override", 0)) == total
                and total > 0
            ),
        },
    }

    write_json(PARITY / "config_behavior_coverage.json", report)
    return report


def main() -> int:
    routes = load_json("route_inventory.json")
    config = load_json("config_inventory.json")
    db = load_json("db_cf_inventory.json")
    functions = load_json("rust_function_inventory.json")
    module_map = load_json("module_map.json")
    baseline = load_json("baseline.json")

    generate_route_inventory(routes)
    generate_route_types(routes)
    generate_route_runtime(routes)
    generate_config_keys(config)
    generate_config_model(config)
    defaults_report = generate_config_defaults(config)
    generate_db_cfs(db)
    generate_db_cf_descriptors(db)
    generate_function_inventory(functions)
    generate_service_inventory(functions)
    coverage = generate_module_scaffold(module_map, baseline)
    impl_cov = generate_implementation_coverage(module_map)
    route_cov = generate_route_behavior_coverage(routes)
    route_runtime_cov = generate_route_runtime_coverage(routes)
    config_cov = generate_config_behavior_coverage(config, defaults_report)

    print("Generated Nim stubs in src/")
    print(
        "Module scaffold coverage: "
        f"{coverage['present']}/{coverage['mapped']} present, "
        f"{coverage['missing']} missing"
    )
    print(
        "Implementation coverage: "
        f"{impl_cov['summary']['implemented']}/{impl_cov['total_modules']} implemented, "
        f"{impl_cov['summary']['partial']} partial, "
        f"{impl_cov['summary']['scaffold']} scaffold"
    )
    print(
        "Route behavior coverage: "
        f"registered={route_cov['summary']['registered_routes']}/{route_cov['summary']['total_routes']} "
        f"auth={route_cov['summary']['auth_covered_routes']} "
        f"handler={route_cov['summary']['handler_covered_routes']} "
        f"error_shape={route_cov['summary']['error_shape_covered_routes']}"
    )
    print(
        "Route runtime coverage: "
        f"implemented={route_runtime_cov['summary']['implemented_routes']}/{route_runtime_cov['summary']['total_routes']} "
        f"fallback={route_runtime_cov['summary']['fallback_routes']}"
    )
    print(
        "Config behavior coverage: "
        f"typed={config_cov['summary']['typed_keys']}/{config_cov['summary']['total_keys']} "
        f"default={config_cov['summary']['default_keys']} "
        f"env_alias={config_cov['summary']['env_alias_keys']} "
        f"override={config_cov['summary']['override_keys']}"
    )
    print(
        "Config defaults extracted: "
        f"{defaults_report['applied_count']}/{defaults_report['total_keys']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
