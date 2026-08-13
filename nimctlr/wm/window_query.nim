import std/strutils

import compat
import types

#
# Queries
#

proc focusedWinid*(): string =
  shvArgs("sirocco", "window", @["focused"], 1, 1).strip()

proc geometry*(winid: string = ""): Geometry =
  let output =
    if winid.len > 0:
      shv("sirocco", ["window", "geometry", winid])
    else:
      shv("sirocco", ["window", "geometry"])

  var
    gotX = false
    gotY = false
    gotWidth = false
    gotHeight = false

  for line in output.splitLines():
    let parts = line.split('=', maxsplit = 1)

    if parts.len != 2:
      quit("invalid window geometry: " & line)

    let value = parseInt(parts[1])

    case parts[0]
    of "X":
      result.x = value
      gotX = true
    of "Y":
      result.y = value
      gotY = true
    of "WIDTH":
      result.width = value
      gotWidth = true
    of "HEIGHT":
      result.height = value
      gotHeight = true
    else:
      quit("unknown window geometry field: " & parts[0])

  if not (gotX and gotY and gotWidth and gotHeight):
    quit("incomplete window geometry")

proc geometry*(args: seq[string]): string =
  shvArgs("window", "geometry", args, 0, 1)
