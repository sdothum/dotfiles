import std/options
import std/sequtils
import std/strutils

import ../wm/compat
import ../wm/constants
import ../wm/group as groups
import ../wm/layout
import ../wm/state
import ../wm/window
import ../wm/window_query as query
import ./types as policyTypes
import ../zephyr_errors

#
# Shared policies
#

# FOR: revert geometry of newly launched fold windows

proc setGeometry() =
  state.snapshot()
  state.restore()

proc liveCount(classname: string): int =
  window.liveIds(@[classname]).splitLines().filterIt(it.len > 0).len

proc center(winid: string, groupname: string = GroupDesk) =
  discard window.target(winid)
    .group(groupname)
    .snap(Center)

proc viewport(winid: string, groupname: string = GroupDesk) =
  discard window.target(winid)
    .group(groupname)
    .size(Viewport)

proc sizeA4Centered(winid: string, groupname: string = GroupUtil) =
  discard window.target(winid)
    .group(groupname)
    .size(A4, Rotate)
    .snap(Center)

proc tile3Columns(winid, groupname, classname: string) =
  discard window.target(winid).group(groupname)
  layout.fold("3", classname)
  setGeometry()

proc video1080p(winid: string, groupname: string = GroupPlay) =
  discard window.target(winid)
    .size("1080p")
    .group(groupname)
    .snap(Center)

#
# Application policies
#

proc btop(winid: string) =
  discard window.target(winid)
    .group(GroupUtil)
    # .size(A5)
    .snap(Center)

  groups.focus(GroupDesk)

proc feh(winid: string) =
  discard window.target(winid)
    .size("1080x1690")
    .snap(Center)

# NOTE: save newly opened window geometry AFTER its intended sizing

proc kak(winid: string) =
  let w = window.target(winid)
  discard w.group(GroupCode)

  case liveCount(ClassKak)
  of 1:
    case liveCount(ClassQutebrowser)
    of 0:
      discard w.tile("3", "2")
      # layout.fold("3", ClassKak)
    else:
      discard w.tile("3", "3")
  of 2 .. 3:
    layout.fold("4", ClassKak)
    setGeometry()
  else:
    layout.fold("4", "--rows", "2", ClassKak)
    setGeometry()

proc luakit(winid: string) =
  discard window.target(winid)
    .group(GroupComm)
    .size("690x1080")
    .snap(Center, Vertical)
    .spread(Left)

proc manpage(winid: string) =
  discard window.target(winid)
    .group(GroupCode)
    .size(A5)

  layout.spread("3", "1")

proc pavucontrol(winid: string) =
  discard window.target(winid)
    .group(GroupUtil)
    .size(B6, Rotate)
    .snap(Center)

  groups.focus(GroupDesk)

proc compose(winid: string) =
  discard window.target(winid)
    .tile("3", "2")
    .group(GroupComm)

proc email(winid: string) =
  discard window.target(winid)
    .tile("3", "2")
    .group(GroupComm)
    .stackCycle()

proc cbftp(winid: string) =
  discard window.target(winid).tile("3", "2")

proc xftp(winid: string) =
  discard window.target(winid).tile("3", "3")

proc audacious(winid: string) =
  discard window.target(winid)
    .group(GroupPlay)
    .snap(Center)

proc gftp(winid: string) =
  discard window.target(winid).size(Viewport)

proc pcmanfm(winid: string) =
  discard window.target(winid)
    .group(GroupUtil)
    .tile("3")

proc term(winid: string, classname: string = ClassTerm) =
  discard window.target(winid).group(GroupCode)

  case liveCount(classname)
  of 0..2:
    layout.fold("3", "--spread", classname)
    setGeometry()
  else:
    layout.fold("3", "--rows", "2", "--spread", classname)
    setGeometry()

proc matchesInstance*(client: policyTypes.RuleClient, selector: string): bool =
  ## Exact WM_CLASS instance comparison for policies that explicitly use it.
  client.instanceName == selector

