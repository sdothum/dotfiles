
# chroma theme for Kakoune

# ................................................................ Color palette

# background and statusbar must be set by kakrc

# dark to lighter shades
# blacks
declare-option str black                  'rgb:263238'
declare-option str light_black            'rgb:304047'
declare-option str dark_grey              'rgb:445c65'
declare-option str pale_grey              'rgb:cfd8dc'
declare-option str white                  'rgb:fffdf8'
# reds
declare-option str dark_red               'rgb:a1462a'
declare-option str soft_red               'rgb:fa8c69'
# oranges
declare-option str strong_orange          'rgb:bf450c'
declare-option str desaturated_orange     'rgb:d5b875'
declare-option str light_orange           'rgb:ffe5b4'
declare-option str pale_orange            'rgb:fff4e6'
# yellows
declare-option str pale_yellow            'rgb:f7f3ee'
# blues
declare-option str dark_cyan              'rgb:00607c'
declare-option str blue_cyan              'rgb:0087af'
declare-option str dark_blue              'rgb:0069af'
declare-option str desaturated_cyan       'rgb:78a0a2'
declare-option str soft_cyan              'rgb:a3d5e4'
declare-option str vivid_cyan             'rgb:20fccf'
# teals
declare-option str dark_teal               'rgb:008b8b'
declare-option str lime_teal               'rgb:398b76'

# ................................................................ Color objects

# declare-option str background           "%opt{pale_yellow}"  # see kakrc
declare-option str foreground             "%opt{black}"
declare-option str linenr                 "%opt{pale_grey}"
declare-option str margin                 "%opt{background}"
declare-option str menu                   "%opt{pale_orange}"
declare-option str pick                   "%opt{desaturated_cyan}"
declare-option str statusbar              "%opt{background}"
declare-option str statusline             "%opt{desaturated_cyan}"

declare-option str cursor                 "%opt{vivid_cyan}"
declare-option str eol                    "%opt{dark_cyan}"
declare-option str multi                  "%opt{soft_red}"
declare-option str secondary              "%opt{light_orange}"
declare-option str selection              "%opt{blue_cyan}"
declare-option str wrap                   "%opt{soft_cyan}"

declare-option str attribute              "%opt{dark_blue}"
declare-option str comment                "%opt{desaturated_orange}"
declare-option str constant               "%opt{dark_teal}"
declare-option str function               "%opt{light_black}"
declare-option str operator               "%opt{strong_orange}"
declare-option str string                 "%opt{dark_red}"
declare-option str variable               "%opt{lime_teal}"

declare-option str heading                "%opt{dark_red}"
declare-option str link                   "%opt{soft_red}"
declare-option str list                   "%opt{soft_red}"
declare-option str mono                   "%opt{desaturated_cyan}"

declare-option str space                  "%opt{soft_cyan}"
declare-option str match                  "%opt{soft_red}"

# ......................................................................... Code

set-face global attribute                 "%opt{attribute}"
set-face global comment                   "%opt{comment}"
set-face global documentation             "%opt{comment}"
set-face global constant                  "%opt{constant}"
set-face global function                  "%opt{function}+b"
set-face global keyword                   "%opt{attribute}+b"
set-face global builtin                   "%opt{function}"
set-face global meta                      "%opt{function}"
set-face global module                    "%opt{function}"
set-face global operator                  "%opt{operator}+b"
set-face global string                    "%opt{string}"
set-face global type                      "%opt{attribute}"
set-face global value                     "%opt{constant}"
set-face global variable                  "%opt{variable}"

# ....................................................................... Markup

set-face global block                     "%opt{mono}"
# set-face global                         bold "%opt{heading}+b"
set-face global bullet                    "%opt{list}+b"
set-face global header                    "%opt{heading}+b"
set-face global italic                    "%opt{heading}"
set-face global link                      "%opt{link}"
set-face global list                      "%opt{list}"
set-face global mono                      "%opt{mono}+b"
set-face global title                     "%opt{heading}"

