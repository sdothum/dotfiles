# sdothum - 2016 (c) wtfpl

# Kakoune
# ══════════════════════════════════════════════════════════════════════════════

# duochrome theme for Kakoune

# SEE: - kakrc for modal/capslock background colorscheme control
#      - $USER/bin/function/shell/min
#      - $USER/bin/function/test/exists
#      - dyetide git for dye

# dynamic theme modal/capslock contrast

evaluate-commands %sh{

	exists dye && lighten=true  # unset for desaturated cursor ruler

	lightness() {
		[ $2 ] || set -- $@ 10              # default lightness adjustment % amount NOTE: negative values darken
		set -- $@ $(dye -x hsl "#${1#*:}")  # rgb:<hex color> <lightness amount> hsla(<hue>, <saturation>%, <lightness>%)
		[ "${2%-*}" = '' ] && l=$(max 0 $(( ${5%%%*} + $2 )) ) || l=$(min 100 $(( ${5%%%*} + $2 )) )
		echo "rgb:$(dye -h hex "$3 $4 ${l}%)" | cut -d\# -f2)"
	}

	# from dabruin.kak
	desaturate() {
		printf "${1#*:}\n" | fold -b2 | while read -r hex; do
			base10="$(printf '%d' "0x${hex}")"
			printf '%02x' "$(( base10 * ${2:-7 / 10} ))"
		done | xargs printf 'rgb:%s'
	}

	# Usage: setbg <BG #> <varname> <default:lightness>
	#              where, BG=<normal[:lightness]>,<insert[:lightness]>,<capslock[:lightness]> SEE: kak wrapper
	#                     <[+|-]lightness> is hsla lightness (lighten/darken) adjustment percentage for ruler
	#              example: $BG= -> ffead0:-7,fff5e8:9,ffd7a6:-8  (monochromatic orange theme)
	#                            -> ffead0:-7,fff5e8:9,96f8f8:-12 (duochromatic orange/cyan theme)
	#                            -> 96f8f8:-12,fff5e8:9,ffd9b6:-7 (triadic cyan/orange/salmon theme)

   [ "$kak_opt_filetype" = 'markdown' ] && BG=${BG:-ffead0:-7,fff5e8:9,96f8f8:-12} || BG=${BG:-96f8f8:-12,fff5e8:9,ffd9b6:-7}

	setbg() {
		hex=$(echo $BG,, | cut -s -d, -f$1)
		[ $hex ] || hex=$3  # apply default triadic color
		eval ${2}=${hex%:*}
		[ $hex != ${hex#*:} ] && eval ${2}_=${hex#*:}
	}

	setbg 1 NORMAL   96f8f8:-12
	setbg 2 INSERT   fff5e8:9
	setbg 3 CAPSLOCK ffd9b6:-7

	# ............................................................. Color palette

	# dark to lighter shades
	# blacks
	black='rgb:263238'
	light_black='rgb:304047'
	dark_grey='rgb:445c65'
	white='rgb:ffffff'
	# reds
	dark_red='rgb:a1462a'
	soft_red='rgb:fa8c69'
	salmon='rgb:ffd9b6'
	pale_pink='rgb:ffd4db'
	# oranges
	strong_orange='rgb:bf450c'
	light_orange='rgb:ffe5b4'
	desaturated_orange='rgb:d5a575'
	pale_orange='rgb:f6f3ef'
	# blues
	dark_blue='rgb:0069af'
	faint_blue='rgb:add8e6'
	pale_blue='rgb:caeaef'
	# cyans
	dark_cyan='rgb:0087af'
	soft_cyan='rgb:a3d5e4'
	vivid_cyan='rgb:20fccf'
	pale_cyan='rgb:96f8f8'

	# one-light colors for testing.. ltex-ls highlighter overwritten(?)
	lightred='rgb:e45649'
	darkred='rgb:ca1243'
	green='rgb:50a14f'
	lightorange='rgb:c18401'
	darkorange='rgb:986801'
	blue='rgb:4078f2'
	magenta='rgb:a626a4'
	cyan='rgb:0184bc'

	# kak-tree-sitter
	diffminus='rgb:ed8796'
	diffmoved='rgb:c6a0f6'
	diffplus='rgb:a6da95'
	diffdelta='rgb:8aadf4'

	# ............................................................. Color objects

	# modal highlights
	case "${kak_opt_color}" in
		normal   )
			background="rgb:${NORMAL}"
			menu="rgb:${INSERT}"
			comment="$(desaturate ${background})"
			if [ $lighten ] ;then
				# cursor="${vivid_cyan}"
				cursor="${white}"
				ruler="$(lightness ${background} ${NORMAL_:--12})"  # NOTE: negative value for darkening
			else
				cursor="${pale_orange}"
				ruler="$(desaturate ${background} '34 / 35')"
			fi
			;;
		capslock )
			background="rgb:${CAPSLOCK}"
			menu="rgb:${INSERT}"
			comment="$(desaturate ${background})"
			if [ $lighten ] ;then
				if [ "${kak_opt_mode}" = 'normal' ] ;then
					cursor="${white}"
					ruler="$(lightness ${background} ${CAPSLOCK_:--7})"
				else
					cursor="${vivid_cyan}"  # insert mode cursor and ruler
					ruler="$(lightness ${pale_orange} ${INSERT_:-9})"
				fi
			else
				[ "${kak_opt_mode}" = 'normal' ] && cursor="${pale_orange}" || cursor="${vivid_cyan}"
				ruler="$(desaturate ${background} '36 / 37')"
			fi
			;;
		*        )
			background="rgb:${INSERT}"  # insert mode (default non-modal mode)
			menu="rgb:${NORMAL}"
			cursor="${vivid_cyan}"
			if [ $lighten ] ;then
				ruler="$(lightness ${background} ${INSERT_:-9})"
				comment="$(desaturate $(lightness ${background} -18) '5 / 6')"
			else
				ruler="$(desaturate ${background} '42 / 43')"
				comment="${desaturated_orange}"
			fi
			;;
	esac

	foreground="${black}"
	margin="${background}"
	linenr="$(desaturate ${background} '11 / 13')"
	pick="$(desaturate ${pale_cyan})"
	statusbar="${background}"
	statusline="$(desaturate ${background})"
	# info="$(desaturate ${soft_red} '12 / 15')"
	info="$(desaturate ${comment} '12 / 15')"

	eol="${soft_red}"
	multi="${soft_red}"
	secondary="${light_orange}"
	selection="${dark_cyan}"
	wrap="${soft_red}"

	attribute="${dark_blue}"
	constant="${dark_blue}"
	function="${light_black}"
	operator="${strong_orange}"
	string="${dark_red}"
	variable="${light_black}"

	heading="${strong_orange}"
	link="blue"
	list="${soft_red}"

	space="${soft_cyan}"
	match="${soft_red}"
	error="$(desaturate ${soft_red} '12 / 15')"
	diagnostic="$(desaturate ${pale_pink} '12 / 15')"
	mono="${error}"


	cat <<-COLORSCHEME
