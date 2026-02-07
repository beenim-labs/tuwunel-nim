## Database map API surface.

import map/options
import map/open
import map/get
import map/put
import map/del
import map/contains
import map/count
import map/get_batch
import map/insert
import map/remove
import map/clear
import map/keys
import map/keys_prefix
import map/keys_from
import map/qry
import map/qry_batch
import map/stream
import map/stream_prefix
import map/stream_from
import map/rev_keys
import map/rev_keys_prefix
import map/rev_keys_from
import map/rev_stream
import map/rev_stream_prefix
import map/rev_stream_from
import map/watch
import map/compact

export options
export open
export get
export put
export del
export contains
export count
export get_batch
export insert
export remove
export clear
export keys
export keys_prefix
export keys_from
export qry
export qry_batch
export stream
export stream_prefix
export stream_from
export rev_keys
export rev_keys_prefix
export rev_keys_from
export rev_stream
export rev_stream_prefix
export rev_stream_from
export watch
export compact

type
  MapModuleInfo* = object
    name*: string
    featureCount*: int

proc mapModuleInfo*(): MapModuleInfo =
  MapModuleInfo(name: "database.map", featureCount: 27)

proc mapFeatureCount*(): int =
  mapModuleInfo().featureCount
