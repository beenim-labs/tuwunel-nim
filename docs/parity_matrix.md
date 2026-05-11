| Milestone | Status | Evidence |
| --- | --- | --- |
| M1 inventory + codegen | Implemented | Route, config, database, and module inventories are present and registered. |
| M2 core runtime/CLI/config parity | Implemented | Config defaults and CLI compatibility tests cover the generated config model. |
| M3 database compatibility | Implemented | In-memory database runtime, schema, serialization, and RocksDB-disabled policy tests pass. |
| M4+ | In progress | Native runtime smoke paths pass and client appstate/device/ephemeral/presence/profile/room-history/push routes now persist filters, account data, tags, device metadata, pushers, push rules, read receipts, fully-read markers, local presence, profile fields, aliases, member-event filters, and timeline context/event pagination, plus transient typing state. Another 57 client compatibility routes return Matrix-shaped local responses instead of registered 501 fallbacks, but 60 fallback routes and deeper federation/E2EE/room-graph semantics remain before full Rust parity. |