proc matchCreated*(client: policyTypes.RuleClient): Option[string] =

  if client.instanceName.len == 0 and client.className.len == 0 and
      client.title.len == 0:
    return none(string)

  # These rulerrc name selectors precede the mpv class selector and are
  # substring regex matches in ruler's existing matching convention.
  if client.title.contains("- - mpv"):
    return some("youtube")
  if client.title.contains("Mozilla Firefox"):
    return some("firefox")

  # Ruler's await actions also ran immediately when their title condition
  # was already true as the client appeared.
  if client.className == "Surf" and client.title.contains("@cgDIS:T | "):
    return some("surf")
  if client.className == "qutebrowser" and client.title == "Whoops!":
    return some("qutebrowser-whoops")

  case client.className
  of "aerc": some("aerc")
  of "Asunder": some("asunder")
  of "audacious": some("audacious")
  of "btop": some("btop")
  of "calibre": some("calibre")
  of "cbftp": some("cbftp")
  of "chromium": some("chromium")
  of "compose": some("compose")
  of "darktable": some("darktable")
  of "email": some("email")
  of "feh": some("feh")
  of "foliate": some("foliate")
  of "fontmatrix": some("fontmatrix")
  of "gFTP": some("gftp")
  of "gimp": some("gimp")
  of "kak": some("kak")
  of "krita": some("krita")
  of "Luakit": some("luakit")
  of "manpage": some("manpage")
  of "mpv": some("mpv")
  of "music": some("music")
  of "nicotine": some("nicotine")
  of "oculante": some("oculante")
  of "org.squidowl.halloy": some("halloy")
  of "palette": some("palette")
  of "pavucontrol": some("pavucontrol")
  of "pcmanfm": some("pcmanfm")
  of "qutebrowser": some("qutebrowser")
  of "RapidRAW": some("rawtherapee")
  of "rawtherapee": some("rawtherapee")
  of "term": some("term")
  of "tmux": some("tmux")
  of "wiki": some("wiki")
  of "xftp": some("xftp")
  of "yazi-root": some("yazi-root")
  of "yazi": some("yazi")
  of "zathura": some("zathura")
  else: none(string)

proc matchTitleChanged*(client: policyTypes.RuleClient,
    oldTitle: string): Option[string] =
  ## These are semantic title transitions, not generic property callbacks.
  ## The selectors mirror the current Surf marker and qutebrowser crash title.
  if client.className == "Surf" and client.title.contains("@cgDIS:T | "):
    return some("surf")
  if client.className == "qutebrowser" and client.title == "Whoops!" and
      oldTitle != client.title:
    return some("qutebrowser-whoops")
  none(string)

#
# Dispatch
#

proc applyRule*(verb, winid: string) =
  case verb
  of "calibre", "darktable", "gimp", "krita", "palette", "rawtherapee":
    center(winid)

  of "chromium", "firefox", "foliate", "oculante", "rapidraw":
    viewport(winid)
  of "aerc", "halloy":
    viewport(winid, GroupComm)
  of "fontmatrix":
    viewport(winid, GroupCode)
  of "nicotine":
    viewport(winid, GroupPeer)

  of "audacious":
    audacious(winid)
  of "compose":
    compose(winid)
  of "email":
    email(winid)
  of "feh":
    feh(winid)
  of "cbftp":
    cbftp(winid)
  of "xftp":
    xftp(winid)
  of "gftp":
    gftp(winid)
  of "pcmanfm":
    pcmanfm(winid)

  of "mpv", "youtube":
    video1080p(winid)

  of "qutebrowser":
    tile3Columns(winid, groups.name(), ClassQutebrowser)
  of "wiki":
    tile3Columns(winid, GroupWiki, ClassWiki)
  of "zathura":
    tile3Columns(winid, GroupDesk, ClassZathura)

  of "term":
    term(winid)
  of "tmux":
    term(winid, ClassTmux)

  of "yazi", "yazi-root":
    sizeA4Centered(winid)
  of "music":
    sizeA4Centered(winid, GroupPlay)
  of "asunder":
    sizeA4Centered(winid, GroupUtil)

  of "btop":
    btop(winid)
  of "kak":
    kak(winid)
  of "luakit":
    luakit(winid)

  of "surf":
    discard window.target(winid)
      .tile("4", "1")
      .group(GroupComm)
  of "qutebrowser-whoops":
    discard window.target(winid).close()

  of "manpage":
    manpage(winid)
  of "pavucontrol":
    pavucontrol(winid)
  else:
    raiseZephyrError("unknown rule: " & verb)

proc dispatch*(verb: string, rest: seq[string]) =
  requireNoArgs(verb, rest)

  let snapshot = query.wmSnapshot()
  if snapshot.focused.isNone:
    raiseZephyrError("rule: no focused managed window")
  let winid = snapshot.focused.get
  var focusedIsManaged = false
  for client in snapshot.clients:
    if client.winid == winid:
      focusedIsManaged = true
      break
  if not focusedIsManaged:
    raiseZephyrError("rule: no focused managed window")

  applyRule(verb, winid)
