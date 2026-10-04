import std/unittest

import ../wm/layer_types
import ../wm/native_ipc as ipc

suite "canonical layer domain type":
  test "normal remains the safe default":
    var layer: Layer
    check layer == Normal

  test "wire values explicitly match cirrus protocol values":
    check layerWireValue(Normal) == 0'u32
    check layerWireValue(Above) == 1'u32
    check layerWireValue(Overlay) == 2'u32

  test "native layer API rejects arbitrary text at compile time":
    static:
      doAssert not compiles(ipc.layer(ipc.WindowId(1), "Above"))
