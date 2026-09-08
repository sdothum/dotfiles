import compat
import std/strutils

type ScreenMetrics* = object
  gap*: int
  margin*: int
  top*: int
  panel*: int
  indent*: int

proc metrics*(): ScreenMetrics =
  let raw = shv("screen", @[])
  var seenGap, seenMargin, seenTop, seenPanel, seenIndent = false
  for line in raw.splitLines():
    let fields = line.split('=' , maxsplit = 1)
    if fields.len != 2:
      quit("screen metrics: malformed response")
    let value = try:
      parseInt(fields[1].strip())
    except ValueError:
      quit("screen metrics: malformed value for " & fields[0])
    case fields[0]
    of "GAP":
      if seenGap: quit("screen metrics: duplicate GAP")
      result.gap = value
      seenGap = true
    of "MARGIN":
      if seenMargin: quit("screen metrics: duplicate MARGIN")
      result.margin = value
      seenMargin = true
    of "TOP":
      if seenTop: quit("screen metrics: duplicate TOP")
      result.top = value
      seenTop = true
    of "PANEL_HEIGHT":
      if seenPanel: quit("screen metrics: duplicate PANEL_HEIGHT")
      result.panel = value
      seenPanel = true
    of "PANEL_INDENT":
      if seenIndent: quit("screen metrics: duplicate PANEL_INDENT")
      result.indent = value
      seenIndent = true
    of "OUTER_BORDER", "INNER_BORDER", "BORDER_EXTENT":
      discard
    else:
      quit("screen metrics: unknown field " & fields[0])
  if not (seenGap and seenMargin and seenTop and seenPanel and seenIndent):
    quit("screen metrics: incomplete response")

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
  else:
    quit("unknown screen action")
