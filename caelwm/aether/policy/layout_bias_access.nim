import std/options

import ../zephyr_errors
import ../wm/daemon_client
import ./layout_bias


# Reads authoritative layout bias from resident policy state or daemon IPC.
# Call once at an operation boundary and propagate the captured value explicitly.
# Raises an error if the remote query fails or returns an invalid response.

proc bias*(): LayoutBias =
  let resident = localBias()
  if resident.isSome:
    return resident.get
  let reply = queryDaemon(RequestQueryLayoutBias)
  if not reply.ok:
    raiseZephyrError("layout bias: " & reply.error)
  if reply.responseKind != RequestQueryLayoutBias:
    raiseZephyrError("layout bias: unexpected response")
  parseLayoutBias(reply.body)
