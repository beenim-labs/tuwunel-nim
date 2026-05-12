const
  RustPath* = "service/users/ldap.rs"
  RustCrate* = "service"

type
  LdapSearchResult* = object
    userId*: string
    displayName*: string
    email*: string

proc ldapEnabled*(): bool =
  false

proc ldapSearch*(term: string): seq[LdapSearchResult] =
  discard term
  @[]
