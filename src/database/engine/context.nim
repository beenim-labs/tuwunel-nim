## Context for opening and managing database engine handles.

import ../generated_column_family_descriptors
import cf_opts
import db_opts

type
  EngineContext* = object
    path*: string
    descriptors*: seq[DatabaseColumnFamilyDescriptor]
    dbOptions*: EngineDbOptions
    cfPolicy*: EngineColumnFamilyPolicy

proc initEngineContext*(
    path: string;
    descriptors = DatabaseColumnFamilyDescriptors;
    dbOptions = defaultEngineDbOptions();
    cfPolicy = defaultColumnFamilyPolicy()): EngineContext =
  result = EngineContext(
    path: path,
    descriptors: @descriptors,
    dbOptions: dbOptions,
    cfPolicy: cfPolicy,
  )

proc selectedDescriptors*(context: EngineContext): seq[DatabaseColumnFamilyDescriptor] =
  context.cfPolicy.selectedColumnFamilies(context.descriptors)

proc selectedDescriptorNames*(context: EngineContext): seq[string] =
  context.cfPolicy.selectedColumnFamilyNames(context.descriptors)

proc withPath*(context: EngineContext; path: string): EngineContext =
  result = context
  result.path = path

proc withDbOptions*(context: EngineContext; dbOptions: EngineDbOptions): EngineContext =
  result = context
  result.dbOptions = dbOptions

proc withColumnFamilyPolicy*(
    context: EngineContext; policy: EngineColumnFamilyPolicy): EngineContext =
  result = context
  result.cfPolicy = policy
