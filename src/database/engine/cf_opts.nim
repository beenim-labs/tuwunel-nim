## Engine column-family option policy.

import ../generated_column_family_descriptors

type
  EngineColumnFamilyPolicy* = object
    includeDropped*: bool
    includeIgnored*: bool

proc defaultColumnFamilyPolicy*(): EngineColumnFamilyPolicy =
  EngineColumnFamilyPolicy(includeDropped: false, includeIgnored: false)

proc shouldInclude*(
    policy: EngineColumnFamilyPolicy; descriptor: DatabaseColumnFamilyDescriptor): bool =
  if descriptor.dropped and not policy.includeDropped:
    return false
  if descriptor.ignored and not policy.includeIgnored:
    return false
  true

proc selectedColumnFamilies*(
    policy: EngineColumnFamilyPolicy; descriptors = DatabaseColumnFamilyDescriptors): seq[
    DatabaseColumnFamilyDescriptor] =
  result = @[]
  for descriptor in descriptors:
    if policy.shouldInclude(descriptor):
      result.add(descriptor)

proc selectedColumnFamilyNames*(
    policy: EngineColumnFamilyPolicy; descriptors = DatabaseColumnFamilyDescriptors): seq[string] =
  result = @[]
  for descriptor in policy.selectedColumnFamilies(descriptors):
    result.add(descriptor.name)

proc withDropped*(policy: EngineColumnFamilyPolicy; enabled = true): EngineColumnFamilyPolicy =
  result = policy
  result.includeDropped = enabled

proc withIgnored*(policy: EngineColumnFamilyPolicy; enabled = true): EngineColumnFamilyPolicy =
  result = policy
  result.includeIgnored = enabled
