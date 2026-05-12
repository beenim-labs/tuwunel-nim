const
  RustPath* = "api/client/versions.rs"
  RustCrate* = "api"
  GeneratedAt* = "2026-05-12T00:00:00+00:00"

import std/json

const
  SupportedVersions* = [
    "r0.0.1",
    "r0.1.0",
    "r0.2.0",
    "r0.3.0",
    "r0.4.0",
    "r0.5.0",
    "r0.6.0",
    "r0.6.1",
    "v1.1",
    "v1.2",
    "v1.3",
    "v1.4",
    "v1.5",
    "v1.10",
    "v1.11",
    "v1.12",
    "v1.15",
  ]

  UnstableFeatures* = [
    "org.matrix.e2e_cross_signing",
    "org.matrix.msc2285.stable",
    "fi.mau.msc2659.stable",
    "uk.half-shot.msc2666.query_mutual_rooms",
    "org.matrix.msc2836",
    "org.matrix.msc3030",
    "org.matrix.msc2946",
    "org.matrix.msc3026.busy_presence",
    "org.matrix.msc3575",
    "org.matrix.msc3814",
    "org.matrix.msc3827",
    "org.matrix.msc3827.stable",
    "org.matrix.msc3916.stable",
    "org.matrix.msc3952_intentional_mentions",
    "uk.tcpip.msc4133",
    "uk.tcpip.msc4133.stable",
    "us.cloke.msc4175",
    "us.cloke.msc4175.stable",
    "org.matrix.msc4180",
    "org.matrix.simplified_msc3575",
    "fi.mau.msc2815",
    "org.matrix.msc2964",
    "org.matrix.msc2965",
    "org.matrix.msc2966",
    "org.matrix.msc2967",
    "org.matrix.msc3824",
    "com.beeper.msc4169",
    "org.matrix.msc4380",
    "org.matrix.msc4380.stable",
    "net.zemos.msc4383",
    "org.matrix.msc4284",
    "org.matrix.msc3771",
    "org.matrix.msc3773",
  ]

proc supportedVersionsResponse*(
    version: string;
    serverName = "tuwunel";
    compiler = "nim"
): JsonNode =
  var versions = newJArray()
  for item in SupportedVersions:
    versions.add(%item)

  var features = newJObject()
  for item in UnstableFeatures:
    features[item] = %true

  %*{
    "versions": versions,
    "unstable_features": features,
    "server": {
      "name": serverName,
      "version": version,
      "compiler": compiler,
    }
  }
