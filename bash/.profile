export PGDATA=/var/lib/postgresql/15/data
[ -e /home/shum/go/bin ] && export PATH="/home/shum/go/bin:$PATH"
[ -e /home/shum/.cargo/bin ] && export PATH="/home/shum/.cargo/bin:$PATH"
which fish >/dev/null 2>&1 && fish && exit
