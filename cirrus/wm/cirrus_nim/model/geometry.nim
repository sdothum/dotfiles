## X-free geometry arithmetic matching the Stage 0 C oracle.

import std/[math, options]
import ./types
import ./state

proc cHypotf(x, y: cfloat): cfloat {.importc: "hypotf", header: "<math.h>".}
proc cAtan2f(y, x: cfloat): cfloat {.importc: "atan2f", header: "<math.h>".}

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

proc decorationGeometry*(client: Geometry; config: WmConfiguration): Geometry =
  let border = config.outerBorderWidth
  let gap = config.innerBorderWidth
  case config.borderStyle
  of 1'u32:
    result = Geometry(x: client.x - border - gap, y: client.y,
        width: cast[uint32](border + gap), height: client.height)
  of 2'u32:
    result = Geometry(x: client.x, y: client.y - border - gap,
        width: client.width, height: cast[uint32](border + gap))
  of 3'u32:
    result = Geometry(x: client.x, y: client.y + int32(client.height),
        width: client.width, height: cast[uint32](border + gap))
  of 4'u32:
    result = Geometry(x: client.x + int32(client.width), y: client.y,
        width: cast[uint32](border + gap), height: client.height)
  else:
    let extent = border + gap
    result = Geometry(x: client.x - extent, y: client.y - extent,
        width: cast[uint32](int64(client.width) + int64(2 * extent)),
        height: cast[uint32](int64(client.height) + int64(2 * extent)))

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
  # C stores the post-hint result in uint16_t. Keep its modulo narrowing for
  # relative IPC resizes that exceed the representable client dimension.
  result.width = uint32(width and int64(high(uint16)))
  result.height = uint32(height and int64(high(uint16)))

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

proc cardinalFocusCandidate*(focused: ClientState;
    clients: openArray[ClientState]; direction: uint32): Option[WindowId] =
  ## Reproduce focus.c:cardinal_focus candidate filtering and score ordering.
  ## Direction values are NORTH=0, EAST=1, SOUTH=2, WEST=3.
  if clients.len == 0: return none(WindowId)
  if direction > 3'u32: return none(WindowId)
  let focusLeft = int64(cast[int16](focused.geometry.x))
  let focusTop = int64(cast[int16](focused.geometry.y))
  let focusWidth = int64(cast[uint16](focused.geometry.width))
  let focusHeight = int64(cast[uint16](focused.geometry.height))
  let focusRight = focusLeft + focusWidth
  let focusBottom = focusTop + focusHeight
  let focusCenterX = focusLeft + focusWidth div 2
  let focusCenterY = focusTop + focusHeight div 2
  var bestScore = -1'f32

  # focus.c prepends every eligible window to valid_windows while scanning
  # win_list, so its scoring pass sees eligible clients in reverse list order.
  for clientIndex in countdown(clients.high, 0):
    let candidate = clients[clientIndex]
    if candidate.window == focused.window or not candidate.mapped: continue
    let left = int64(cast[int16](candidate.geometry.x))
    let top = int64(cast[int16](candidate.geometry.y))
    let width = int64(cast[uint16](candidate.geometry.width))
    let height = int64(cast[uint16](candidate.geometry.height))
    let right = left + width
    let bottom = top + height
    let centerX = left + width div 2
    let centerY = top + height div 2

    # C first applies strict/inclusive center-coordinate half-plane filters.
    case direction
    of 0'u32:
      if centerY >= focusCenterY: continue
    of 1'u32:
      if centerX < focusCenterX: continue
    of 2'u32:
      if centerY < focusCenterY: continue
    of 3'u32:
      if centerX >= focusCenterX: continue
    else:
      continue

    let dx = float32(centerX - focusCenterX)
    let dy = float32(centerY - focusCenterY)
    var distance = cHypotf(dx, dy).float32
    let radians = cAtan2f(dx, dy)
    let angle = float32(float64(radians) *
        (180.0 / 3.14159265358979323846))
    let delta10 = case direction
      of 0'u32: angle >= 170'f32 or angle <= -170'f32
      of 1'u32: angle <= 100'f32 and angle > 80'f32
      of 2'u32: abs(angle) <= 10'f32
      of 3'u32: angle <= -80'f32 and angle >= -100'f32
      else: false
    let delta25 = case direction
      of 0'u32: angle >= 155'f32 or angle <= -155'f32
      of 1'u32: angle <= 115'f32 and angle > 65'f32
      of 2'u32: abs(angle) <= 25'f32
      of 3'u32: angle <= -65'f32 and angle >= -115'f32
      else: false
    let delta35 = case direction
      of 0'u32: angle >= 145'f32 or angle <= -145'f32
      of 1'u32: angle <= 125'f32 and angle > 55'f32
      of 2'u32: abs(angle) <= 35'f32
      of 3'u32: angle <= -55'f32 and angle >= -125'f32
      else: false
    let delta50 = case direction
      of 0'u32: angle >= 130'f32 or angle <= -130'f32
      of 1'u32: angle <= 140'f32 and angle > 40'f32
      of 2'u32: abs(angle) <= 50'f32
      of 3'u32: angle <= -40'f32 and angle >= -140'f32
      else: false
    if not (delta10 or delta25 or delta35 or delta50): continue

    # Preserve the C corner-in-rectangle overlap test (including its inclusive
    # edges), rather than substituting a conventional rectangle intersection.
    let xOverlaps =
        (focusLeft <= left and focusRight >= left) or
        (focusLeft <= right and focusRight >= right)
    let yOverlaps =
        (focusTop <= top and focusBottom >= top) or
        (focusTop <= bottom and focusBottom >= bottom)
    let overlaps = xOverlaps and yOverlaps

    if delta10:
      if overlaps: distance = float32(float64(distance) * 0.1)
      distance = float32(float64(distance) * 0.80)
    elif delta25:
      if overlaps: distance = float32(float64(distance) * 0.1)
      distance = float32(float64(distance) * 0.85)
    elif delta35:
      if overlaps: distance = float32(float64(distance) * 0.1)
      distance = float32(float64(distance) * 0.9)
    else:
      if overlaps: distance = float32(float64(distance) * 0.1)
      distance = float32(float64(distance) * 3.0)

    # C gives a further 10% preference when the candidate center lies within
    # the focused window's horizontal/vertical span for this direction.
    let aligned = case direction
      of 0'u32, 2'u32: focusLeft <= centerX and focusRight >= centerX
      of 1'u32, 3'u32: focusTop <= centerY and focusBottom >= centerY
      else: false
    if aligned: distance = float32(float64(distance) * 0.9)

    # Strict comparison intentionally leaves equal-score ties with the first
    # candidate in C's reversed valid_windows order (reverse managed order).
    if bestScore == -1'f32 or distance < bestScore:
      bestScore = distance
      result = some(candidate.window)
