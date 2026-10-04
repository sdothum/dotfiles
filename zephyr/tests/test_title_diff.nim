import std/unittest

import ../wm/title_diff

suite "semantic title diff":
  test "same identity with a changed effective title emits one transition":
    let previous = @[ObservedTitle(winid: "0x1", token: "client-a",
      title: "A", available: true)]
    let current = @[ObservedTitle(winid: "0x1", token: "client-a",
      title: "B", available: true)]
    let changes = diffTitleChanges(previous, current)
    check changes.len == 1
    check changes[0].oldTitle == "A"
    check changes[0].newTitle == "B"

  test "unchanged effective title suppresses repeated property notifications":
    let state = @[ObservedTitle(winid: "0x1", token: "client-a",
      title: "B", available: true)]
    check diffTitleChanges(state, state).len == 0

  test "XID replacement is a lifecycle change rather than a title transition":
    let previous = @[ObservedTitle(winid: "0x1", token: "client-a",
      title: "A", available: true)]
    let current = @[ObservedTitle(winid: "0x1", token: "client-b",
      title: "B", available: true)]
    check diffTitleChanges(previous, current).len == 0

  test "baseline or unavailable title does not synthesize a transition":
    let baseline = @[ObservedTitle(winid: "0x1", token: "client-a",
      title: "A", available: true)]
    check diffTitleChanges(newSeq[ObservedTitle](), baseline).len == 0
    let unavailable = @[ObservedTitle(winid: "0x1", token: "client-a",
      title: "", available: false)]
    check diffTitleChanges(unavailable, baseline).len == 0

  test "same effective title from a different source needs no event":
    let oldTitle = @[ObservedTitle(winid: "0x1", token: "client-a",
      title: "same", available: true)]
    let effectiveNewTitle = @[ObservedTitle(winid: "0x1", token: "client-a",
      title: "same", available: true)]
    check diffTitleChanges(oldTitle, effectiveNewTitle).len == 0
