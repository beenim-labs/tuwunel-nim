type
  AdminStatus* = object
    enabled*: bool
    commandCount*: int
    lastCommand*: string
    errors*: seq[string]

proc defaultAdminStatus*(): AdminStatus =
  AdminStatus(enabled: false, commandCount: 0, lastCommand: "", errors: @[])

proc adminEnabled*(status: AdminStatus): bool =
  status.enabled

proc recordAdminCommand*(status: var AdminStatus; command: string; ok = true) =
  status.enabled = true
  status.lastCommand = command
  inc status.commandCount
  if not ok:
    status.errors.add(command)

proc adminFailureCount*(status: AdminStatus): int =
  status.errors.len

proc adminSummaryLine*(status: AdminStatus): string =
  "enabled=" & $status.enabled &
    " commands=" & $status.commandCount &
    " failures=" & $status.errors.len &
    " last=" & status.lastCommand

proc adminHealthy*(status: AdminStatus): bool =
  status.enabled and status.errors.len == 0

proc resetAdminStatus*(status: var AdminStatus) =
  status.enabled = false
  status.commandCount = 0
  status.lastCommand = ""
  status.errors.setLen(0)

proc adminLastError*(status: AdminStatus): string =
  if status.errors.len == 0:
    return ""
  status.errors[^1]
