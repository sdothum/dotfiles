import std/[unittest, sequtils]
import ../x11/realize

suite "C-compatible unmanaged-destroy client-list publication plan":
  const clientList = 0x100'u32
  const stackingList = 0x101'u32

  test "physical root order filters decorations and unmanaged children":
    let order = projectManagedRootOrder(
        @[0x300'u32, 0x202'u32, 0x400'u32, 0x201'u32],
        @[0x201'u32, 0x202'u32])
    check order == @[0x202'u32, 0x201'u32]

  test "two clients are cleared then appended in physical root order":
    let plan = clientListMutationPlan(@[0x202'u32, 0x201'u32],
        clientList, stackingList)
    check plan.len == 6
    check plan[0].kind == clmkDelete
    check plan[0].property == clientList
    check plan[1].kind == clmkDelete
    check plan[1].property == stackingList
    check plan[2].kind == clmkAppend
    check plan[2].property == clientList
    check plan[2].window == 0x202'u32
    check plan[3].kind == clmkAppend
    check plan[3].property == stackingList
    check plan[3].window == 0x202'u32
    check plan[4].kind == clmkAppend
    check plan[4].property == clientList
    check plan[4].window == 0x201'u32
    check plan[5].kind == clmkAppend
    check plan[5].property == stackingList
    check plan[5].window == 0x201'u32

  test "already-current and stale properties receive the same complete rewrite":
    let physicalOrder = @[0x202'u32, 0x201'u32]
    let stalePlan = clientListMutationPlan(physicalOrder,
        clientList, stackingList)
    let currentPlan = clientListMutationPlan(physicalOrder,
        clientList, stackingList)
    check stalePlan == currentPlan
    check stalePlan.countIt(it.kind == clmkDelete) == 2
    check stalePlan.countIt(it.kind == clmkAppend) == 4

  test "empty order deletes both properties and appends nothing":
    let plan = clientListMutationPlan([], clientList, stackingList)
    check plan.len == 2
    check plan[0].kind == clmkDelete
    check plan[0].property == clientList
    check plan[1].kind == clmkDelete
    check plan[1].property == stackingList

  test "single client appends to both properties after both deletes":
    let plan = clientListMutationPlan(@[0x201'u32],
        clientList, stackingList)
    check plan.len == 4
    check plan[0].kind == clmkDelete
    check plan[1].kind == clmkDelete
    check plan[2].kind == clmkAppend
    check plan[2].property == clientList
    check plan[2].window == 0x201'u32
    check plan[3].kind == clmkAppend
    check plan[3].property == stackingList
    check plan[3].window == 0x201'u32
