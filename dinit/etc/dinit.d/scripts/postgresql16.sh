#!/bin/sh
# Code from Void Runit

. /etc/psql16/default/postgresql
PGDATA="$PGROOT/data"

if [ "$PGROOT" != "/var/lib/postgresql16" ]; then
	echo "Creating symlink /var/lib/postgresql16 -> $PGROOT"
	ln -sf "$PGROOT" /var/lib/postgresql16
fi

if [ ! -d "$PGDATA" ]; then
	echo "Initializing database in $PGDATA"

	mkdir -p "$PGDATA" || exit 1
	chown -R postgres:postgres "$PGDATA"
	chmod 0700 "$PGDATA"
	su - postgres -c "/usr/lib/psql16/bin/initdb $INITOPTS -D '$PGDATA'" 2>&1 || {
		rm -fr "$PGDATA"
		exit 1
	}

	if [ -f /etc/psql16/postgresql/postgresql.conf ]; then
		ln -sf /etc/psql16/postgresql/postgresql.conf "$PGDATA/postgresql.conf"
	fi
fi

/usr/lib/psql16/bin/postgres -D "$PGDATA" $PGOPTS 2>&1
