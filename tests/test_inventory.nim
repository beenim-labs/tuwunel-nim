import std/unittest
import api/generated_route_inventory
import core/generated_config_keys
import database/generated_column_families
import core/generated_function_inventory

suite "Baseline parity inventory":
  test "route counts are frozen":
    check ClientRumaRoutes.len == 149
    check ServerRumaRoutes.len == 29
    check ManualRoutes.len == 29

  test "config and database inventories exist":
    check ConfigKeys.len > 0
    check DatabaseColumnFamilies.len > 0

  test "rust function inventory summary exists":
    check RustFunctionTotal > 0
    check RustCrateFunctionCounts.len > 0
