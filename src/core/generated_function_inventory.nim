## Generated function inventory — compile-time function registration.
##
## Ported from Rust function inventory (used for admin commands, etc.)

import std/tables

const
  RustPath* = "core/generated_function_inventory"
  RustCrate* = "core"

type
  FunctionEntry* = object
    name*: string
    module*: string
    description*: string

var functionRegistry* = initTable[string, FunctionEntry]()

proc registerFunction*(name, module, description: string) =
  functionRegistry[name] = FunctionEntry(
    name: name, module: module, description: description,
  )

proc getFunction*(name: string): FunctionEntry =
  if name in functionRegistry:
    functionRegistry[name]
  else:
    raise newException(KeyError, "Function not found: " & name)

proc allFunctions*(): seq[FunctionEntry] =
  for _, entry in functionRegistry:
    result.add entry
