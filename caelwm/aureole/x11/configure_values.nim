## Pure packing for X ConfigureWindow's mask-ordered value list.

type
  PackedGeometryValues* = object
    mask*: uint32
    count*: int
    values*: array[4, uint32]

proc packGeometryValues*(mask: uint16; x, y: int32;
                         width, height: uint32): PackedGeometryValues =
  ## XCB serializes values in ascending mask-bit order: X, Y, WIDTH, HEIGHT.
  result.mask = uint32(mask and 0x000f'u16)
  if (mask and 1'u16) != 0:
    result.values[result.count] = uint32(x and 0xffff'i32)
    inc result.count
  if (mask and 2'u16) != 0:
    result.values[result.count] = uint32(y and 0xffff'i32)
    inc result.count
  if (mask and 4'u16) != 0:
    if width == 0 or width > uint32(high(uint16)):
      raise newException(ValueError, "X ConfigureWindow width is outside uint16 range")
    result.values[result.count] = width
    inc result.count
  if (mask and 8'u16) != 0:
    if height == 0 or height > uint32(high(uint16)):
      raise newException(ValueError, "X ConfigureWindow height is outside uint16 range")
    result.values[result.count] = height
    inc result.count

proc packConfigureRequestValues*(mask: uint16; x, y: int16;
                                 width, height, borderWidth: uint16;
                                 sibling: uint32; stackMode: uint8):
                                 array[7, uint32] =
  ## X ConfigureWindow values follow ascending mask-bit order. The caller
  ## supplies only fields that were present in the received request mask.
  var index = 0
  if (mask and (1'u16 shl 0)) != 0:
    result[index] = uint32(cast[uint16](x)); inc index
  if (mask and (1'u16 shl 1)) != 0:
    result[index] = uint32(cast[uint16](y)); inc index
  if (mask and (1'u16 shl 2)) != 0:
    result[index] = uint32(width); inc index
  if (mask and (1'u16 shl 3)) != 0:
    result[index] = uint32(height); inc index
  if (mask and (1'u16 shl 4)) != 0:
    result[index] = uint32(borderWidth); inc index
  if (mask and (1'u16 shl 5)) != 0:
    result[index] = sibling; inc index
  if (mask and (1'u16 shl 6)) != 0:
    result[index] = uint32(stackMode)
