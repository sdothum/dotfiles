import std/[unittest, sequtils]
import ../model/[types, state, lifecycle, geometry]

let epoch = ProcessEpoch(hi: 0x7d3c4b7'u64, lo: 0x1913'u64)
let bounds = GeometryBounds(x: 0, y: 0, width: 1280, height: 900)

suite "diagnostic private zoom command ordering":
  test "Full and Monocle commands retain the outer focus-and-raise phase":
    for opcode in [19'u32, 20'u32]:
      var state = newWmState()
      let client = state.addRuntimeClient(epoch, WindowId(0x800001),
          WindowId(0x900001), RawGroup(1), 80, 90, 400, 250).state
      let words = if opcode == 19:
          [0'u32, client.window.raw, 0'u32, 0'u32]
        else:
          [client.window.raw, 0'u32, 0'u32, 0'u32]
      let result = state.applyPrivateCommand(epoch,
          PrivateSemanticInput(opcode: opcode, words: words,
            observations: WmInput(geometryBounds: bounds),
            hasObservations: true))
      let kinds = result.transition.effects.mapIt(it.kind)
      check result.disposition == pcdSemanticAccepted
      check kinds.count(weRaiseClient) == 1
      check kinds[^1] == weRaiseClient
