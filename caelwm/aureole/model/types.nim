## X-free identities and startup state used by the authoritative model.

import std/options

type
  WindowId* = distinct uint32
  ClientId* = distinct uint64
  ClientGeneration* = distinct uint64
  RawGroup* = distinct uint32

  WindowLayer* = enum
    wlNormal, wlAbove, wlOverlay

  EwmhStateAtom* = enum
    esaAbove, esaFullscreen, esaMaximizedVert, esaMaximizedHorz, esaUnknown

  StackPriority* = enum
    spNormal, spAbove, spZoomed, spOverlay

  StackingLayerSnapshot* = object
    window*, decoration*: WindowId
    layer*: WindowLayer
    maxed*, monocled*: bool

  Geometry* = object
    x*, y*: int32
    width*, height*: uint32

  ResizeHints* = object
    minWidth*, minHeight*: uint32
    widthIncrement*, heightIncrement*: uint32

  PointerOperation* = enum
    poNone, poMove, poResizeSide, poResizeCorner

  PointerAllowMode* = enum
    pamSyncPointer, pamReplayPointer

  PointerInteraction* = object
    operation*: PointerOperation
    clientId*: ClientId
    startX*, startY*: int16
    startGeometry*: Geometry
    handle*: uint8
    button*: uint8
    active*: bool

  ProcessEpoch* = object
    hi*: uint64
    lo*: uint64

  ClientToken* = object
    epoch*: ProcessEpoch
    generation*: ClientGeneration

  WmStateValue* = enum
    wsvAbsent,
    wsvNormal,
    wsvIconic,
    wsvWithdrawn,
    wsvOther

  ClientState* = object
    id*: ClientId
    window*: WindowId
    token*: ClientToken
    mapped*: bool
    group*: RawGroup
    startupWmState*: WmStateValue
    decoration*: Option[WindowId]
    runtimeManaged*: bool
    groupMapPending*: bool
    groupUnmapPending*: bool
    geometry*: Geometry
    origGeometry*: Geometry
    resizeHints*: ResizeHints
    maxed*, hmaxed*, vmaxed*, monocled*: bool
    layer*: WindowLayer
    layerExplicit*: bool
    setByUser*: bool

const NullGroup* = RawGroup(0xffffffff'u32)

proc `==`*(a, b: WindowId): bool {.borrow.}
proc `==`*(a, b: ClientId): bool {.borrow.}
proc `==`*(a, b: ClientGeneration): bool {.borrow.}
proc `==`*(a, b: RawGroup): bool {.borrow.}

proc raw*(id: WindowId): uint32 {.inline.} = uint32(id)
proc raw*(id: ClientId): uint64 {.inline.} = uint64(id)
proc raw*(generation: ClientGeneration): uint64 {.inline.} = uint64(generation)
proc raw*(group: RawGroup): uint32 {.inline.} = uint32(group)
proc x*(client: ClientState): int16 {.inline.} = int16(client.geometry.x)
proc y*(client: ClientState): int16 {.inline.} = int16(client.geometry.y)
proc width*(client: ClientState): uint16 {.inline.} = uint16(client.geometry.width)
proc height*(client: ClientState): uint16 {.inline.} = uint16(client.geometry.height)
