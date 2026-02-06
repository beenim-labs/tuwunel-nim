## Engine backup helpers.

import std/[json, os]
import context
import files

type
  BackupReport* = object
    sourcePath*: string
    backupPath*: string
    descriptorCount*: int
    fileCountAtSource*: int

proc writeBackupManifest*(path: string; report: BackupReport) =
  let payload = %*{
    "source_path": report.sourcePath,
    "backup_path": report.backupPath,
    "descriptor_count": report.descriptorCount,
    "file_count_at_source": report.fileCountAtSource,
  }
  writeFile(path, $payload)

proc createBackupReport*(context: EngineContext; backupRoot: string): BackupReport =
  ensureDbDir(backupRoot)
  let targetPath = buildBackupPath(backupRoot, timestampTag())
  ensureDbDir(targetPath)

  BackupReport(
    sourcePath: context.path,
    backupPath: targetPath,
    descriptorCount: context.selectedDescriptors().len,
    fileCountAtSource: dbFileCount(context.path),
  )

proc createBackup*(context: EngineContext; backupRoot: string): BackupReport =
  let report = createBackupReport(context, backupRoot)
  writeBackupManifest(report.backupPath / "backup_manifest.json", report)
  report
