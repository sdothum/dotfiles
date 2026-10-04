## Validated public, one-based group identifiers.
## The WM reserves slot 0, so its reported count is an exclusive upper bound.
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