# ................................................................ Builtin faces

set-face global Default                   "%opt{foreground},%opt{background}"
set-face global PrimarySelection          "%opt{background},%opt{selection}"
set-face global SecondarySelection        "default,%opt{secondary}"
set-face global PrimaryCursor             "%opt{foreground},%opt{cursor}"
set-face global SecondaryCursor           "%opt{foreground},%opt{multi}"
set-face global PrimaryCursorEol          "%opt{background},%opt{eol}"
set-face global SecondaryCursorEol        "%opt{background},%opt{eol}"

set-face global LineNumbers               "%opt{linenr},%opt{background}"
set-face global LineNumberCursor          "%opt{string},%opt{background}+b"
set-face global LineNumbersWrapped        "%opt{margin},%opt{margin}+i"
set-face global MenuForeground            "%opt{menu},%opt{dark_grey}+b"
set-face global MenuBackground            "%opt{pick},%opt{menu}"
set-face global MenuInfo                  "%opt{string},%opt{menu}"

set-face global Information               "%opt{statusline},%opt{statusbar}"
set-face global Error                     "%opt{string},%opt{statusbar}"
set-face global StatusLine                "%opt{statusline},%opt{statusbar}"
set-face global StatusLineMode            "%opt{statusline},%opt{statusbar}"
set-face global StatusLineInfo            "%opt{statusline},%opt{statusbar}"
set-face global StatusLineValue           "%opt{statusline},%opt{statusbar}"
set-face global StatusCursor              "%opt{foreground},%opt{cursor}"

set-face global Prompt                    "%opt{statusline},%opt{statusbar}"
set-face global MatchingChar              "%opt{match},%opt{background}"
set-face global Whitespace                "%opt{space},%opt{background}+f"
set-face global WrapMarker                "%opt{wrap}+b"
set-face global BufferPadding             "%opt{background},%opt{background}"

# ...................................................................... kak-lsp

set-face global InlayHint                 "+d@type"
set-face global parameter                 "+i@variable"
set-face global enum                      "%opt{operator}"

# one-light colors for testing.. ltex-ls highlighter overwritten(?)
declare-option str lightred               "rgb:e45649"
declare-option str darkred                "rgb:ca1243"
declare-option str green                  "rgb:50a14f"
declare-option str lightorange            "rgb:c18401"
declare-option str darkorange             "rgb:986801"
declare-option str blue                   "rgb:4078f2"
declare-option str magenta                "rgb:a626a4"
declare-option str cyan                   "rgb:0184bc"

set-face global InlayDiagnosticError      "%opt{lightred}"
set-face global InlayDiagnosticWarning    "%opt{lightorange}"
set-face global InlayDiagnosticInfo       "%opt{blue}"
set-face global InlayDiagnosticHint       "%opt{green}"
set-face global LineFlagError             "%opt{lightred}"
set-face global LineFlagWarning           "%opt{lightorange}"
set-face global LineFlagInfo              "%opt{blue}"
set-face global LineFlagHint              "%opt{green}"
set-face global DiagnosticError           ",,%opt{lightred}+c"
set-face global DiagnosticWarning         ",,%opt{lightorange}+c"
set-face global DiagnosticInfo            ",,%opt{blue}+c"
set-face global DiagnosticHint            ",,%opt{green}+c"
# infobox faces
set-face global InfoDefault               Information
set-face global InfoBlock                 block
set-face global InfoBlockQuote            block
set-face global InfoBullet                bullet
set-face global InfoHeader                header
set-face global InfoLink                  link
set-face global InfoLinkMono              header
set-face global InfoMono                  mono
set-face global InfoRule                  comment
set-face global InfoDiagnosticError       InlayDiagnosticError
set-face global InfoDiagnosticHint        InlayDiagnosticHint
set-face global InfoDiagnosticInformation InlayDiagnosticInfo
set-face global InfoDiagnosticWarning     InlayDiagnosticWarning
