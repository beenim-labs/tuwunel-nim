type
  AdminStatus* = object
    enabled*: bool

proc defaultAdminStatus*(): AdminStatus =
  AdminStatus(enabled: false)
