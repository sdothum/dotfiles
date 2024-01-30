provide-module search-doc %~

declare-option \
    -docstring 'A list of directories from where search-doc looks for documentation recursively' \
    str-list search_doc_path \
    "%val(config)/autoload" \
    "%val(runtime)/doc" \
    "%val(runtime)/rc"

evaluate-commands %sh(
    test -d "$kak_opt_plug_install_dir" &&
        printf "%s" 'set-option -add global search_doc_path "%opt(plug_install_dir)"'
)

declare-option -hidden str search_doc_docstring "search-doc <topic>: search kak documentation for a topic"

# A shell script that must be safe to include in %sh(...)-expansions.
# Requires a variable "task" to be set.
declare-option -hidden str search_doc_script %(
    get_directories_0 ()
    {
        local some=
        eval set -- "$kak_quoted_opt_search_doc_path"
        for directory
        do
            if test -d "$directory"; then
                printf '%s\0' "$directory"
                some=1
            fi
        done
        if ! test "$some"; then
            printf '%s\n' 'search-doc: found no documentation pages'
            exit 1
        fi | tee /dev/stderr
    }

    get_pages ()
    {
        xargs -0 '-I{}' find -L '{}' -type f -name "*.asciidoc" |
            ruby --disable-gems -e '
                strings_to_delete = ["*", "`", "'"'"'"]
                puts(
                  STDIN.each_line(chomp: true).flat_map do |pagename|
                    simplified_page = pagename[/([^\/]*)\.asciidoc$/, 1]
                    most_recent_title = nil
                    File.open(pagename) do |io|
                      io.each_line.map do |content|
                        next unless content = content[/^\*.*[^:](?=::)|^=+ .*/]
                        if title = content[/^=+ (.*)/, 1]
                          most_recent_title = title
                          nil
                        elsif most_recent_title
                          strings_to_delete.each {|s| content.gsub!(s, "")}
                          [simplified_page, content, most_recent_title]
                        end
                      end.compact
                    end
                  end.map do |simplified_page, content, title|
                    "#{content} (#{simplified_page}: #{title})"
                  end.to_a
                )
            '
    }

    get_specific_page ()
    {
        xargs -0 '-I{}' find -L '{}' -type f -name "$filename.asciidoc" | head -n1
    }

    render_page ()
    {
        local page="$(cat)"
        if [ -f "${page}" ]; then
            printf %s\\n "evaluate-commands -save-regs / -try-client %opt{docsclient} %{
                doc-render ${page}
                try %(
                    set-register / '^\Q$coarse_topic\E$'
                    execute-keys /<ret>
                )
                set-register / '^\Q$fine_topic\E$'
                execute-keys /<ret>vv
            }"
        else
            printf 'fail No such doc page: %s\n' "${page}"
        fi
    }

    case "$task" in
    # balance parentheses for kak: (
    "candidates")
        get_directories_0 | get_pages
        ;;
    # balance parentheses for kak: (
    "render")
        get_directories_0 | get_specific_page | render_page
        ;;
    # balance parentheses for kak: (
    *)
        printf '%s' "search-doc.kak: Internal bug with unknown task '$1'" >&2
        exit 1
        ;;
    esac
)

# A shell script that returns kakoune command parameter completion options,
# one option per line.
# This must be safe to include in %sh(...) expansions.
# See also: %val(runtime)/tools/doc.kak
declare-option -hidden str search_doc_candidates "task=candidates; %opt(search_doc_script)"

# Define the 'search-doc' command in such a way that it computes parameter
# candidates on demand and then redefines itself.
define-command search-doc \
    -params 1 \
    -docstring "%opt(search_doc_docstring)" \
    -shell-script-candidates "%opt(search_doc_candidates)" \
%(
    search-doc-impl %arg(@)
    search-doc-redefine
)

# The actual implementation of the 'search-doc' command.
define-command search-doc-impl -hidden -params 1 \
%[
    search-doc-impl-impl %sh[
        content_and_title="${1##* (}"
        content_and_title="${content_and_title%)}"
        printf "%s" "${content_and_title%: *}"
    ] %sh[
        content_and_title="${1##* (}"
        content_and_title="${content_and_title%)}"
        printf "%s" "${content_and_title##*: }"
    ] %sh[
        printf "%s" "${1% (*}"
    ]
]

# A helper command used by 'search-doc' to go to the desired documentation.
define-command search-doc-impl-impl -hidden -params 3 %(
    evaluate-commands "evaluate-commands %%sh(
        task=render
        filename=""$1""
        coarse_topic=""$2""
        fine_topic=""$3""
        %opt(search_doc_script)
    )"
)

# A helper command that precomputes parameter candidates and then overrides the
# 'search-doc' command to use those candidates.
define-command search-doc-redefine -hidden %(
    evaluate-commands \
        declare-option -hidden str search_doc_evaluated_candidates \
            "%%sh(%opt(search_doc_candidates))"
    define-command search-doc \
        -params 1 \
        -docstring "%opt(search_doc_docstring)" \
        -override \
        -shell-script-candidates %(
            printf "%s\n" "$kak_opt_search_doc_evaluated_candidates"
        ) %(search-doc-impl %arg(@))
)

~
