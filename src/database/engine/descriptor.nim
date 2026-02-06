## Descriptor helpers for engine open policies.

import ../generated_column_family_descriptors

proc requiredDescriptors*(
    descriptors = DatabaseColumnFamilyDescriptors): seq[DatabaseColumnFamilyDescriptor] =
  result = @[]
  for descriptor in descriptors:
    if descriptor.dropped or descriptor.ignored:
      continue
    result.add(descriptor)

proc droppedDescriptors*(
    descriptors = DatabaseColumnFamilyDescriptors): seq[DatabaseColumnFamilyDescriptor] =
  result = @[]
  for descriptor in descriptors:
    if descriptor.dropped:
      result.add(descriptor)

proc ignoredDescriptors*(
    descriptors = DatabaseColumnFamilyDescriptors): seq[DatabaseColumnFamilyDescriptor] =
  result = @[]
  for descriptor in descriptors:
    if descriptor.ignored:
      result.add(descriptor)

proc descriptorNames*(
    descriptors: openArray[DatabaseColumnFamilyDescriptor]): seq[string] =
  result = @[]
  for descriptor in descriptors:
    result.add(descriptor.name)

proc hasDescriptor*(name: string; descriptors = DatabaseColumnFamilyDescriptors): bool =
  for descriptor in descriptors:
    if descriptor.name == name:
      return true
  false

proc descriptorCount*(descriptors = DatabaseColumnFamilyDescriptors): int =
  descriptors.len