# Syntax highlighting
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ......................................................................... Code

# NOTE: window scope (vs global SEE: kakrc)

set-face window attribute                      "${attribute}"
set-face window comment                        "${comment}"
set-face window documentation                  "${comment}"
set-face window constant                       "${constant}"
set-face window function                       "${function}+b"
set-face window keyword                        "${function}+b"
set-face window builtin                        "${function}"
set-face window meta                           "${function}"
set-face window module                         "${function}"
set-face window operator                       "${operator}+b"
set-face window string                         "${string}"
set-face window type                           "${attribute}"
set-face window value                          "${constant}"
set-face window variable                       "${variable}"

# ....................................................................... Markup

set-face window block                          "${mono}"
set-face window bullet                         "${list}+b"
set-face window header                         "${heading}+b"
set-face window italic                         "${heading}"
set-face window link                           "${link}+b"
set-face window list                           "${list}"
set-face window mono                           "${mono}+b"
set-face window title                          "${heading}"

# Kakoune UI
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# ................................................................ Builtin faces

set-face window Default                        "${foreground},${background}"
set-face window PrimarySelection               "${background},${selection}"
set-face window SecondarySelection             "default,${secondary}"
set-face window PrimaryCursor                  "default,${cursor}"
set-face window SecondaryCursor                "default,${multi}"
set-face window PrimaryCursorEol               "${background},${eol}"
set-face window SecondaryCursorEol             "${background},${eol}"

