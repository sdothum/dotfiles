import std/unittest

import ../wm/panel_notification
import ../wm/snapshot_diff

suite "panel notification mapping":
  test "focus refreshes desktop only":
    let targets = panelRefreshTargets(@[
      SnapshotChange(kind: FocusChanged)
    ])
    check targets.desktop
    check not targets.system

  test "current refreshes both panels":
    let targets = panelRefreshTargets(@[
      SnapshotChange(kind: CurrentChanged)
    ])
    check targets.desktop
    check targets.system

  test "client and membership changes refresh both panels":
    for kind in [ClientAdded, ClientRemoved, GroupChanged, MappedChanged]:
      let targets = panelRefreshTargets(@[SnapshotChange(kind: kind)])
      check targets.desktop
      check targets.system

  test "null-group changes refresh desktop only":
    let targets = panelRefreshTargets(@[
      SnapshotChange(kind: NullGroupChanged)
    ])
    check targets.desktop
    check not targets.system

  test "empty diff does not notify either panel":
    let targets = panelRefreshTargets(@[])
    check not targets.desktop
    check not targets.system

  test "multiple changes remain coalesced":
    let targets = panelRefreshTargets(@[
      SnapshotChange(kind: FocusChanged),
      SnapshotChange(kind: CurrentChanged),
      SnapshotChange(kind: GroupChanged)
    ])
    check targets.desktop
    check targets.system
