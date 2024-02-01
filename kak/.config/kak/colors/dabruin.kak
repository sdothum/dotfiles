#
# brun.kak by nasmevka
# file structure based on base16.kak
#

evaluate-commands %sh{
	dim() {
		printf "${1#*:}\n" | fold -b2 | while read -r hex; do
			base10="$(printf '%d' "0x${hex}")"
			printf '%02x' "$(( $base10 * ${2:-5 / 9} ))"
		done | xargs printf 'rgb:%s'
	}

	# base
	accent="${kak_opt_dabruin_accent:-rgb:FFB852}"
	background='rgb:242124'
	foreground='rgb:F5F5F5'
	grey='rgb:B2BECA'
	deep='rgb:3D4C59'

	# dim
	accent_dim="$(dim "${accent}")"
	foreground_dim="$(dim "${foreground}")"
	grey_dim="$(dim "${grey}")"

	# code
	cat <<-COLORSCHEME
		face global value              ${foreground_dim}+i
		face global type               ${foreground}+bu
		face global variable           ${foreground}+i
		face global module             string
		face global function           ${accent_dim}+i
		face global string             ${grey}+i
		face global keyword            ${accent}
		face global operator           ${foreground}
		face global attribute          ${foreground}+i
		face global comment            ${deep}
		face global documentation      comment
		face global meta               ${accent_dim}+b
		face global builtin            ${foreground}+i

		face global title              ${accent}+bi
		face global header             title
		face global mono               string
		face global block              mono
		face global link               ${accent_dim}+u
		face global bullet             ${foreground_dim}
		face global list               bullet

		face global Default            ${foreground},${background}
		face global PrimarySelection   ${background},${accent}+fg
		face global SecondarySelection ${background},${accent_dim}+fg
		face global PrimaryCursor      ${background},${foreground}+fg
		face global SecondaryCursor    ${background},${foreground_dim}+fg
		face global PrimaryCursorEol   ${grey}+r
		face global SecondaryCursorEol ${grey_dim}+r
		face global LineNumbers        ${grey_dim},${background}
		face global LineNumbersWrapped ${background},${background}
		face global LineNumberCursor   ${foreground},${background}
		face global MenuForeground     ${accent},${background}+rb
		face global MenuBackground     ${foreground},${background}
		face global MenuInfo           ${accent}@MenuBackground
		face global Information        ${accent}+b@MenuBackground
		face global Error              red
		face global DiagnosticError    red
		face global DiagnosticWarning  yellow
		face global StatusLine         ${foreground},${background}
		face global StatusLineMode     ${accent}
		face global StatusLineInfo     ${grey}
		face global StatusLineValue    ${grey}
		face global StatusCursor       ${accent},${background}+r
		face global Prompt             ${accent},${background}
		face global MatchingChar       default+rfg@PrimaryCursor
		face global BufferPadding      ${deep},${background}+F
		face global Whitespace         ${deep},${background}+f
	COLORSCHEME
}
