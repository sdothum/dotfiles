import std/options
import std/unittest

import ../policy/rules
import ../policy/types

suite "daemon-native rule selection":
  test "class selectors select existing rule verbs":
    for (className, expected) in [
        ("aerc", "aerc"),
        ("email", "email"),
        ("compose", "compose"),
        ("cbftp", "cbftp"),
        ("xftp", "xftp"),
        ("kak", "kak"),
        ("wiki", "wiki"),
        ("music", "music"),
        ("yazi", "yazi"),
        ("yazi-root", "yazi-root"),
        ("btop", "btop"),
        ("manpage", "manpage"),
        ("term", "term"),
        ("tmux", "tmux"),
        ("palette", "palette"),
        ("pavucontrol", "pavucontrol"),
        ("audacious", "audacious"),
        ("calibre", "calibre"),
        ("nicotine", "nicotine"),
        ("darktable", "darktable"),
        ("gimp", "gimp"),
        ("krita", "krita"),
        ("RapidRAW", "rawtherapee"),
        ("rawtherapee", "rawtherapee"),
        ("foliate", "foliate"),
        ("fontmatrix", "fontmatrix"),
        ("gFTP", "gftp"),
        ("pcmanfm", "pcmanfm"),
        ("mpv", "mpv"),
        ("oculante", "oculante"),
        ("zathura", "zathura"),
        ("chromium", "chromium"),
        ("qutebrowser", "qutebrowser"),
        ("Luakit", "luakit"),
        ("org.squidowl.halloy", "halloy")
      ]:
      check matchCreated(RuleClient(winid: "0x01234567", className: className)).get == expected

  test "title selectors match Mozilla Firefox and youtube mpv titles":
    check matchCreated(RuleClient(
      winid: "0x01234567", title: "Example page — Mozilla Firefox"
    )).get == "firefox"
    check matchCreated(RuleClient(
      winid: "0x01234567", className: "mpv", title: "video - - mpv"
    )).get == "youtube"

  test "empty or unrelated metadata has no rule":
    check matchCreated(RuleClient(winid: "0x01234567")).isNone
    check matchCreated(RuleClient(
      winid: "0x01234567", className: "unknown", title: "unrelated"
    )).isNone

  test "Surf and qutebrowser title transitions are application scoped":
    check matchTitleChanged(RuleClient(winid: "0x1", className: "Surf",
      title: "@cgDIS:T | Hangouts"), "blank").get == "surf"
    check matchTitleChanged(RuleClient(winid: "0x1", className: "Surf",
      title: "ordinary page"), "blank").isNone
    check matchTitleChanged(RuleClient(winid: "0x1", className: "Other",
      title: "@cgDIS:T | Hangouts"), "blank").isNone
    check matchTitleChanged(RuleClient(winid: "0x2", className: "qutebrowser",
      title: "Whoops!"), "normal page").get == "qutebrowser-whoops"
    check matchTitleChanged(RuleClient(winid: "0x2", className: "qutebrowser",
      title: "whoops!"), "normal page").isNone
    check matchTitleChanged(RuleClient(winid: "0x3", className: "Other",
      title: "Whoops!"), "normal page").isNone
    check matchCreated(RuleClient(winid: "0x2", className: "qutebrowser",
      title: "Whoops!")).get == "qutebrowser-whoops"
    check matchCreated(RuleClient(winid: "0x4", className: "Surf",
      title: "@cgDIS:T | immediate")).get == "surf"
    check matchTitleChanged(RuleClient(winid: "0x2", className: "qutebrowser",
      title: "Whoops!"), "Whoops!").isNone

  test "rulerrc class selector spelling remains case-sensitive":
    check matchCreated(RuleClient(winid: "0x01234567", className: "RapidRAW")).get == "rawtherapee"
    check matchCreated(RuleClient(winid: "0x01234567", className: "rapidraw")).isNone
    check matchCreated(RuleClient(winid: "0x01234567", className: "org.squidowl.halloy")).get == "halloy"
    check matchCreated(RuleClient(winid: "0x01234567", className: "Org.squidowl.halloy")).isNone
    check matchCreated(RuleClient(winid: "0x01234567", className: "gftp")).isNone
    check matchCreated(RuleClient(winid: "0x01234567", className: "luakit")).isNone

  test "WM_CLASS instance and class remain independent exact values":
    let client = RuleClient(
      winid: "0x01234567",
      instanceName: "luakit",
      className: "Luakit",
      title: "Hangouts"
    )
    check matchesInstance(client, "luakit")
    check not matchesInstance(client, "Luakit")
    check matchCreated(client).get == "luakit"

    let wrongClass = RuleClient(
      winid: "0x01234567",
      instanceName: "Luakit",
      className: "luakit"
    )
    check matchesInstance(wrongClass, "Luakit")
    check matchCreated(wrongClass).isNone
