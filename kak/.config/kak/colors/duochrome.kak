# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# duochrome theme for Kakoune

# SEE: kakrc for modal/capslock background colorscheme control

# dynamic theme modal/capslock contrast

evaluate-commands %sh{

	# from dabruin.kak
	desaturate() {
		printf "${1#*:}\n" | fold -b2 | while read -r hex; do
			base10="$(printf '%d' "0x${hex}")"
			printf '%02x' "$(( $base10 * ${2:-7 / 10} ))"
		done | xargs printf 'rgb:%s'
	}

	# ............................................................. Color palette

	# dark to lighter shades
	# blacks
	black='rgb:263238'
	light_black='rgb:304047'
	dark_grey='rgb:445c65'
	# reds
	dark_red='rgb:a1462a'
	soft_red='rgb:fa8c69'
	pale_pink='rgb:fadadd'
	# oranges
	strong_orange='rgb:bf450c'
	light_orange='rgb:ffe5b4'
	desaturated_orange='rgb:d5b875'
	pale_orange='rgb:f7f3ee'
	# blues
	dark_blue='rgb:0069af'
	faint_blue='rgb:add8e6'
	pale_blue='rgb:caeaef'
	# cyans
	dark_cyan='rgb:0087af'
	soft_cyan='rgb:a3d5e4'
	vivid_cyan='rgb:20fccf'
	pale_cyan='rgb:baf8f8'

	# one-light colors for testing.. ltex-ls highlighter overwritten(?)
	lightred='rgb:e45649'
	darkred='rgb:ca1243'
	green='rgb:50a14f'
	lightorange='rgb:c18401'
	darkorange='rgb:986801'
	blue='rgb:4078f2'
	magenta='rgb:a626a4'
	cyan='rgb:0184bc'

	# ............................................................. Color objects

	# modal highlights
		case "${kak_opt_colormode}" in
			normal   )
	background="${pale_cyan}"
	menu="${pale_orange}"
	comment="$(desaturate ${background})"
				;;
			capslock )
	background="${pale_pink}"
	menu="${pale_cyan}"
	comment="$(desaturate ${background})"
				;;
			*        )  # insert mode
	background="${pale_orange}"
	menu="${pale_cyan}"
	# comment="$(desaturate ${background})"
	comment="${desaturated_orange}"
				;;
		esac

	foreground="${black}"
	margin="${background}"
	linenr="$(desaturate ${background} '11 / 13')"
	pick="$(desaturate ${pale_cyan})"
	statusbar="${background}"
	statusline="$(desaturate ${background})"
	info="$(desaturate ${soft_red} '12 / 15')"

	cursor="${vivid_cyan}"
	eol="${soft_red}"
	multi="${soft_red}"
	secondary="${light_orange}"
	selection="${dark_cyan}"
	ruler="$(desaturate ${background} '14 / 15')"
	wrap="${soft_red}"

	attribute="${dark_blue}"
	constant="${dark_blue}"
	function="${light_black}"
	operator="${strong_orange}"
	string="${dark_red}"
	variable="${light_black}"

	heading="${strong_orange}"
	link="${soft_red}"
	list="${soft_red}"
	mono="$(desaturate ${soft_red} '12 / 15')"

	space="${soft_cyan}"
	match="${soft_red}"

	cat <<-COLORSCHEME

# ......................................................................... Code

# NOTE: window scope (vs global SEE: kakrc)

set-face window attribute                 "${attribute}"
set-face window comment                   "${comment}"
set-face window documentation             "${comment}"
set-face window constant                  "${constant}"
set-face window function                  "${function}+b"
set-face window keyword                   "${function}+b"
set-face window builtin                   "${function}"
set-face window meta                      "${function}"
set-face window module                    "${function}"
set-face window operator                  "${operator}+b"
set-face window string                    "${string}"
set-face window type                      "${attribute}"
set-face window value                     "${constant}"
set-face window variable                  "${variable}"

# ....................................................................... Markup

set-face window block                     "${mono}"
set-face window bullet                    "${list}+b"
set-face window header                    "${heading}+b"
set-face window italic                    "${heading}"
set-face window link                      "${link}"
set-face window list                      "${list}"
set-face window mono                      "${mono}+b"
set-face window title                     "${heading}"

# ................................................................ Builtin faces

set-face window Default                   "${foreground},${background}"
set-face window PrimarySelection          "${background},${selection}"
set-face window SecondarySelection        "default,${secondary}"
set-face window PrimaryCursor             "default,${cursor}"
set-face window SecondaryCursor           "default,${multi}"
set-face window PrimaryCursorEol          "${background},${eol}"
set-face window SecondaryCursorEol        "${background},${eol}"

set-face window LineNumbers               "${linenr},${background}"
set-face window LineNumberCursor          "${string},${background}+b"
set-face window LineNumbersWrapped        "${margin},${margin}+i"
set-face window MenuForeground            "${menu},${dark_grey}+b"
set-face window MenuBackground            "${pick},${menu}"
set-face window MenuInfo                  "${string},${menu}"

set-face window Information               "${info},${statusbar}"
set-face window InlineInformation         "${statusline},${statusbar}"
set-face window Error                     "${string},${statusbar}"
set-face window DiagnosticError           "${string},${statusbar}"
set-face window DiagnosticWarning         "${string},${statusbar}"

set-face window StatusLine                "${statusline},${statusbar}"
set-face window StatusLineMode            "${statusline},${statusbar}"
set-face window StatusLineInfo            "${statusline},${statusbar}"
set-face window StatusLineValue           "${statusline},${statusbar}"
set-face window StatusCursor              "${foreground},${cursor}"
set-face window Prompt                    "${foreground},${statusbar}"

set-face window MatchingChar              "${match},${background}+br"
set-face window Whitespace                "${space},${background}+f"
set-face window WrapMarker                "${wrap}+bf"
set-face window BufferPadding             "${background},${background}"  # hide tilde

# .................................................................. Admonitions

set-face window Admonitions               "+bf@Error"

# ...................................................................... Peneira

set-face window PeneiraSelected           "${foreground},${faint_blue}"
set-face window PeneiraFlag               LineNumberCursor
set-face window PeneiraMatches            "${background},${selection}+b"
set-face window PeneiraFileName           "${attribute}"

# ............................................................... kak-crosshairs

set-face window crosshairs_line           "default,default+u"
set-face window crosshairs_column         "default,${ruler}"

# ...................................................................... kak-lsp

set-face window InlayHint                 "+d@type"
set-face window parameter                 "+i@variable"
set-face window enum                      "${operator}"

set-face window InlayDiagnosticError      "${lightred}"
set-face window InlayDiagnosticWarning    "${lightred}"
set-face window InlayDiagnosticInfo       "${lightred}"
set-face window InlayDiagnosticHint       "${lightred}"
set-face window LineFlagError             "${lightred}"
set-face window LineFlagWarning           "${lightred}"
set-face window LineFlagInfo              "${lightred}"
set-face window LineFlagHint              "${lightred}"
set-face window DiagnosticError           ",,${lightred}+c"
set-face window DiagnosticWarning         ",,${lightred}+c"
set-face window DiagnosticInfo            ",,${lightred}+c"
set-face window DiagnosticHint            ",,${lightred}+c"
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

	COLORSCHEME
}
