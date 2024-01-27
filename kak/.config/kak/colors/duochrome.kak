# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# duochrome theme for Kakoune

# ................................................................ Color palette

# dynamic theme mode contrast
# background/comment and statusbar must be set by kakrc

# dark to lighter shades
# blacks
declare-option str black                  'rgb:263238'
declare-option str light_black            'rgb:304047'
declare-option str dark_grey              'rgb:445c65'
# declare-option str light_grey           'rgb:b8c6cb'
# declare-option str pale_grey            'rgb:cfd8dc'
# reds
declare-option str dark_red               'rgb:a1462a'
declare-option str soft_red               'rgb:fa8c69'
# declare-option str desaturated_pink     'rgb:9d748c'  # see kakrc
# declare-option str pale_pink            'rgb:fadadd'  # see kakrc
# oranges
declare-option str strong_orange          'rgb:bf450c'
declare-option str light_orange           'rgb:ffe5b4'
# declare-option str desaturated_orange   'rgb:d5b875'  # see kakrc (as master color assignment)
# declare-option str pale_orange          'rgb:f7f3ee'  # see kakrc
# blues
declare-option str dark_blue              'rgb:0069af'
# declare-option str desaturated_blue     'rgb:6b9494'  # see kakrc
# declare-option str pale_blue            'rgb:caeaef'  # see kakrc
# cyans
declare-option str dark_cyan              'rgb:0087af'
declare-option str soft_cyan              'rgb:a3d5e4'
declare-option str vivid_cyan             'rgb:20fccf'
# declare-option str desaturated_cyan     'rgb:78a0a2'  # see kakrc
# declare-option str pale_cyan            'rgb:baf8f8'  # see kakrc
# greens
# declare-option str desaturated_green    'rgb:78ab78'  # see kakrc
# declare-option str pale_green           'rgb:d4ebe1'  # see kakrc

# ................................................................ Color objects

# declare-option str background           "%opt{pale_orange}"         # see kakrc
declare-option str foreground             "%opt{black}"
# declare-option str linenr               "%opt{pale_grey}"           # see kakr
declare-option str margin                 "%opt{background}"
# declare-option str menu                 "%opt{pale_cyan}"           # see kakr
declare-option str pick                   "%opt{desaturated_cyan}"
declare-option str statusbar              "%opt{background}"
declare-option str statusline             "%opt{desaturated_cyan}"

declare-option str cursor                 "%opt{vivid_cyan}"
declare-option str eol                    "%opt{soft_red}"
declare-option str multi                  "%opt{soft_red}"
declare-option str secondary              "%opt{light_orange}"
declare-option str selection              "%opt{dark_cyan}"
declare-option str wrap                   "%opt{soft_red}"

declare-option str attribute              "%opt{dark_blue}"
# declare-option str comment              "%opt{desaturated_orange}"  # see kakrc
declare-option str constant               "%opt{dark_blue}"
declare-option str function               "%opt{light_black}"
declare-option str operator               "%opt{strong_orange}"
declare-option str string                 "%opt{dark_red}"
declare-option str variable               "%opt{light_black}"

declare-option str heading                "%opt{dark_red}"
declare-option str link                   "%opt{soft_red}"
declare-option str list                   "%opt{soft_red}"
declare-option str mono                   "%opt{desaturated_cyan}"

declare-option str space                  "%opt{soft_cyan}"
declare-option str match                  "%opt{soft_red}"

# ......................................................................... Code

# NOTE: window scope (vs global SEE: kakrc)

set-face window attribute                 "%opt{attribute}"
set-face window comment                   "%opt{comment}"
set-face window documentation             "%opt{comment}"
set-face window constant                  "%opt{constant}"
set-face window function                  "%opt{function}+b"
set-face window keyword                   "%opt{function}+b"
set-face window builtin                   "%opt{function}"
set-face window meta                      "%opt{function}"
set-face window module                    "%opt{function}"
set-face window operator                  "%opt{operator}+b"
set-face window string                    "%opt{string}"
set-face window type                      "%opt{attribute}"
set-face window value                     "%opt{constant}"
set-face window variable                  "%opt{variable}"

# ....................................................................... Markup

set-face window block                     "%opt{mono}"
# set-face window bold                    "%opt{heading}+b"
set-face window bullet                    "%opt{list}+b"
set-face window header                    "%opt{heading}+b"
set-face window italic                    "%opt{heading}"
set-face window link                      "%opt{link}"
set-face window list                      "%opt{list}"
set-face window mono                      "%opt{mono}+b"
set-face window title                     "%opt{heading}"

