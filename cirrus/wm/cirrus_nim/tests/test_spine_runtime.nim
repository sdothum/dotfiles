## Include the existing coordinator to exercise its private final realization
## boundary without adding an exported production test hook.
import std/unittest
include ../runtime/coordinator

{.compile: "support/mock_runtime_frame.c".}
proc resetRequests() {.importc: "randr_mock_reset_requests", cdecl.}
proc configureCalls(): cint {.importc: "randr_mock_configure_calls", cdecl.}
proc configureWindow(index: cint): uint32 {.importc: "randr_mock_configure_window", cdecl.}
proc configureValue(index, field: cint): uint32 {.importc: "randr_mock_configure_value", cdecl.}

suite "spine geometry at the final runtime realization boundary":
  test "per-monitor recalculation retains each style before ConfigureWindow":
    for style in 0'u32..5'u32:
      var wm = newWmState()
      wm.config.borderStyle = style
      wm.config.outerBorderWidth = 6
      wm.config.innerBorderWidth = 4
      discard wm.addAdoptedClient(ProcessEpoch(hi:1,lo:1), WindowId(0x100),
          true, RawGroup(1), wsvNormal,160,180,160,100)
      var client = wm.lookup(WindowId(0x100)).get
      client.decoration = some(WindowId(0x200))
      discard wm.replaceClient(client)
      var r = LifecycleCoordinator(state:addr wm,connection:XConnection(root:1,
          screenWidth:1024,screenHeight:768,randrEventBase: -1))
      cast[ptr pointer](addr r.connection)[] = cast[pointer](1)
      let expected = case style
        of 1: Geometry(x:150,y:180,width:10,height:100)
        of 2: Geometry(x:160,y:170,width:160,height:10)
        of 3: Geometry(x:160,y:280,width:160,height:10)
        of 4: Geometry(x:320,y:180,width:10,height:100)
        else: Geometry(x:150,y:170,width:180,height:120)
      resetRequests()
      r.realizeEffects([WmEffect(kind:weConfigureDecoration,window:WindowId(0x100),
          decoration:WindowId(0x200),geometry:expected)], false)
      check configureCalls() == 1
      check configureWindow(0) == 0x200
      check configureValue(0,0) == uint32(expected.x)
      check configureValue(0,1) == uint32(expected.y)
      check configureValue(0,2) == expected.width
      check configureValue(0,3) == expected.height
