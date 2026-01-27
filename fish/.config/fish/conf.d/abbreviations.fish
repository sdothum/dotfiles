# sdothum - 2016 (c) wtfpl

# Fish Shell
# ══════════════════════════════════════════════════════════════════════════════

# ...................................................................... Package

if arch
	abbr pkgs 'comm -23 <(pacman -Qeq | sort) <(pacman -Qgq base base-devel | sort)'
	abbr pn 'env D=N pd'
	abbr pq 'pacman -Qii'
end

# ................................................................... Supervisor

abbr halt 'supervisor halt'
abbr poweroff 'supervisor poweroff'
# abbr reboot 'supervisor reboot'
abbr shutdown 'supervisor shutdown'
abbr soft-reboot 'supervisor soft-reboot'

# ...................................................................... Service

abbr K 'env sig=-KILL k'
abbr KK 'env sig=-KILL kk'
abbr sv 'sv'  # override service abbrev (from fish-completions)
if alpine
	abbr sva 'sv add'
	abbr svd 'sv delete'
	abbr svi 'sv status'
	abbr svl 'sv list'
	abbr svq 'sv status'
	abbr svr 'sv restart'
	abbr svs 'sv start'
	abbr svt 'sv stop'
else if void 'dinit'
	abbr svd 'sv disable'
	abbr sve 'sv enable'
	abbr svs 'sv start'
	abbr svt 'sv stop'
	abbr svr 'sv restart'
	abbr svi 'sv status'
	abbr svl 'sv log'
else if void           # runit
	abbr svd 'sv disable'
	abbr svt 'sv down'
	abbr sve 'sv enable'
	abbr svm 'sv mask'  # at boot
	abbr svr 'sv restart'
	abbr svi 'sv status'
	abbr svs 'sv up'
	abbr svu 'sv UP'
else
	abbr svd 'sv disable'
	abbr sve 'sv enable'
	abbr svi 'sv info'
	abbr svl 'sv reload'
	abbr svm 'sv mask'
	abbr svr 'sv restart'
	abbr svs 'sv start'
	abbr svt 'sv stop'  # terminate
	abbr svu 'sv unmask'
end

# ....................................................................... Device

abbr close 'eject -t'
abbr left_shift_key 'test -f /etc/X11/Xmodmap; and xmodmap /etc/X11/Xmodmap'
abbr mmtp 'mtp mount'
abbr umtp 'mtp umount'
abbr mount 'sudo mount'
abbr umount 'sudo umount'

# ....................................................................... System

abbr blame 'systemd-analyze blame'
abbr font-manager 'font-manager;  rm -f ~/.fonts.conf'
abbr fontmatrix 'fontmatrix;  rm -f ~/.fonts.conf'
abbr gtop 'glances'
abbr htop 'htop --sort-key PERCENT_CPU'
abbr ttop 'htop --tree'
abbr iotop 'sudo iotop'
abbr lpr 'lpr -P hp-LaserJet-1320-series'
abbr screenfetch 'fetch'
abbr services "systemctl list-units -t service --no-pager --no-legend | grep active | grep -E -v 'systemd|exited' | cut -d' ' -f1"
abbr time '/usr/bin/time -p'
abbr traceroute 'mtr --report -c 1'
abbr who 'command w'

# ......................................................................... File

function b; bat (find -iname $argv[1]) ;end
function ba; bat (al $argv[1]) ;end

abbr c 'sudo cat'
abbr cp 'cp -i'
abbr cpf 'cp -rf'
abbr cpl 'cp -iLRfv'
abbr cpr 'cp -rf'
abbr cpv 'cp -iv'
abbr gprename 'gprename $PWD'
abbr hd 'head'
abbr m 'pager'
abbr mv 'mv -i'
abbr mvf 'mv -f'
abbr mvv 'mv -iv'
abbr r '/usr/bin/rsync --info=progress2 -a'
abbr r3 'rsync home; rsync library; rsync music'
abbr rm 'rm -i'
abbr rmf 'rm -rf'
abbr rmr 'rm -rf'
abbr rmv 'rm -iv'
abbr so 'sort -n'
abbr t 'sudo tail -f'
abbr tar 'tar -xvf'

# .................................................................... Directory

set -l HUMAN h

