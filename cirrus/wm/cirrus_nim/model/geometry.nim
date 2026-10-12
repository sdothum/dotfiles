## X-free geometry arithmetic matching the Stage 0 C oracle.

import ./types

type
  GeometryBounds* = object
    x*, y*, width*, height*: int32
    borderExtent*: int32
    gapLeft*, gapRight*, gapTop*, gapBottom*: int32

  ConfigureMask* = object
    x*, y*, width*, height*: bool

proc decorationGeometry*(client: Geometry; border: int32): Geometry =
  Geometry(x: client.x - border, y: client.y - border,
      width: client.width + uint32(max(0, border * 2)),
      height: client.height + uint32(max(0, border * 2)))

proc fitConfigure*(geometry: Geometry; minimum: ResizeHints;
                   bounds: GeometryBounds): Geometry =
  ## Port of fit_on_screen: position correction, min clamp, then screen clamp.
  result = geometry
  let left = bounds.x
  let top = bounds.y
  let right = left + bounds.width
  let bottom = top + bounds.height
  let border = bounds.borderExtent
  if result.x > right or result.y > bottom or result.x < left or result.y < top:
    if result.x > right:
      result.x = right - int32(result.width) - 2 * border
    elif result.x < left:
      result.x = left
    if result.y > bottom:
      result.y = bottom - int32(result.height) - 2 * border
    elif result.y < top:
      result.y = top
  if minimum.minWidth != 0 and result.width < minimum.minWidth:
    result.width = minimum.minWidth
  if minimum.minHeight != 0 and result.height < minimum.minHeight:
    result.height = minimum.minHeight
  if int64(result.width) + int64(2 * border) > bounds.width:
    result.x = left
    result.width = uint32(max(0, bounds.width - 2 * border))
  elif result.x + int32(result.width) + 2 * border > right:
    result.x = right - int32(result.width) - 2 * border
  if int64(result.height) + int64(2 * border) > bounds.height:
    result.y = top
    result.height = uint32(max(0, bounds.height - 2 * border))
  elif result.y + int32(result.height) + 2 * border > bottom:
    result.y = bottom - int32(result.height) - 2 * border

proc resizeRelative*(geometry: Geometry; hints: ResizeHints;
                     deltaWidth, deltaHeight: int32;
                     useHints: bool): Geometry =
  result = geometry
  var width = int64(geometry.width)
  var height = int64(geometry.height)
  let proposedWidth = width + int64(deltaWidth)
  let proposedHeight = height + int64(deltaHeight)
  if proposedWidth > 0: width = proposedWidth
  if proposedHeight > 0: height = proposedHeight
  if hints.minWidth != 0 and width < int64(hints.minWidth): width = int64(hints.minWidth)
  if hints.minHeight != 0 and height < int64(hints.minHeight): height = int64(hints.minHeight)
  if useHints:
    let widthInc = max(1'u32, hints.widthIncrement)
    let heightInc = max(1'u32, hints.heightIncrement)
    width -= width mod int64(widthInc)
    height -= height mod int64(heightInc)
  result.width = uint32(max(0'i64, min(width, int64(high(uint16)))))
  result.height = uint32(max(0'i64, min(height, int64(high(uint16)))))

proc fitDecoration*(decoration: Geometry; bounds: GeometryBounds): Geometry =
  ## Safe geometric clipping corresponding to the visible intersection.
  result = decoration
  let right = int64(decoration.x) + int64(decoration.width)
  let bottom = int64(decoration.y) + int64(decoration.height)
  let maxRight = int64(bounds.x) + int64(bounds.width)
  let maxBottom = int64(bounds.y) + int64(bounds.height)
  if result.x < bounds.x:
    let delta = int64(bounds.x) - int64(result.x)
    result.x = bounds.x
    result.width = uint32(min(int64(high(uint32)), int64(result.width) + delta))
  if result.y < bounds.y:
    let delta = int64(bounds.y) - int64(result.y)
    result.y = bounds.y
    result.height = uint32(min(int64(high(uint32)), int64(result.height) + delta))
  if right > maxRight:
    # Match border.c: compute overflow from the pre-left-clipped right edge,
    # then subtract that amount from the already-expanded clipped width.
    result.width = uint32(max(0'i64, int64(result.width) -
        (right - maxRight)))
  if bottom > maxBottom:
    result.height = uint32(max(0'i64, int64(result.height) -
        (bottom - maxBottom)))

proc decorationClipWouldFailC*(decoration: Geometry;
                               bounds: GeometryBounds): bool =
  ## border.c subtracts right/bottom overflow from unsigned dimensions. If a
  ## frame starts beyond those edges, the result wraps and its ConfigureWindow
  ## request can fail. Preserve the observable old-frame behavior without
  ## emitting a wrapped or saturated dimension from Nim.
  let right = int64(bounds.x) + int64(bounds.width)
  let bottom = int64(bounds.y) + int64(bounds.height)
  result = int64(decoration.x) >= right or int64(decoration.y) >= bottom
