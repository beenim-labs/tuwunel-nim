## Database pool configuration helpers.

type
  DbPoolConfig* = object
    workers*: int
    queueMultiplier*: int
    maxWorkers*: int

proc defaultDbPoolConfig*(): DbPoolConfig =
  DbPoolConfig(
    workers: 4,
    queueMultiplier: 4,
    maxWorkers: 64,
  )

proc withWorkers*(config: DbPoolConfig; workers: int): DbPoolConfig =
  result = config
  result.workers = max(1, workers)

proc withQueueMultiplier*(config: DbPoolConfig; queueMultiplier: int): DbPoolConfig =
  result = config
  result.queueMultiplier = max(1, queueMultiplier)

proc withMaxWorkers*(config: DbPoolConfig; maxWorkers: int): DbPoolConfig =
  result = config
  result.maxWorkers = max(1, maxWorkers)

proc queueCapacity*(config: DbPoolConfig): int =
  max(1, config.workers * config.queueMultiplier)

proc isValid*(config: DbPoolConfig): bool =
  config.workers > 0 and config.maxWorkers >= config.workers

proc normalize*(config: DbPoolConfig): DbPoolConfig =
  result = config
  if result.workers <= 0:
    result.workers = 1
  if result.queueMultiplier <= 0:
    result.queueMultiplier = 1
  if result.maxWorkers < result.workers:
    result.maxWorkers = result.workers