abbr df "df -$HUMAN"
abbr du "du -$HUMAN -d1"
abbr dus "/usr/bin/du -hs * | sort -h"
abbr l 'ls -A'
abbr l1 'ls -1 | print'
abbr ldot "ls -lAd$HUMAN .* | print"
abbr lL 'ls -AL'
abbr ll "ls -lA$HUMAN"
abbr llr "ls -lAR$HUMAN"
abbr lr "ls -LAR"
abbr ls "ll -S$HUMAN"
abbr lt "ll -t$HUMAN"
abbr mk "mkdir -p"
abbr path 'echo $PATH'
abbr pp 'pwd'
abbr tree 'sudo tree -aCF'
abbr treed 'sudo tree -aCdF'

# ................................................................. File manager

function hgc; hg cat -r $argv | bat; end

# abbr hgr 'hg revert -r'
abbr N 'nnn -p -'  # cmd .. (N) file picker mode
abbr n 'nnn'
abbr nb 'nnn -s ebooks'
# abbr r 'vifm'
# abbr R 'ranger'
abbr y 'yazi'
abbr Y 'set -x TERMBG light; yazi; set -u TERMBG' 

# ....................................................................... Search

function ww; cd (dirname (which $argv 2>/dev/null) 2>/dev/null); test $HOME = (pwd) and ditto "$argv" 'not found' and cd - ;end  # no 755 in $HOME

abbr a0 'a --depth 0'
abbr a1 'a --depth 1'
abbr a2 'a --depth 2'
abbr a3 'a --depth 3'
abbr aa 'clear; a'
abbr f 'find -iname'
abbr fi 'find'
abbr fr 'find -regex'
abbr ft 'find -type'
abbr f1 'find -maxdepth 1'
abbr ff1 'find -maxdepth 1 -type f'
abbr g 'ugrep --ignore-case'
abbr locate 'sudo locate'
abbr mgrep 'pcregrep -r -M'
abbr w 'which'

# ...................................................................... Desktop

abbr cl 'clear;  setterm -cursor on'
abbr cursor 'setterm -cursor on'
abbr gaps 'rlwrap -n gaps'
abbr h: 'ls -l /tmp/herbstluftwm:*'
abbr hc 'herbstclient'
abbr herbstluftwm ". $HOME/.config/herbstluftwm/config/ENV"
abbr L 'chefls'
abbr qkss 'qk stop; qk start'
abbr X x

# ......................................................................... Edit

function flirt:kak; test (count $argv) -gt 0 && z $argv; set -l f (flirt); test -z "$f" || kak $f ;end
function kf; kak (find -iname $argv[1]) ;end
function ndiff; set -l d (pwd); cd; for i in (nnn -p - $d); dirdiff -s $i ;end; cd - ;end 

abbr d 'diff'
abbr dd 'dirdiff -s'                         # sudo dd still does file copy
abbr nd 'ndiff'                              # file picker mode
abbr de 'dmenu - edit'
abbr dp 'dmenu - projects'
abbr dr 'dmenu - run'
abbr ds 'dmenu - scripts'
# abbr h 'helix'
abbr fk 'flirt:kak'
abbr K '/usr/local/bin/kak'                  # for filename with spaces
abbr k 'kak'
abbr kd 'kakdiff'
abbr kl 'kak -l'
abbr kp 'kak -p'
abbr nv 'nvpy'
abbr vd 'vi -d --role=gvimdiff'
abbr vdn 'vi -d --role=gvimdiff (nnn -p -)'  # file picker mode
abbr sd 'sdiff -b -E -W -w(tput cols)'
abbr vdarchive 'dirdiff ./ /net/archive(pwd)'
abbr vdbackup 'dirdiff ./ /net/backup(pwd)'

# ........................................................................ Regex

abbr indent "env tab=soft print"
abbr list "ls -A1 | tr '\n' ' ' | sed 's/ /|/g; s/|\$//'"

# .................................................................. Development

abbr dot 'rlwrap -n dotfiles'
# abbr ghc 'ghc -dynamic'  # arch repo only
abbr ghc 'stack ghc'
abbr ghcc 'stack build'
abbr ghcx 'stack runghc'
abbr ghci 'stack exec ghci'
abbr git1 'git clone --depth 1'
abbr gitb 'git clone --depth 1 --branch'
abbr mysql 'mysql -h localhost -u root -p'
abbr perli 'perl -de 1'

# ........................................................................ Shell

