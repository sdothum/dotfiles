import std/options

import ../zephyr_errors

type LayoutBias* {.pure.} = enum
  Left = "left"
  Right = "right"

# Only Aetherd initializes this state. CLI processes always use daemon IPC.
# Kept separate from layouts to let the IPC handler use policy state without
# importing layout execution (which itself uses the daemon client).
var residentBias = none(LayoutBias)

proc initializeResidentBias*() =
  residentBias = some(LayoutBias.Left)

proc localBias*(): Option[LayoutBias] = residentBias

proc setResidentBias*(value: LayoutBias) =
  if residentBias.isNone:
    raiseZephyrError("layout bias: resident policy is not initialized")
  residentBias = some(value)

proc parseLayoutBias*(value: string): LayoutBias =
  case value
  of "left": LayoutBias.Left
  of "right": LayoutBias.Right
  else: raiseZephyrError("layout bias: expected left or right")
