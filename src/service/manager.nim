import std/[algorithm, sets, tables]
import service/service

const
  RustPath* = "service/manager.rs"
  RustCrate* = "service"
  GeneratedAt* = "2026-02-06T01:01:57+00:00"

type
  ServiceRegistrationReport* = object
    ok*: bool
    registered*: int
    errors*: seq[string]

  ServiceCycleReport* = object
    ok*: bool
    executed*: int
    order*: seq[string]
    errors*: seq[string]

  ServiceManager* = ref object
    context*: ServiceContext
    services*: OrderedTable[string, ServiceRuntime]
    bootOrder*: seq[string]

proc initServiceManager*(context: ServiceContext): ServiceManager =
  new(result)
  result.context = context
  result.services = initOrderedTable[string, ServiceRuntime]()
  result.bootOrder = @[]

proc serviceCount*(manager: ServiceManager): int =
  manager.services.len

proc hasService*(manager: ServiceManager; id: string): bool =
  id in manager.services

proc registerService*(manager: ServiceManager; definition: ServiceDefinition): ServiceRegistrationReport =
  result = ServiceRegistrationReport(ok: true, registered: 0, errors: @[])
  if definition.id.len == 0:
    result.ok = false
    result.errors.add("Service id cannot be empty")
    return

  if manager.hasService(definition.id):
    result.ok = false
    result.errors.add("Duplicate service id: " & definition.id)
    return

  manager.services[definition.id] = initServiceRuntime(definition)
  result.registered = 1

proc serviceState*(manager: ServiceManager; id: string): ServiceState =
  if id notin manager.services:
    return ssFailed
  manager.services[id].state

proc registrationOrder*(manager: ServiceManager): seq[string] =
  result = @[]
  for id in manager.services.keys:
    result.add(id)

proc computeBootOrder*(manager: ServiceManager): ServiceCycleReport =
  var pending = initHashSet[string]()
  for id in manager.services.keys:
    pending.incl(id)

  var resolved = initHashSet[string]()
  var order: seq[string] = @[]
  var errors: seq[string] = @[]

  let registered = manager.registrationOrder()
  while pending.len > 0:
    var progressed = false

    for id in registered:
      if id notin pending:
        continue

      let definition = manager.services[id].definition
      var ready = true
      for dep in definition.dependencies:
        if dep notin manager.services:
          errors.add("Service " & id & " depends on unknown service " & dep)
          ready = false
          break
        if dep notin resolved:
          ready = false
          break

      if not ready:
        continue

      progressed = true
      order.add(id)
      resolved.incl(id)
      pending.excl(id)

    if not progressed:
      var left: seq[string] = @[]
      for id in pending.items:
        left.add(id)
      left.sort(system.cmp[string])
      errors.add("Dependency cycle detected among " & $left)
      break

  result = ServiceCycleReport(
    ok: errors.len == 0,
    executed: order.len,
    order: order,
    errors: errors,
  )

  if result.ok:
    manager.bootOrder = order

proc runPhaseOrdered(
    manager: ServiceManager; phase: ServicePhase; reverse = false): ServiceCycleReport =
  var ids = if manager.bootOrder.len > 0: manager.bootOrder else: manager.registrationOrder()
  if reverse:
    ids.reverse()

  var errors: seq[string] = @[]
  var executed = 0
  for id in ids:
    if id notin manager.services:
      errors.add("Missing service during phase execution: " & id)
      continue

    var runtime = manager.services[id]
    let outcome = runtime.runPhase(manager.context, phase)
    manager.services[id] = runtime

    if not outcome.ok:
      errors.add("Service " & id & " failed in phase " & $phase & ": " & outcome.err)
      if runtime.definition.critical:
        return ServiceCycleReport(
          ok: false,
          executed: executed,
          order: ids,
          errors: errors,
        )

    inc executed

  ServiceCycleReport(
    ok: errors.len == 0,
    executed: executed,
    order: ids,
    errors: errors,
  )

proc buildAll*(manager: ServiceManager): ServiceCycleReport =
  let order = manager.computeBootOrder()
  if not order.ok:
    return order
  manager.runPhaseOrdered(spBuild)

proc startAll*(manager: ServiceManager): ServiceCycleReport =
  manager.runPhaseOrdered(spStart)

proc pollAll*(manager: ServiceManager): ServiceCycleReport =
  manager.runPhaseOrdered(spPoll)

proc interruptAll*(manager: ServiceManager): ServiceCycleReport =
  manager.runPhaseOrdered(spInterrupt, reverse = true)

proc stopAll*(manager: ServiceManager): ServiceCycleReport =
  manager.runPhaseOrdered(spStop, reverse = true)
