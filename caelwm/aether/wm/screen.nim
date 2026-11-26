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


# Reads configured UI directory values and derives usable screen spacing metrics.

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
    of "gap_width grid":
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


# Returns the configured gap as decimal text, rejecting arguments in the CLI overload.

proc gap*(args: seq[string]): string =
  requireNoArgs("screen gap", args)
  $metrics().gap


# Returns the derived indent as decimal text, rejecting arguments in the CLI overload.

proc indent*(args: seq[string]): string =
  requireNoArgs("screen indent", args)
  $metrics().indent


# Returns the derived margin as decimal text, rejecting arguments in the CLI overload.

proc margin*(args: seq[string]): string =
  requireNoArgs("screen margin", args)
  $metrics().margin


# Returns the panel spacing as decimal text, rejecting arguments in the CLI overload.

proc panel*(args: seq[string]): string =
  requireNoArgs("screen panel", args)
  $metrics().panel


# Returns top spacing as decimal text, rejecting arguments in the CLI overload.

proc top*(args: seq[string]): string =
  requireNoArgs("screen top", args)
  $metrics().top


# Returns bottom spacing as decimal text, rejecting arguments in the CLI overload.

proc bottom*(args: seq[string]): string =
  requireNoArgs("screen bottom", args)
  $metrics().bottom

#
# Native Nim convenience overloads
#


# Returns the configured gap as decimal text, rejecting arguments in the CLI overload.

proc gap*(): string =
  gap(@[])


# Returns the derived indent as decimal text, rejecting arguments in the CLI overload.

proc indent*(): string =
  indent(@[])


# Returns the derived margin as decimal text, rejecting arguments in the CLI overload.

proc margin*(): string =
  margin(@[])


# Returns the panel spacing as decimal text, rejecting arguments in the CLI overload.

proc panel*(): string =
  panel(@[])


# Returns top spacing as decimal text, rejecting arguments in the CLI overload.

proc top*(): string =
  top(@[])


# Returns bottom spacing as decimal text, rejecting arguments in the CLI overload.

proc bottom*(): string =
  bottom(@[])

#
# Dispatch
#


# Prints the requested screen spacing metric and rejects unknown actions.

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
