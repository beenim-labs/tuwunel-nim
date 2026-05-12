const
  RustPath* = "service/media/migrations.rs"
  RustCrate* = "service"

type
  MediaMigration* = object
    name*: string
    applied*: bool

proc defaultMediaMigrations*(): seq[MediaMigration] =
  @[
    MediaMigration(name: "mediaid_file", applied: true),
    MediaMigration(name: "mediaid_pending", applied: true),
    MediaMigration(name: "mediaid_user", applied: true),
    MediaMigration(name: "url_previews", applied: true),
  ]

proc allMediaMigrationsApplied*(migrations: openArray[MediaMigration]): bool =
  for migration in migrations:
    if not migration.applied:
      return false
  true
