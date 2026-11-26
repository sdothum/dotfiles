import std/options
import std/sequtils
import std/strutils

import ../wm/compat
import ../wm/constants
import ../wm/group as groups
import ./layouts as layouts
import ../wm/state
import ../wm/window
import ../wm/window_query as query
import ./types as policyTypes
import ../zephyr_errors

#
# Shared policies
#

# FOR: revert geometry of newly launched fold windows


# Captures and restores controller geometry state through the state module.

proc setGeometry() =
  state.snapshot()
  state.restore()


# Counts nonempty live WM ID records for the supplied class selector.

proc liveCount(classname: string): int =
  window.liveIds(@[classname]).splitLines().filterIt(it.len > 0).len


# Assigns the target group and centers the explicit window through the fluent window API.

proc center(winid: string, groupname: string = GroupDesk) =
  discard window.target(winid)
    .group(groupname)
    .snap(Center)


# Assigns the target group and applies the configured viewport size.

proc viewport(winid: string, groupname: string = GroupDesk) =
  discard window.target(winid)
    .group(groupname)
    .size(Viewport)


# Assigns the target group, applies rotated A4 sizing and centers the explicit window.

proc sizeA4Centered(winid: string, groupname: string = GroupUtil) =
  discard window.target(winid)
    .group(groupname)
    .size(A4, Rotate)
    .snap(Center)


# Assigns the target group, folds matching class windows into three columns and records geometry.

proc tile3Columns(winid, groupname, classname: string) =
  discard window.target(winid).group(groupname)
  layouts.fold(@["3", classname])
  setGeometry()


# Applies 1080p sizing, assigns the play group by default and centers the explicit window.

proc video1080p(winid: string, groupname: string = GroupPlay) =
  discard window.target(winid)
    .size("1080p")
    .group(groupname)
    .snap(Center)

#
# Application policies
#


# Places the monitor window in the utility group at centered rotated B5 size, then focuses the desk.

proc btop(winid: string) =
  discard window.target(winid)
    .group(GroupUtil)
    .size(B5,Rotate)
    .snap(Center)

  groups.focus(GroupDesk)


# Sizes the image viewer to 1080x1690 and centers it.

proc feh(winid: string) =
  discard window.target(winid)
    .size("1080x1690")
    .snap(Center)

# NOTE: save newly opened window geometry AFTER its intended sizing


# Assigns the code group and selects editor tiling from current editor and browser counts.

proc kak(winid: string) =
  let w = window.target(winid)
  discard w.group(GroupCode)

  case liveCount(ClassKak)
  of 1:
    let qutebrowser = liveCount(ClassQutebrowser)
    case qutebrowser + liveCount(ClassFirefox)
    of 0:
      discard w.tile("3", "2")
    else:
      if qutebrowser > 0:
        discard w.tile("3", "3")
      else:
        discard w.tile("4", "4")
  of 2 .. 3:
    layouts.fold(@["4", ClassKak])
    setGeometry()
  else:
    layouts.fold(@["4", "--rows", "2", ClassKak])
    setGeometry()


# Assigns the communication group and applies browser sizing, vertical centering and biased spread.

proc luakit(winid: string) =
  discard window.target(winid)
    .group(GroupComm)
    .size("690x1080")
    .snap(Center, Vertical)
    .spread($layouts.bias())


# Assigns code-group A5 sizing and invokes the layout spread policy.

proc manpage(winid: string) =
  discard window.target(winid)
    .group(GroupCode)
    .size(A5)

  layouts.spread(@["3", "1"])


# Centers rotated B6 audio controls in the utility group, then focuses the desk.

proc pavucontrol(winid: string) =
  discard window.target(winid)
    .group(GroupUtil)
    .size(B6, Rotate)
    .snap(Center)

  groups.focus(GroupDesk)


# Tiles the compose window in the second of three columns and assigns the communication group.

proc compose(winid: string) =
  discard window.target(winid)
    .tile("3", "2")
    .group(GroupComm)


# Tiles the mail window in the communication group and cycles its overlapping stack.

proc email(winid: string) =
  discard window.target(winid)
    .tile("3", "2")
    .group(GroupComm)
    .stackCycle()


# Tiles the explicit transfer window in the second of three columns.

proc cbftp(winid: string) =
  discard window.target(winid).tile("3", "2")


# Tiles the explicit transfer window in the third of three columns.

proc xftp(winid: string) =
  discard window.target(winid).tile("3", "3")


# Assigns the player to the play group and centers it.

proc audacious(winid: string) =
  discard window.target(winid)
    .group(GroupPlay)
    .snap(Center)


# Applies the configured viewport size to the transfer window.

proc gftp(winid: string) =
  discard window.target(winid).size(Viewport)


# Assigns the file manager to the utility group and applies three-column tiling.

proc pcmanfm(winid: string) =
  discard window.target(winid)
    .group(GroupUtil)
    .tile("3")


# Assigns the code group and spreads class-matched terminals across one or two grid rows.

proc term(winid: string, classname: string = ClassTerm) =
  discard window.target(winid).group(GroupCode)

  case liveCount(classname)
  of 0..2:
    layouts.fold(@["3", "--spread", classname])
    # setGeometry()
  else:
    layouts.fold(@["3", "--rows", "2", "--spread", classname])
    # setGeometry()


# Exact WM_CLASS instance comparison for policies that explicitly use it.

proc matchesInstance*(client: policyTypes.RuleClient, selector: string): bool =
  client.instanceName == selector


# Selects the first matching creation policy from observed instance, class and title metadata.

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
  of "Chromium": some("Chromium")
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
  of "luakit", "Luakit": some("luakit")
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


# These are semantic title transitions, not generic property callbacks.
# The selectors mirror the current Surf marker and qutebrowser crash title.

proc matchTitleChanged*(client: policyTypes.RuleClient,
    oldTitle: string): Option[string] =
  if client.className == "Surf" and client.title.contains("@cgDIS:T | "):
    return some("surf")
  if client.className == "qutebrowser" and client.title == "Whoops!" and
      oldTitle != client.title:
    return some("qutebrowser-whoops")
  none(string)

#
# Dispatch
#


# Applies the selected application policy to the explicit window and rejects unknown policy verbs.

proc applyRule*(verb, winid: string) =
  case verb
  of "calibre", "darktable", "gimp", "krita", "palette", "rawtherapee":
    center(winid)

  of "chromium", "Chromium", "firefox", "foliate", "oculante", "rapidraw":
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

#
# layout direction
#


# Requires a focused managed snapshot client before applying a no-argument rule command.

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