# ................................................................ Builtin faces

set-face window Default                   "%opt{foreground},%opt{background}"
set-face window PrimarySelection          "%opt{background},%opt{selection}"
set-face window SecondarySelection        "default,%opt{secondary}"
set-face window PrimaryCursor             "%opt{foreground},%opt{cursor}"
set-face window SecondaryCursor           "%opt{foreground},%opt{multi}"
set-face window PrimaryCursorEol          "%opt{background},%opt{eol}"
set-face window SecondaryCursorEol        "%opt{background},%opt{eol}"

set-face window LineNumbers               "%opt{linenr},%opt{background}"
set-face window LineNumberCursor          "%opt{string},%opt{background}+b"
set-face window LineNumbersWrapped        "%opt{margin},%opt{margin}+i"
set-face window MenuForeground            "%opt{menu},%opt{dark_grey}+b"
set-face window MenuBackground            "%opt{pick},%opt{menu}"
set-face window MenuInfo                  "%opt{string},%opt{menu}"

set-face window Information               "%opt{statusline},%opt{statusbar}"
set-face window InlineInformation         "%opt{statusline},%opt{statusbar}"
set-face window Error                     "%opt{string},%opt{statusbar}"
set-face window DiagnosticError           "%opt{string},%opt{statusbar}"
set-face window DiagnosticWarning         "%opt{string},%opt{statusbar}"

set-face window StatusLine                "%opt{statusline},%opt{statusbar}"
set-face window StatusLineMode            "%opt{statusline},%opt{statusbar}"
set-face window StatusLineInfo            "%opt{statusline},%opt{statusbar}"
set-face window StatusLineValue           "%opt{statusline},%opt{statusbar}"
set-face window StatusCursor              "%opt{foreground},%opt{cursor}"
set-face window Prompt                    "%opt{statusline},%opt{statusbar}"

set-face window MatchingChar              "%opt{match},%opt{background}+br"
set-face window Whitespace                "%opt{space},%opt{background}+f"
set-face window WrapMarker                "%opt{wrap}+bf"
set-face window BufferPadding             "%opt{background},%opt{background}"  # hide tilde

# .................................................................. Admonitions

set-face window Admonitions               "+bf@Error"

# ...................................................................... Peneira

set-face window PeneiraSelected           "%opt{foreground},%opt{faint_blue}"
set-face window PeneiraFlag               LineNumberCursor
set-face window PeneiraMatches            "%opt{background},%opt{selection}+b"
set-face window PeneiraFileName           attribute

# ...................................................................... kak-lsp

set-face window InlayHint                 "+d@type"
set-face window parameter                 "+i@variable"
set-face window enum                      "%opt{operator}"

# one-light colors for testing.. ltex-ls highlighter overwritten(?)
declare-option str lightred               "rgb:e45649"
declare-option str darkred                "rgb:ca1243"
declare-option str green                  "rgb:50a14f"
declare-option str lightorange            "rgb:c18401"
declare-option str darkorange             "rgb:986801"
declare-option str blue                   "rgb:4078f2"
declare-option str magenta                "rgb:a626a4"
declare-option str cyan                   "rgb:0184bc"

set-face window InlayDiagnosticError      "%opt{lightred}"
set-face window InlayDiagnosticWarning    "%opt{lightorange}"
set-face window InlayDiagnosticInfo       "%opt{dark_blue}"
set-face window InlayDiagnosticHint       "%opt{desaturated_green}"
set-face window LineFlagError             "%opt{lightred}"
set-face window LineFlagWarning           "%opt{lightorange}"
set-face window LineFlagInfo              "%opt{dark_blue}"
set-face window LineFlagHint              "%opt{desaturated_green}"
set-face window DiagnosticError           ",,%opt{lightred}+c"
set-face window DiagnosticWarning         ",,%opt{lightorange}+c"
set-face window DiagnosticInfo            ",,%opt{dark_blue}+c"
set-face window DiagnosticHint            ",,%opt{desaturated_green}+c"
# infobox faces
set-face window InfoDefault               Information
set-face window InfoBlock                 block
set-face window InfoBlockQuote            block
set-face window InfoBullet                bullet
set-face window InfoHeader                header
set-face window InfoLink                  link
set-face window InfoLinkMono              header
set-face window InfoMono                  mono
set-face window InfoRule                  comment
set-face window InfoDiagnosticError       InlayDiagnosticError
set-face window InfoDiagnosticHint        InlayDiagnosticHint
set-face window InfoDiagnosticInformation InlayDiagnosticInfo
set-face window InfoDiagnosticWarning     InlayDiagnosticWarning

