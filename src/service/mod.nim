import generated_service_inventory

from service/service import ServicePhase, ServiceState, ServiceIssue, ServiceHookResult, ServiceContext,
  ServiceHook, ServiceDefinition, ServiceRuntime, hookOk, hookErr, initServiceContext, setMeta, getMeta,
  incCounter, counterValue, initServiceDefinition, initServiceRuntime, runPhase, phaseRuns, failed
from service/manager import ServiceRegistrationReport, ServiceCycleReport, ServiceManager,
  initServiceManager, serviceCount, hasService, registerService, serviceState, registrationOrder,
  computeBootOrder, buildAll, startAll, pollAll, interruptAll, stopAll
from service/services import ServicePlanItem, defaultServicePlan, registerDefaultServices, defaultServiceCount
from service/once_services import OnceServiceGate, initOnceServiceGate, hasCompleted, markCompleted,
  shouldRun, runOnce, reset
from service/migrations import MigrationStep, MigrationReport, defaultMigrationSteps, runServiceMigrations
from service/config import ServiceRuntimeConfig, loadServiceRuntimeConfig
from service/globals import RuntimeGlobals, initRuntimeGlobals, uptimeSeconds, setHealth, health,
  touchLifecycle, GlobalDataStore, newGlobalDataStore, setValue, getValue, hasValue, addCounter, counter, valueCount

export generated_service_inventory
export ServicePhase, ServiceState, ServiceIssue, ServiceHookResult, ServiceContext, ServiceHook
export ServiceDefinition, ServiceRuntime, hookOk, hookErr, initServiceContext, setMeta, getMeta
export incCounter, counterValue, initServiceDefinition, initServiceRuntime, runPhase, phaseRuns, failed
export ServiceRegistrationReport, ServiceCycleReport, ServiceManager, initServiceManager, serviceCount
export hasService, registerService, serviceState, registrationOrder, computeBootOrder, buildAll, startAll
export pollAll, interruptAll, stopAll
export ServicePlanItem, defaultServicePlan, registerDefaultServices, defaultServiceCount
export OnceServiceGate, initOnceServiceGate, hasCompleted, markCompleted, shouldRun, runOnce, reset
export MigrationStep, MigrationReport, defaultMigrationSteps, runServiceMigrations
export ServiceRuntimeConfig, loadServiceRuntimeConfig
export RuntimeGlobals, initRuntimeGlobals, uptimeSeconds, setHealth, health, touchLifecycle
export GlobalDataStore, newGlobalDataStore, setValue, getValue, hasValue, addCounter, counter, valueCount

type
  ServiceModuleInfo* = object
    name*: string
    plannedModules*: int

proc serviceModuleInfo*(): ServiceModuleInfo =
  ServiceModuleInfo(name: "service", plannedModules: ServiceModuleCountTotal)
