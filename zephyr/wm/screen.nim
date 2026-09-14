import std/os
import std/strutils

import compat

type ScreenMetrics* = object
  gap*: int
  margin*: int
  top*: int
  bottom*: int
  panel*: int
  indent*: int

proc metrics*(): ScreenMetrics =
  proc value(path: string): int =
    for kind, entry in walkDir(path):
      if kind == pcDir:
        return parseInt(extractFilename(entry))

    return 0

  for kind, entry in walkDir(getEnv("WMSE") / "ui"):
    if kind != pcDir:
      continue

    case extractFilename(entry)
    of "gap_width bottom":
      result.bottom = value(entry)
    of "gap_width top":
      result.top = value(entry)
    of "gap_width left":
      result.margin = value(entry)
    of "grid_gap_width":
      result.gap = value(entry)
    else:
      discard

  for kind, entry in walkDir(getEnv("WMSE") / "panel"):
    if kind != pcDir:
      continue

    case extractFilename(entry)
    of "height":
      result.panel = value(entry)
    of "indent":
      result.indent = value(entry)
    else:
      discard

#
# Queries
#

proc gap*(args: seq[string]): string =
  requireNoArgs("screen gap", args)
  $metrics().gap

proc indent*(args: seq[string]): string =
  requireNoArgs("screen indent", args)
  $metrics().indent

proc margin*(args: seq[string]): string =
  requireNoArgs("screen margin", args)
  $metrics().margin

proc panel*(args: seq[string]): string =
  requireNoArgs("screen panel", args)
  $metrics().panel

proc top*(args: seq[string]): string =
  requireNoArgs("screen top", args)
  $metrics().top

proc bottom*(args: seq[string]): string =
  requireNoArgs("screen bottom", args)
  $metrics().bottom

#
# Native Nim convenience overloads
#

proc gap*(): string =
  gap(@[])

proc indent*(): string =
  indent(@[])

proc margin*(): string =
  margin(@[])

proc panel*(): string =
  panel(@[])

proc top*(): string =
  top(@[])

proc bottom*(): string =
  bottom(@[])

#
# Dispatch
#

proc dispatch*(verb: string, rest: seq[string]) =
  case verb
  of "gap":
    echo gap(rest)
  of "indent":
    echo indent(rest)
  of "margin":
    echo margin(rest)
  of "panel":
    echo panel(rest)
  of "top":
    echo top(rest)
  of "bottom":
    echo bottom(rest)
  else:
    quit("unknown screen action")
