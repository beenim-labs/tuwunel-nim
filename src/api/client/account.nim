## client/account — api module.
##
## Ported from Rust api/client/account.rs

import std/[options, json, tables, strutils]

const
  RustPath* = "api/client/account.rs"
  RustCrate* = "api"

proc changePasswordRoute*() =
  ## Ported from `change_password_route`.
  discard

proc whoamiRoute*() =
  ## Ported from `whoami_route`.
  discard

proc deactivateRoute*() =
  ## Ported from `deactivate_route`.
  discard

proc thirdPartyRoute*(body: Ruma<get_3pids::v3::Request>): get_3pids::v3::Response =
  ## Ported from `third_party_route`.
  discard

proc request3PidManagementTokenViaEmailRoute*(Body: Ruma<request_3pid_management_token_via_email::v3::Request>): request_3pid_management_token_via_email::v3::Response =
  ## Ported from `request_3pid_management_token_via_email_route`.
  discard

proc request3PidManagementTokenViaMsisdnRoute*(Body: Ruma<request_3pid_management_token_via_msisdn::v3::Request>): request_3pid_management_token_via_msisdn::v3::Response =
  ## Ported from `request_3pid_management_token_via_msisdn_route`.
  discard
