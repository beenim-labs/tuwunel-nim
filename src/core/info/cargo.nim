import std/[algorithm, sequtils, strutils, tables]

const
  RustPath* = "core/info/cargo.rs"
  RustCrate* = "core"
  EmbeddedWorkspaceManifestPath* = "<embedded:workspace/Cargo.toml>"
  EmbeddedDependencyNames = [
    "argon2",
    "arrayvec",
    "async-channel",
    "async-trait",
    "axum",
    "axum-client-ip",
    "axum-extra",
    "axum-server",
    "axum-server-dual-protocol",
    "base64",
    "blurhash",
    "bytes",
    "bytesize",
    "cargo_toml",
    "checked_ops",
    "chrono",
    "clap",
    "core_affinity",
    "const-str",
    "criterion",
    "ctor",
    "cyborgtime",
    "derive_more",
    "either",
    "figment",
    "futures",
    "hickory-resolver",
    "hmac",
    "http",
    "http-body-util",
    "hyper",
    "image",
    "insta",
    "ipaddress",
    "itertools",
    "jevmalloc",
    "jsonwebtoken",
    "ldap3",
    "libc",
    "libloading",
    "log",
    "loole",
    "lru-cache",
    "maplit",
    "minicbor",
    "minicbor-serde",
    "nix",
    "num_cpus",
    "num-traits",
    "object_store",
    "opentelemetry",
    "opentelemetry_sdk",
    "proc-macro2",
    "quote",
    "rand",
    "regex",
    "reqwest",
    "ring",
    "ruma",
    "rust-rocksdb",
    "rustls",
    "rustyline-async",
    "sanitize-filename",
    "sd-notify",
    "sentry",
    "sentry-tower",
    "sentry-tracing",
    "serde",
    "serde_core",
    "serde_html_form",
    "serde_json",
    "serde_regex",
    "serde_yaml",
    "sha1",
    "sha2",
    "similar",
    "smallstr",
    "smallvec",
    "syn",
    "termimad",
    "thiserror",
    "tokio",
    "tokio-metrics",
    "toml",
    "tower",
    "tower-http",
    "tracing",
    "tracing-core",
    "tracing-flame",
    "tracing-opentelemetry",
    "tracing-subscriber",
    "tuwunel-admin",
    "tuwunel-api",
    "tuwunel-core",
    "tuwunel-database",
    "tuwunel-macros",
    "tuwunel-router",
    "tuwunel-service",
    "url",
    "webpage",
    "webpki-root-certs"
  ]
  EmbeddedFeatureNames = [
    "blurhashing",
    "brotli_compression",
    "bzip2_compression",
    "console",
    "default",
    "direct_tls",
    "element_hacks",
    "gzip_compression",
    "io_uring",
    "jemalloc",
    "jemalloc_conf",
    "jemalloc_prof",
    "jemalloc_stats",
    "ldap",
    "lz4_compression",
    "media_thumbnail",
    "perf_measurements",
    "release_max_log_level",
    "sentry_telemetry",
    "systemd",
    "tokio_console",
    "tuwunel_mods",
    "url_preview",
    "zstd_compression"
  ]

type DepsSet* = OrderedTable[string, string]

proc workspaceManifestPath*(): string =
  EmbeddedWorkspaceManifestPath

proc parseWorkspaceDependencies*(manifest: string): DepsSet =
  result = initOrderedTable[string, string]()
  for rawLine in manifest.splitLines():
    let line = rawLine.strip()
    if line.startsWith("[workspace.dependencies.") and line.endsWith("]"):
      let name = line["[workspace.dependencies.".len ..< line.high]
      result[name] = ""

proc parseFeatureNames*(manifest: string): seq[string] =
  result = @[]
  var inFeatureSection = false
  for rawLine in manifest.splitLines():
    let line = rawLine.strip()
    if line.startsWith("[") and line.endsWith("]"):
      inFeatureSection = line == "[features]" or line.endsWith(".features]")
      continue
    if inFeatureSection and "=" in line:
      let key = line.split("=", 1)[0].strip()
      if key.len > 0:
        result.add(key)
  result.sort()
  result = result.deduplicate(isSorted = true)

proc dependencies*(): DepsSet =
  result = initOrderedTable[string, string]()
  for name in EmbeddedDependencyNames:
    result[name] = ""

proc dependenciesNames*(): seq[string] =
  result = @[]
  for name in dependencies().keys:
    result.add(name)
  result.sort()

proc features*(): seq[string] =
  result = @[]
  for name in EmbeddedFeatureNames:
    result.add(name)
  result.sort()
  result = result.deduplicate(isSorted = true)