set-face window LineNumbers                    "${linenr},${background}"
set-face window LineNumberCursor               "${string},${background}+b"
set-face window LineNumbersWrapped             "${margin},${margin}+i"
set-face window MenuForeground                 "${menu},${dark_grey}+b"
set-face window MenuBackground                 "${pick},${menu}"
set-face window MenuInfo                       "${string},${menu}"

set-face window Information                    "${info},${statusbar}"
set-face window InlineInformation              "${statusline},${statusbar}"
set-face window Error                          "${error},${statusbar}+br"
set-face window DiagnosticError                "${diagnostic},${statusbar}+br"
set-face window DiagnosticWarning              "${info},${statusbar}+br"

set-face window StatusLine                     "${statusline},${statusbar}"
set-face window StatusLineMode                 "${statusline},${statusbar}"
set-face window StatusLineInfo                 "${statusline},${statusbar}"
set-face window StatusLineValue                "${statusline},${statusbar}"
set-face window StatusCursor                   "${foreground},${cursor}"
set-face window Prompt                         "${foreground},${statusbar}"

set-face window MatchingChar                   "${match},${background}+br"
set-face window Whitespace                     "${space},${background}+f"
set-face window WrapMarker                     "${wrap}+bf"
set-face window BufferPadding                  "${background},${background}"  # hide tilde
set-face window Trailing                       "default,${white}+bs"

# ................................................................. Highlighting

set-face window Admonitions                    "+bf@Error"

add-highlighter -override window/ dynregex '%reg{/}' 0:SecondarySelection

# Plugins
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# .......................................................................... hop
set-face window hop_label_head                 "${white},${dark_blue}+bF"
set-face window hop_label_tail                 hop_label_head

# ............................................................... kak-crosshairs

# set-face window crosshairs_line              "default,default+u"
set-face window crosshairs_line                "default,${ruler}"
set-face window crosshairs_column              "default,${ruler}"

# ................................................................ kakoune-focus

set-face window FocusSeparator                 "${soft_red},${background}+F"

# ...................................................................... peneira

set-face window PeneiraSelected                "${foreground},${multi}"
set-face window PeneiraFlag                    LineNumberCursor
set-face window PeneiraMatches                 "${foreground},${secondary}+b"
set-face window PeneiraFileName                "${attribute}"

# ............................................................ phantom selection

# set-face window PhantomSelection             "${white},${wrap}+F"
set-face window PhantomSelection               "default,${soft_red}+g"

# .................................................................. reasymotion

set-face window REasymotionBackground          hop_label_head  # BUG: currently not overriding plugin
set-face window REasymotionForeground          hop_label_head

# ...................................................................... kak-lsp

set-face window InlayHint                      "+d@type"
set-face window parameter                      "+i@variable"
set-face window enum                           "${operator}"

