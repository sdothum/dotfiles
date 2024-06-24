	source "%val{config}/bundle/kak-bundle/rc/kak-bundle.kak"
	bundle-noload kak-bundle https://github.com/jdugan6240/kak-bundle

	# ........................................................... lua interpreter
	bundle luar https://github.com/gustavo-hms/luar.git %{
		require-module luar
		set-option global luar_interpreter luajit
	}

	# .................................................... peneira (fuzzy finder)
	bundle peneira https://github.com/gustavo-hms/peneira.git %{
		require-module luar
		require-module peneira
		set-option global peneira_files_command "rg --files --sort=path"  # single threaded --sort is fast enough for my folder organization

		# HACK: multi-client focus switching causes peneira to lose active client buffer directory
		define-command peneira-resync %{
			# change-directory-current-buffer  # handled by hook FocusIn above, otherwise required
			buffer *debug*
			execute-keys ga
		}

		define-command buffers %{
			peneira-resync
			peneira 'buffers: ' %{ printf '%s\n' $kak_quoted_buflist } %{ buffer %arg{1} }
		}

		define-command files %{
			peneira-resync
			peneira-files -hide-opened
		}

		map global user b ': buffers<ret>' -docstring 'buffers'
		map global user e ': files<ret>'   -docstring 'edit file'
	}

