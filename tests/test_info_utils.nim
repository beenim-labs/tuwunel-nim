import std/[os, strutils, tables, unittest]

import core/info/cargo as cargo_info
import core/info/rustc as rustc_info
import core/info/version as version_info
import "core/info/mod" as mod_info

template withEnvValue(key, value: string; body: untyped) =
  let previous = getEnv(key, "")
  let hadPrevious = existsEnv(key)
  putEnv(key, value)
  try:
    body
  finally:
    if hadPrevious:
      putEnv(key, previous)
    else:
      delEnv(key)

suite "core info parity":
  test "version helpers preserve Tuwunel branding and extra precedence":
    check version_info.name() == "Tuwunel"
    check version_info.semantic().len > 0
    check version_info.userAgent().startsWith("Tuwunel/")
    withEnvValue("TUWUNEL_VERSION_EXTRA", "test-extra"):
      check version_info.version().endsWith("(test-extra)")

  test "cargo manifest helpers parse workspace dependency names":
    let manifest = """
[workspace.dependencies.alpha]
version = "1"

[workspace.dependencies.beta]
version = "2"
"""
    let deps = cargo_info.parseWorkspaceDependencies(manifest)
    check deps.hasKey("alpha")
    check deps.hasKey("beta")
    check cargo_info.workspaceManifestPath() == cargo_info.EmbeddedWorkspaceManifestPath
    check "argon2" in cargo_info.dependenciesNames()
    check "tuwunel-core" in cargo_info.dependenciesNames()
    check "url_preview" in cargo_info.features()

  test "rustc flag feature extraction mirrors --cfg feature pairs":
    rustc_info.captureFlags("core", ["--cfg", "feature=\"zstd\"", "--cfg", "test"])
    rustc_info.captureFlags("main", ["--cfg", "feature=\"zstd\"", "--cfg", "feature=\"sentry\""])
    let features = rustc_info.features()
    check features == @["sentry", "zstd"]
    check rustc_info.version().startsWith("nim ")

  test "module constants expose crate naming":
    check mod_info.ModuleRoot == "tuwunel_core"
    check mod_info.CratePrefix == "tuwunel"