set-face window InlayDiagnosticError           "${lightred}"
set-face window InlayDiagnosticWarning         "${lightred}"
set-face window InlayDiagnosticInfo            "${lightred}"
set-face window InlayDiagnosticHint            "${lightred}"
set-face window LineFlagError                  "${lightred}"
set-face window LineFlagWarning                "${lightred}"
set-face window LineFlagInfo                   "${lightred}"
set-face window LineFlagHint                   "${lightred}"
set-face window DiagnosticError                ",,${lightred}+c"
set-face window DiagnosticWarning              ",,${lightred}+c"
set-face window DiagnosticInfo                 ",,${lightred}+c"
set-face window DiagnosticHint                 ",,${lightred}+c"
# infobox faces
set-face window InfoDefault                    Information
set-face window InfoBlock                      block
set-face window InfoBlockQuote                 block
set-face window InfoBullet                     bullet
set-face window InfoHeader                     header
set-face window InfoLink                       link
set-face window InfoLinkMono                   header
set-face window InfoMono                       mono
set-face window InfoRule                       comment
set-face window InfoDiagnosticError            InlayDiagnosticError
set-face window InfoDiagnosticHint             InlayDiagnosticHint
set-face window InfoDiagnosticInformation      InlayDiagnosticInfo
set-face window InfoDiagnosticWarning          InlayDiagnosticWarning

# .............................................................. kak-tree-sitter

set-face window ts_attribute                   attribute
set-face window ts_comment                     comment
set-face window ts_conceal                     comment
set-face window ts_constant                    constant
set-face window ts_constant_builtin_boolean    constant
set-face window ts_constant_character          constant
set-face window ts_constant_macro              constant
set-face window ts_constructor                 operator
set-face window ts_diff_plus                   "${diffplus}"
set-face window ts_diff_minus                  "${diffminus}"
set-face window ts_diff_delta                  "${diffdelta}"
set-face window ts_diff_delta_moved            "${diffmoved}"
set-face window ts_error                       InlayDiagnosticError
set-face window ts_function                    function
set-face window ts_function_builtin            function
set-face window ts_function_macro              function
set-face window ts_hint                        InlayDiagnosticHint
set-face window ts_info                        InlayDiagnosticInfo
set-face window ts_keyword                     keyword
set-face window ts_keyword_conditional         keyword
set-face window ts_keyword_control_conditional keyword
set-face window ts_keyword_control_directive   keyword
set-face window ts_keyword_control_import      keyword
set-face window ts_keyword_directive           keyword
set-face window ts_label                       header
set-face window ts_markup_bold                 header
set-face window ts_markup_heading              header
set-face window ts_markup_heading_1            header
set-face window ts_markup_heading_2            header
set-face window ts_markup_heading_3            header
set-face window ts_markup_heading_4            header
set-face window ts_markup_heading_5            header
set-face window ts_markup_heading_6            header
set-face window ts_markup_heading_marker       header
set-face window ts_markup_italic               "+i"
set-face window ts_markup_list_checked         list
set-face window ts_markup_list_numbered        list
set-face window ts_markup_list_unchecked       list
set-face window ts_markup_list_unnumbered      list
set-face window ts_markup_link_label           link
set-face window ts_markup_link_url             link
set-face window ts_markup_link_uri             link
set-face window ts_markup_link_text            link
set-face window ts_markup_quote                string
set-face window ts_markup_raw                  block
set-face window ts_markup_strikethrough        "+s"
set-face window ts_namespace                   module
set-face window ts_operator                    operator
set-face window ts_property                    type
set-face window ts_punctuation                 operator
set-face window ts_punctuation_special         operator
set-face window ts_special                     operator
set-face window ts_spell                       InlayDiagnosticWarning
set-face window ts_string                      string
set-face window ts_string_regex                string
set-face window ts_string_regexp               string
set-face window ts_string_escape               string
set-face window ts_string_special              string
set-face window ts_string_special_path         string
set-face window ts_string_special_symbol       string
set-face window ts_string_symbol               string
set-face window ts_tag                         type
set-face window ts_tag_error                   InlayDiagnosticError
set-face window ts_text                        "$foreground"
set-face window ts_text_title                  title
set-face window ts_type                        type
set-face window ts_type_enum_variant           type
set-face window ts_variable                    variable
set-face window ts_variable_builtin            variable
set-face window ts_variable_other_member       variable
set-face window ts_variable_parameter          variable
set-face window ts_warning                     InlayDiagnosticWarning

	COLORSCHEME
}
