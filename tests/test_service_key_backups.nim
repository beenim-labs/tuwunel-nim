import std/[json, tables, unittest]

import "service/key_backups/mod" as key_backup_service

suite "Service key backup parity":
  test "versions use monotonic ids etags metadata and latest lookup":
    var service = key_backup_service.initKeyBackupService()
    let first = key_backup_service.createBackup(
      service,
      "@alice:localhost",
      %*{
        "algorithm": "m.megolm_backup.v1.curve25519-aes-sha2",
        "auth_data": {"public_key": "curve-one"},
      },
    )
    let second = key_backup_service.createBackup(
      service,
      "@alice:localhost",
      %*{
        "algorithm": "m.megolm_backup.v1.curve25519-aes-sha2",
        "auth_data": {"public_key": "curve-two"},
      },
    )
    check first == "1"
    check second == "3"
    check key_backup_service.getLatestBackupVersion(service, "@alice:localhost").version == second
    check key_backup_service.getLatestBackup(service, "@alice:localhost").metadata["auth_data"]["public_key"].getStr == "curve-two"

    let priorEtag = key_backup_service.getEtag(service, "@alice:localhost", second)
    check key_backup_service.updateBackup(
      service,
      "@alice:localhost",
      second,
      %*{"algorithm": "m.megolm_backup.v1.curve25519-aes-sha2", "auth_data": {"public_key": "curve-updated"}},
    ).ok
    check key_backup_service.getBackup(service, "@alice:localhost", second).metadata["auth_data"]["public_key"].getStr == "curve-updated"
    check key_backup_service.getEtag(service, "@alice:localhost", second) != priorEtag

  test "session keys group by room and mutate etags like Rust backup storage":
    var service = key_backup_service.initKeyBackupService()
    let version = key_backup_service.createBackup(
      service,
      "@alice:localhost",
      %*{"algorithm": "m.megolm_backup.v1.curve25519-aes-sha2", "auth_data": {}},
    )
    let createdEtag = key_backup_service.getEtag(service, "@alice:localhost", version)
    check key_backup_service.addKey(
      service,
      "@alice:localhost",
      version,
      "!room:localhost",
      "sess1",
      %*{"first_message_index": 1, "session_data": {"ciphertext": "one"}},
    ).ok
    check key_backup_service.addKey(
      service,
      "@alice:localhost",
      version,
      "!room:localhost",
      "sess2",
      %*{"first_message_index": 2, "session_data": {"ciphertext": "two"}},
    ).ok
    check key_backup_service.addKey(
      service,
      "@alice:localhost",
      version,
      "!other:localhost",
      "sess3",
      %*{"first_message_index": 3, "session_data": {"ciphertext": "three"}},
    ).ok

    check key_backup_service.getEtag(service, "@alice:localhost", version) != createdEtag
    check key_backup_service.countKeys(service, "@alice:localhost", version) == 3
    let allRooms = key_backup_service.getAll(service, "@alice:localhost", version)
    check allRooms.len == 2
    check allRooms["!room:localhost"]["sess1"]["session_data"]["ciphertext"].getStr == "one"
    let room = key_backup_service.getRoom(service, "@alice:localhost", version, "!room:localhost")
    check room.len == 2
    check key_backup_service.getSession(service, "@alice:localhost", version, "!room:localhost", "sess2").keyData["first_message_index"].getInt == 2

    key_backup_service.deleteRoomKey(service, "@alice:localhost", version, "!room:localhost", "sess1")
    check key_backup_service.countKeys(service, "@alice:localhost", version) == 2
    key_backup_service.deleteRoomKeys(service, "@alice:localhost", version, "!room:localhost")
    check key_backup_service.countKeys(service, "@alice:localhost", version) == 1
    key_backup_service.deleteAllKeys(service, "@alice:localhost", version)
    check key_backup_service.countKeys(service, "@alice:localhost", version) == 0

  test "deleting a backup removes metadata and sessions":
    var service = key_backup_service.initKeyBackupService()
    let version = key_backup_service.createBackup(
      service,
      "@alice:localhost",
      %*{"algorithm": "m.megolm_backup.v1.curve25519-aes-sha2", "auth_data": {}},
    )
    check key_backup_service.addKey(service, "@alice:localhost", version, "!room:localhost", "sess", %*{"session_data": {}}).ok
    key_backup_service.deleteBackup(service, "@alice:localhost", version)
    check not key_backup_service.backupVersionExists(service, "@alice:localhost", version)
    check key_backup_service.countKeys(service, "@alice:localhost", version) == 0
