## Validated public, one-based group identifiers.
## The WM reserves slot 0, so its reported count is an exclusive upper bound.

import ../zephyr_errors

type
  PublicGroupId* = object
    value: int

proc publicGroupId*(value, groupCount: int,
    context = "group"): PublicGroupId =
  if value < 1:
    quit(context & ": group must be > 0")
  if value >= groupCount:
    quit(context & ": invalid group id " & $value)
  PublicGroupId(value: value)

proc intValue*(group: PublicGroupId): int = group.value

proc `$`*(group: PublicGroupId): string = $group.value

type GroupNavigationDirection* = enum
  PreviousGroup,
  NextGroup

proc relativeGroupId*(currentGroup, groupCount: int,
    direction: GroupNavigationDirection): PublicGroupId =
  if groupCount < 2:
    raiseZephyrError("group navigation: invalid group count " & $groupCount)
  if currentGroup < 1 or currentGroup >= groupCount:
    raiseZephyrError("group navigation: invalid current group " & $currentGroup)

  let lastPublicGroup = groupCount - 1
  var destination: int
  case direction
  of PreviousGroup:
    destination = if currentGroup == 1: lastPublicGroup else: currentGroup - 1
  of NextGroup:
    destination = if currentGroup == lastPublicGroup: 1 else: currentGroup + 1

  PublicGroupId(value: destination)
