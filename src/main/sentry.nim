import core/config_values

const
  RustPath* = "main/sentry.rs"
  RustCrate* = "main"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  SentryPlan* = object
    enabled*: bool
    endpoint*: string
    filter*: string
    sendServerName*: bool
    tracesSampleRate*: float

proc valueAsBool(value: ConfigValue; fallback: bool): bool =
  case value.kind
  of cvBool:
    value.b
  of cvInt:
    value.i != 0
  of cvString:
    value.s.toLowerAscii() in ["1", "true", "yes", "on"]
  else:
    fallback

proc valueAsString(value: ConfigValue; fallback: string): string =
  case value.kind
  of cvString:
    value.s
  else:
    fallback

proc valueAsFloat(value: ConfigValue; fallback: float): float =
  case value.kind
  of cvFloat:
    value.f
  of cvInt:
    float(value.i)
  else:
    fallback

proc readBool(values: FlatConfig; key: string; fallback: bool): bool =
  if key in values:
    return valueAsBool(values[key], fallback)
  fallback

proc readString(values: FlatConfig; key, fallback: string): string =
  if key in values:
    return valueAsString(values[key], fallback)
  fallback

proc readFloat(values: FlatConfig; key: string; fallback: float): float =
  if key in values:
    return valueAsFloat(values[key], fallback)
  fallback

proc buildSentryPlan*(values: FlatConfig): SentryPlan =
  SentryPlan(
    enabled: readBool(values, "sentry", false),
    endpoint: readString(values, "sentry_endpoint", ""),
    filter: readString(values, "sentry_filter", ""),
    sendServerName: readBool(values, "sentry_send_server_name", true),
    tracesSampleRate: readFloat(values, "sentry_traces_sample_rate", 0.0),
  )

proc sentryReady*(plan: SentryPlan): bool =
  if not plan.enabled:
    return true
  plan.endpoint.len > 0

proc sentrySummaryLine*(plan: SentryPlan): string =
  "enabled=" & $plan.enabled &
    " endpoint=" & plan.endpoint &
    " filter=" & plan.filter &
    " send_server_name=" & $plan.sendServerName &
    " traces=" & $plan.tracesSampleRate