abbr fn 'function'  # fish shell shorthand
for i in (seq 1 9); abbr \$$i "\$argv[$i]" ;end
# function ncd; set -l f (/usr/bin/nnn -p - $argv[1]); test -d $f && z $f || z (dirname $f) ;end
function flirt:cd; test (count $argv) -gt 0 && z $argv; set -l f (flirt); test -d "$f" && z $f || z (dirname $f) ;end
function flirt:sh; test (count $argv) -gt 0 && z $argv; set -l IFS; set -l f (flirt); test -z "$f" || echo "$f" | vipe | sh ;end
function fishlog; history $argv | pager ;end

# abbr cd 'z'
# abbr nd 'ncd'
abbr dash 'rlwrap -n dash'
abbr fd 'flirt:cd'
abbr fh 'flirt:sh'
abbr hdel 'fishlog delete'
abbr h 'fishlog search'
abbr hk "kak $HOME/.local/share/fish/fish_history"
abbr hv "vi $HOME/.local/share/fish/fish_history"
abbr ma 'man'
abbr rl 'rlwrap'
abbr s 'sudo'
abbr sh 'bash -norc'
abbr ss 'sudo su -c fish'  # su otherwise just invokes sh
abbr uterm 'urxvt -sh 1'
abbr wl 'wc -l'
abbr zz 'z -'

# ........................................................................... AI

abbr \? 'chatgpt'
abbr \?\? 'chatgpt -n'  # new conversation
abbr \@ 'aichat'
abbr \@s 'aichat -r shell'
abbr \@c 'aichat -r c'
abbr \@g 'aichat -r go'
abbr \@j 'aichat -r julia'
abbr \@p 'aichat -r python'
abbr \@r 'aichat -r ruby'
abbr \@R 'aichat -r rust'

# ................................................................... calc / hex

abbr bc 'bcd'
abbr calc 'speedcrunch'
abbr color 'pastel format hex'
abbr hex 'hexdump -C'
abbr termhex "window size 1/3; $HOME/bin/functions/shell/termcolors hex"

# ................................................................... dictionary

if exists /usr/bin/sdcv
	abbr di 'sdcv -wn'
	abbr dox 'sdcv -uk'
	abbr dic 'sdcv -di'
	abbr th 'sdcv -th'
else
	abbr di 'dict'
	abbr ti 'dict -t'
end
abbr W 'words'

# ......................................................................... epub

abbr kc 'kconvert'
abbr kc0 "kconvert css='p { margin: 0 !important; }'"
abbr kcn 'kconvert noformat'
abbr kindle 'dmenu econvert azw3'
abbr eformat 'dmenu econvert reformat'
abbr kobo 'dmenu econvert epub'

# ........................................................................ media

abbr gif 'nsxiv -a'
abbr handbrake 'ghb'
abbr md 'lowdown -tterm'
abbr mdtxt 'lowdown -tterm --term-no-colour'
abbr miniflux-migrate 'sudo miniflux -c /etc/miniflux.conf -migrate'
# abbr music '!p ncmpcpp; and ncmpcpp'
abbr scrot 'scrot -e "mv \$f /net/photos/batchqueue/"'

# ......................................................................... test

abbr displaycal 'displaycal3'
abbr pts 'phoronix-test-suite'

# ..................................................................... metaflac

abbr mf 'metaflac'
abbr mfq 'metaflac -q'
abbr mfa 'metaflac -q artist'
abbr mfa: 'metaflac ls | grep -i artist='
abbr mfaa 'metaflac -q artist+'
abbr mfd 'metaflac -q date'
abbr mfd: 'metaflac ls | grep -i date='
abbr mfdn 'metaflac -q discnumber'
abbr mfex 'metaflac -q export'
abbr mfg 'metaflac -q genre'
abbr mfgg 'metaflac -q genre+'
abbr mfg: 'metaflac LS | grep -i genre='
abbr mfim 'metaflac -q import'
abbr mfl 'metaflac -q album'
abbr mfl: 'metaflac ls | grep -i "album="'
abbr mfla 'metaflac -q albumartist'
abbr mfr 'metaflac -q rm'
abbr mfrt 'metaflac -q rm track trackc'
abbr mft --set-cursor "metaflac -q title '/%"  # --set-cursor to % (do not pad space after slash)
abbr mft: 'metaflac ls | grep -i "title="'
abbr mftu "metaflac -q title '/\<./\U&/g'"
abbr mftn "metaflac -q tracknumber"
abbr mftn: 'metaflac ls | grep -i "track.*="'
