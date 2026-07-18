import constants
import group as groups
import layout
import window

#
# Shared policies
#

proc center(groupname: string = GroupDesk) =
  window.group(groupname)
  window.snap(Center)

proc monocle(groupname: string = GroupDesk) =
  window.group(groupname)
  window.size(SizeMonocle)

proc sizeA4Centered(groupname: string = GroupUtil) =
  window.group(groupname)
  window.size("A4", Rotate)
  window.snap(Center)

proc tile3Columns(groupname, classname: string) =
  window.group(groupname)
  layout.tile("3", classname)

proc video1080p(groupname: string = GroupPlay) =
  window.size("1080p")
  center(groupname)

#
# Application policies
#

proc btop() =
  window.size("A5")

proc kak() =
  window.group(GroupCode)

  case window.count(ClassKak)
  of 1:
    window.tile("3", "3")
  of 2:
    layout.fold("4", ClassKak)
  of 3:
    layout.tile("4", ClassKak)
  of 4:
    layout.fold("4x2", ClassKak)
  else:
    layout.tile("4x2", ClassKak)

proc luakit() =
  window.group(GroupComm)
  window.size("690x1080")
  window.spread(Left)

proc manpage() =
  window.size("A5")
  layout.spread("3", "1", ClassManpage)

proc music() =
  window.group(GroupPlay)
  window.size("1/3")
  window.snap(Center)

proc pavucontrol() =
  window.group(GroupUtil)
  window.size("B6", Rotate)
  window.snap(Center)
  groups.focus(GroupDesk)

proc term() =
  window.group(groups.nameCurrent())

  case window.count(ClassTerm)
  of 0..2:
    layout.spread("3", ClassTerm)
  of 3:
    layout.fold("--", "3x2", ClassTerm)
  else:
    layout.spread("3x2", ClassTerm)

#
# Dispatch
#

proc requireNoArgs(ruleName: string, args: seq[string]) =
  if args.len != 0:
    quit("rule " & ruleName & " expects no args")

proc dispatch*(verb: string, rest: seq[string]) =
  requireNoArgs(verb, rest)

  case verb
  of "calibre", "darktable", "gimp", "krita", "palette", "rawtherapee":
    center()

  of "chromium", "firefox", "foliate", "oculante", "rapidraw":
    monocle()
  of "aerc", "halloy":
    monocle(GroupComm)
  of "fontmatrix":
    monocle(GroupCode)
  of "nicotine":
    monocle(GroupPeer)

  of "mpv", "youtube":
    video1080p()

  of "qutebrowser":
    tile3Columns(groups.nameCurrent(), ClassQutebrowser)
  of "wiki":
    tile3Columns(GroupWiki, ClassWiki)
  of "zathura":
    tile3Columns(GroupDesk, ClassZathura)

  of "yazi", "yazi-root":
    sizeA4Centered()

  of "btop":
    btop()
  of "kak":
    kak()
  of "luakit":
    luakit()
  of "manpage":
    manpage()
  of "music":
    music()
  of "pavucontrol":
    pavucontrol()
  of "term":
    term()
  else:
    quit("unknown rule: " & verb)
