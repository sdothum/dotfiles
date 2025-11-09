
# SEE:  find.kak from https://github.com/occivink/kakoune-find.git
#
# NOTE: 1. commands have been renamed to "search-*" for distinction from original kakoune-find
#       2. modified for columnar output (vertical alignment of line content):
#              right justify -> ..buffer:line:column│  source code..  <- left justify
#          for enhanced readability of filtered lines
#       3. SecondarySelection highlight face for search pattern
#          comment highlight face used for buffer:line:column reference
#       4. search pattern remains for buffer-prev, buffer-next, buffer last
#          return into *search* buffer (unless %reg{/} is consequently altered)
#          SEE: console-plugins for extended *search* buffer handling
# ATTN: command abbreviations expanded to long form kak names (for syntax highlighting of plugin structure)
#       (un)set-option toolsclient, jumpclient removed and replaced with '*' in evaluate-commands -client, -try-client

# search for a regex pattern among all opened buffers
# similar to grep.kak

declare-option -hidden int search_current_line 0
declare-option -hidden str search_pattern  # ADDED: for persistent *search* buffer %reg{/} and highlighting

define-command -params ..1 -docstring "
search [<pattern>]: search for a pattern in all buffers
If <pattern> is not specified, the content of the main selection is used
" search %{
	try %{
		evaluate-commands %sh{ [ -z "$1" ] && echo 'fail' }
		set-register / %arg{1}
		set-option global search_pattern %arg{1}  # ATTN: must have 'global' scope (??) 'buffer' results in (mismatch) pattern prefix
	} catch %{
		execute-keys -save-regs '' '*'
	}
	evaluate-commands -draft -save-regs '"' %{
		try %{ delete-buffer *search* }
		# debug so that it's not included in the iteration
		edit -scratch -debug *search-tmp*
		evaluate-commands -no-hooks -buffer * %{
			try %{
				execute-keys '%s<ret>'
				# merge selections that are on the same line
				execute-keys '<a-s><a-L><a-;>;'
				evaluate-commands -save-regs 'c"' -itersel %{
					set-register c "%val{bufname}:%val{cursor_line}:%val{cursor_column}│䷀"  # NOTE: replace column: with visual separator and column delimeter
					# expand to full line and yank
					execute-keys -save-regs '' '<semicolon>xHy'
					# paste context followed by the selection
					# older Kakoune doesn't select pasted text so make sure we
					# to move the cursor to the end of the pasted text after P
					execute-keys -buffer *search-tmp* 'geo<esc>"cPhglp'
				}
			}
		}
		execute-keys -save-regs '' 'd%y'
		delete-buffer *search-tmp*
		edit -scratch *search*
		execute-keys R
		execute-keys "%%| column -t -s䷀ -R1 -o'  '<ret>gg"                # ATTN: reformat list into columnar format
		set-option buffer search_current_line 0
		add-highlighter buffer/ regex "%reg{/}" 0:SecondarySelection
		# final so that %reg{/} doesn't get highlighted in the header
		add-highlighter buffer/ regex "^([^\n]+:\d+:\d+│)" 1:comment      # NOTE: highlight source triplet as single field SEE: duochrome theme
		add-highlighter buffer/ line '%opt{search_current_line}' default+b  # NOTE: +bold highlight of line returned from after search-jump
		map buffer normal <ret> :search-jump<ret>
	}
	evaluate-commands -try-client * %{
		buffer *search*
	}
}

define-command -hidden search-apply-impl -params 4 %{
	evaluate-commands -buffer %arg{1} %{
		try %{
			# go to the target line and select it (except for \n)
			execute-keys "%arg{2}g<semicolon>xH"
			# check for noop, and abort if it's one
			set-register / %arg{3}
			execute-keys <a-K><ret>
			# replace
			set-register '"' %arg{4}
			execute-keys R
			set-register s "%reg{s}o"
		} catch %{
			set-register i "%reg{i}o"
		}
	}
}

define-command -hidden search-apply-force-impl -params 4 %{
	try %{
		search-apply-impl %arg{@}
	} catch %{
		# the buffer wasn't open: try editing it
		# if this fails there is nothing we can do
		evaluate-commands -verbatim -no-hooks -draft -- edit -existing %arg{1}
		search-apply-impl %arg{@}
		evaluate-commands -no-hooks -buffer %arg{1} "write; delete-buffer"
	}
}

define-command search-apply-changes -params ..1 -docstring "
search-apply-changes [-force]: apply changes specified in the current buffer to their respective file
If -force is specified, changes will also be applied to files that do not currently have a buffer
" %{
	evaluate-commands -no-hooks -save-regs 'csif' %{
		set-register s ""
		set-register i ""
		set-register f ""
		set-register c %sh{ [ "$1" = "-force" ] && printf 'search-apply-force-impl' || printf 'search-apply-impl' }
		evaluate-commands -save-regs '/"' -draft %{
			# select all lines that match the *search* pattern
			execute-keys '%3s^ *([^\n]+?):(\d+)(?::\d+)?│  ([^\n]*)$<ret>'  # NOTE: pattern adjusted for columnar table format
			evaluate-commands -itersel %{
				try %{
					execute-keys -save-regs '' <a-*>
					%reg{c} %reg{1} %reg{2} "\A%reg{/}\z" %reg{3}
				} catch %{
					set-register f "%reg{f}o"
				}
			}
		}
		echo -markup %sh{
			printf "{Information}"
			s=${#kak_main_reg_s}
			[ $s -ne 1 ] && p=s
			printf "%i change%s applied" "$s" "$p"
			i=${#kak_main_reg_i}
			[ $i -gt 0 ] && printf ", %i ignored" "$i"
			f=${#kak_main_reg_f}
			[ $f -gt 0 ] && printf ", %i failed" "$f"
		}
	}
}

define-command -hidden search-jump %{
	evaluate-commands %{
		try %{
			execute-keys -save-regs '' '<semicolon>xs^ *([^\n]+):(\d+):(\d+)│<ret>'  # NOTE: pattern adjusted for columnar table format
			set-option buffer search_current_line %val{cursor_line}
			evaluate-commands -try-client * -verbatim -- edit -existing %reg{1} %reg{2} %reg{3}
			set-register / %opt{search_pattern}  # NOTE: restore register for return to *search* buffer (??) %reg{/} is appended with -save-regs expression above
			try %{ focus * }
		}
	}
}

define-command search-next-match -docstring 'Jump to the next search match' %{
	evaluate-commands -try-client * %{
		buffer '*search*'
		execute-keys "%opt{search_current_line}ggl/^[^\n]+:\d+:\d+:<ret>"
		search-jump
	}
	try %{ evaluate-commands -client * %{ execute-keys %opt{search_current_line}g } }
}

define-command search-previous-match -docstring 'Jump to the previous search match' %{
	evaluate-commands -try-client * %{
		buffer '*search*'
		execute-keys "%opt{search_current_line}g<a-/>^[^\n]+:\d+:\d+:<ret>"
		search-jump
	}
	try %{ evaluate-commands -client * %{ execute-keys %opt{search_current_line}g } }
}

# kak: filetype=kak
