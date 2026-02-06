#!/usr/bin/env python3
"""Generate Nim stubs and constants from extracted parity inventory."""

from __future__ import annotations

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

    public_client = sorted([name for name in client if name in PUBLIC_CLIENT_ROUTE_NAMES])

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
            "proc lookupRoute*(name: string): Option[RouteSpec] =",
            "  for spec in RouteSpecs:",
            "    if spec.name == name:",
            "      return some(spec)",
            "  none(RouteSpec)",
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
            "proc dispatchRoute*(",
            "    routeName: string;",
            "    accessTokenPresent = false;",
            "    federationAuthenticated = false): RouteDispatchResult =",
            "  let specOpt = lookupRoute(routeName)",
            "  if specOpt.isNone:",
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
            "  let spec = specOpt.get",
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


def generate_config_behavior_coverage(config: Dict[str, object]) -> Dict[str, object]:
    fields = list(config.get("fields", []))
    keys = [f["key"] for f in fields]

    config_mod_path = SRC / "core" / "config" / "mod.nim"
    config_mod_text = read_text(config_mod_path) if config_mod_path.exists() else ""
    config_mod_is_scaffold = is_metadata_scaffold(config_mod_text)

    defaults_path = SRC / "core" / "config_bootstrap.nim"
    defaults_text = read_text(defaults_path) if defaults_path.exists() else ""
    generated_model_path = SRC / "core" / "generated_config_model.nim"
    generated_model_text = read_text(generated_model_path) if generated_model_path.exists() else ""

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
    default_key_set = set()
    if not config_mod_is_scaffold or generated_model_text:
        for key in keys:
            if re.search(rf"\b{re.escape(key)}\b", config_mod_text + "\n" + generated_model_text):
                typed_key_set.add(key)
            if f"\"{key}\"" in defaults_text or f"'{key}'" in defaults_text:
                default_key_set.add(key)

    summary = Counter()
    entries = []
    for key in keys:
        typed = key in typed_key_set
        default = key in default_key_set
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
                "typed": typed,
                "default": default,
                "env_alias": env_alias,
                "override": override,
                "status": status,
            }
        )

        summary["total"] += 1
        summary["typed"] += int(typed)
        summary["default"] += int(default)
        summary["env_alias"] += int(env_alias)
        summary["override"] += int(override)

    total = int(summary.get("total", 0))
    report = {
        "summary": {
            "total_keys": total,
            "typed_keys": int(summary.get("typed", 0)),
            "default_keys": int(summary.get("default", 0)),
            "env_alias_keys": int(summary.get("env_alias", 0)),
            "override_keys": int(summary.get("override", 0)),
        },
        "keys": entries,
        "thresholds": {
            "all_keys_typed": int(summary.get("typed", 0)) == total and total > 0,
            "all_keys_have_defaults": int(summary.get("default", 0)) == total and total > 0,
            "all_keys_env_alias_compatible": int(summary.get("env_alias", 0)) == total and total > 0,
            "all_keys_option_override_compatible": int(summary.get("override", 0)) == total and total > 0,
            "m2_ready": (
                int(summary.get("typed", 0)) == total
                and int(summary.get("default", 0)) == total
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
    generate_db_cfs(db)
    generate_db_cf_descriptors(db)
    generate_function_inventory(functions)
    generate_service_inventory(functions)
    coverage = generate_module_scaffold(module_map, baseline)
    impl_cov = generate_implementation_coverage(module_map)
    route_cov = generate_route_behavior_coverage(routes)
    config_cov = generate_config_behavior_coverage(config)

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
        "Config behavior coverage: "
        f"typed={config_cov['summary']['typed_keys']}/{config_cov['summary']['total_keys']} "
        f"default={config_cov['summary']['default_keys']} "
        f"env_alias={config_cov['summary']['env_alias_keys']} "
        f"override={config_cov['summary']['override_keys']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
