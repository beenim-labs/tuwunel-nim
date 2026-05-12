const
  RustPath* = "api/client/sync/v5/extensions.rs"
  RustCrate* = "api"

import std/json

import api/client/sync/v5/extensions/[
  account_data,
  e2ee,
  receipts,
  to_device,
  typing,
]

export account_data, e2ee, receipts, to_device, typing

type
  ExtensionEnable* = object
    accountData*: bool
    receipts*: bool
    typing*: bool
    toDevice*: bool
    e2ee*: bool

proc allExtensionsEnabled*(): ExtensionEnable =
  ExtensionEnable(accountData: true, receipts: true, typing: true, toDevice: true, e2ee: true)

proc extensionsPayload*(
  enabled: ExtensionEnable;
  accountData: JsonNode = nil;
  receipts: JsonNode = nil;
  typing: JsonNode = nil;
  toDevice: JsonNode = nil;
  e2ee: JsonNode = nil
): JsonNode =
  result = newJObject()
  if enabled.accountData:
    result["account_data"] = if accountData.isNil: accountDataPayload() else: accountData.copy()
  if enabled.receipts:
    result["receipts"] = if receipts.isNil: receiptsPayload() else: receipts.copy()
  if enabled.typing:
    result["typing"] = if typing.isNil: typingPayload() else: typing.copy()
  if enabled.toDevice:
    result["to_device"] = if toDevice.isNil: toDevicePayload(0, []) else: toDevice.copy()
  if enabled.e2ee:
    result["e2ee"] = if e2ee.isNil: e2eePayload() else: e2ee.copy()
