# sdothum - 2016 (c) wtfpl

# Fish Shell
# ══════════════════════════════════════════════════════════════════════════════

# ................................................................. Command line

# turn off
set fish_greeting
set -Ua fish_features no-keyboard-protocols  # FOR: termux (fixes '5u' prompt characters)

# only shells with vi mode accepted here!
# fish_vi_key_bindings >/dev/null  # suppress fish_vi_key_bindings eval error!!
fish_vi_key_bindings

# fuzzy searches
test -e /usr/share/fish/completions/autojump.fish
and source /usr/share/fish/completions/autojump.fish

# ............................................................ Shell environment

# default shell
set -x SHELL /usr/bin/fish
set -x XTERM_SHELL /usr/bin/fish
set -x KEYTIMEOUT 1

# paths
set -x CACHEDIR $HOME/.cache
set -x CDPATH . .. ../.. ~ ~/.config ~/build ~/stow /usr / >/dev/null
echo $PATH | grep -q "$HOME/.gem/ruby/(rubyver)/bin"
or set -x PATH $PATH ~/.gem/ruby/(rubyver)/bin ~/.cabal/bin /bin /sbin /usr/sbin /usr/bin/core_perl /usr/local/games >/dev/null

# cli filemanager
set -x FILEMANAGER yazi

# ........................................................... System environment

set -x LC_ALL en_US.UTF-8
set -x LANG en_US.UTF-8
set -x export LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib

# gpg key
test -S ~/.gnupg/S.gpg-agent
and set -x GPG_AGENT_INFO ~/.gnupg/S.gpg-agent
set -x PASSWORD_STORE_CLIP_TIME 60

# ..................................................................... Hardware

# set -x COLEMAK true
set -x TERM xterm-256color

# ......................................................................... Xorg

set -x QT_QPA_PLATFORMTHEME qt5ct

# .......................................................................... LAN

# default printer
set -x PRINTER HP_LaserJet_1320_series
set -x PROOF $HOME/.proof

# main server
set -x SERVER motu
set -x SELF_URL_PATH http://$SERVER:8000/tt-rss/

# ..................................................................... Internet

# proxies
# [ -z (pidof privoxy) ] ;or set -x HTTP_PROXY localhost:8118
# [ -z (pidof squid) ] ;or set -x HTTP_PROXY http://localhost:3128/
# pong luna ;and set -x HTTP_PROXY http://luna:3128/

test -n $HTTP_PROXY
and set -x http_proxy $HTTP_PROXY

set -x XDG_DOWNLOAD_DIR /net/downloads/http
set -x NNTPSERVER news.sunnyusenet.com
set -x NO_PROXY '*'                       # required by webkit browsers to access gmail
set -x WEBKIT_DISABLE_COMPOSITING_MODE  1  # prevent blank web pages with nvidia
# ..................................................................... Defaults

# default editor
# set -x EDITOR 'vi -e'
# set -x EDITOR vim
# set -x VISUAL 'gvim -f'
# set -x VISUAL 'vim -g -f'   # foreground required for crontab -e ..avoids gvim library errors (?)
# let scripts set helix/kak calls (whether term, foreground or not)
set -x VISUAL '/usr/bin/kak'  # foreground required for crontab -e

set -x XIVIEWER feh
set -x PLAYER mpv
# less prompt (replaced by wrapper to be able to set prompt colour)
# set -x LESS '-RX -P ?B %f  %lt-%lb/%L  %Pb\%: [pipe]  %lt-%lb/\.\.'
set -x PAGER less
set -x PAGER pager  # my smart pager

# ..................................................... Development environments

# NOTE: required to recover AMD performance for intel-MKL libraries (looking at you python)
set -x MKL_DEBUG_CPU_TYPE 5

# java
set -x JAVA_HOME "/usr/lib/jvm/default-jvm"
# lua
set -x LUA_INIT "@$HOME/.luarc"
# python
set -x PYTHONPATH '/usr/lib/python3.12'
# ruby
set -x RI '--format ansi --no-pager'

# for xmonad onhost
set -x HOST (hostname)
# commom configurations (dotfiles)
set -x STOW $HOME/stow

# ...................................................................... Session

set -x TMPDIR $HOME/tmp

set -x SESSION $HOME/.session
# proxy override
test -e $SESSION/http_proxy
and set -x HTTP_PROXY (cat $SESSION/http_proxy)

set -x XDG_DATA_HOME $HOME/.local/share
set -x XDG_DOWNLOAD_DIR /net/downloads/http
# set -x XDG_RUNTIME_DIR /tmp/runtime-$USER
set -x XDG_RUNTIME_DIR /run/user/(id -u)
sudo mkdir -p $XDG_RUNTIME_DIR
sudo chown $USER $XDG_RUNTIME_DIR
sudo chmod 700 $XDG_RUNTIME_DIR

set -x NNTPSERVER news.sunnyusenet.com

# ..................................................................... Browsers

# default browser changes require login (Ctrl-d) for X11 autostart
# test (cpu) = celeron
#   and set -x BROWSER vimb
#   or  set -x BROWSER qutebrowser
# set -x BROWSER surf
# set -x BROWSER vimb
test -n $SESSION/browser
and set -x BROWSER (cat $SESSION/browser 2>/dev/null)
test -z $BROWSER
and set -x BROWSER qutebrowser

# ................................................................. Applications

# source shell variables
function SOURCE --description 'Usage: SOURCE <script>'
	for i in (grep '^export ' $argv)
			eval $i
	end
end

# for alot mail
set -x VIM /usr/share/vim/vim9*

# suppress missing google api keys message 
set -x GOOGLE_API_KEY no
set -x GOOGLE_DEFAULT_CLIENT_ID no
set -x GOOGLE_DEFAULT_CLIENT_SECRET no

# for chatgpt https://platform.openai.com/account/api-keys
set -x OPENAI_API_KEY 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
set -x AICHAT_API_KEY $OPENAI_API_KEY

# source nnn environment (and LS_COLORS)
# SOURCE $HOME/bin/functions/shell/nnn
set -x LS_COLORS "di=01;38;5;221:ex=00;38;5;40:ln=00;38;5;51"

# .................................................................. Directories

set -x corne $HOME/stow/corne/qmk_firmware/keyboards/crkbd/keymaps
set -x chimera $HOME/stow/chimera/qmk_firmware/keyboards/chimera_ergo_42/keymaps
set -x planck $HOME/stow/planck/qmk_firmware/keyboards/planck/keymaps
set -x splito $HOME/stow/splitography/qmk_firmware/keyboards/splitography/keymaps

# ............................................................... Initialization

console_login
if [ -e $SESSION/boot:wm ] 
	pgrep -f "sshd: $USER" >/dev/null || user_login
else
	user_login
end
# clear 'fish' tmux window name
pidof tmux >/dev/null 
	and begin 
		console 
			or tmux rename-window '' 
	end

exists zoxide
	and zoxide init fish | source
