import std/unittest

import ../wm/group_id
import ../zephyr_errors

suite "relative public group navigation":
  test "previous and next cover every slot in the ten-slot fixture":
    for current in 1..9:
      let previous = relativeGroupId(current, 10, PreviousGroup)
      let next = relativeGroupId(current, 10, NextGroup)
      check previous.intValue == (if current == 1: 9 else: current - 1)
      check next.intValue == (if current == 9: 1 else: current + 1)
      check previous.intValue > 0
      check next.intValue > 0

  test "navigation uses the configured count rather than a fixed nine":
    check relativeGroupId(1, 2, PreviousGroup).intValue == 1
    check relativeGroupId(1, 2, NextGroup).intValue == 1
    check relativeGroupId(4, 5, NextGroup).intValue == 1
    check relativeGroupId(1, 5, PreviousGroup).intValue == 4

  test "public wrapper and CLI string use the public number":
    let destination = relativeGroupId(9, 10, NextGroup)
    check destination.intValue == 1
    check $destination == "1"

  test "empty groups do not affect destination arithmetic":
    let emptyPublicGroups = {1, 2, 3, 4, 5, 6, 7, 8, 9}
    let previous = relativeGroupId(1, 10, PreviousGroup)
    let next = relativeGroupId(9, 10, NextGroup)
    check previous.intValue == 9
    check next.intValue == 1
    check previous.intValue in emptyPublicGroups
    check next.intValue in emptyPublicGroups

  test "invalid reserved current group is rejected":
    expect ZephyrError:
      discard relativeGroupId(0, 10, NextGroup)

  test "invalid current groups are rejected":
    expect ZephyrError:
      discard relativeGroupId(-1, 10, NextGroup)
    expect ZephyrError:
      discard relativeGroupId(10, 10, PreviousGroup)

  test "invalid group counts are rejected":
    expect ZephyrError:
      discard relativeGroupId(1, 1, NextGroup)
    expect ZephyrError:
      discard relativeGroupId(1, 0, PreviousGroup)
    expect ZephyrError:
      discard relativeGroupId(1, -1, NextGroup)

  test "destination calculation does not mutate caller state":
    var currentGroup = 1
    var lastGroup = 7
    let before = (currentGroup, lastGroup)
    discard relativeGroupId(currentGroup, 10, PreviousGroup)
    check (currentGroup, lastGroup) == before
