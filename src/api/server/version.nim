import std/json

const
  RustPath* = "api/server/version.rs"
  RustCrate* = "api"

proc federationVersionPayload*(
    version: string;
    compiler = "nim";
    name = "Tuwunel"
): JsonNode =
  %*{
    "server": {
      "name": name,
      "version": version,
      "compiler": compiler
    }
  }
