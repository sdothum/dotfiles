import ../wm/group_id

proc requiresPublicGroupId(group: PublicGroupId) =
  discard group

static:
  doAssert not compiles(requiresPublicGroupId(1))

let first = publicGroupId(1, 8)
let last = publicGroupId(7, 8)
doAssert first.intValue == 1
doAssert last.intValue == 7
doAssert $first == "1"
