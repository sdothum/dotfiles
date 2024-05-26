#!/bin/sh
# Code from Void Runit

# Miminum memory that the system should have for preload to be launched.
# In megabytes.
MIN_MEMORY=256

# Command-line arguments to pass to the daemon.  Read preload(8) man page
# for available options.
OPTS="--verbose 1"

# Option to call ionice with.  Leave empty to skip ionice.
IONICE_OPTS=-c3
IONICE=/usr/bin/ionice

free -m | awk '/Mem:/ {exit ($2 >= ('"$MIN_MEMORY"'))?0:1}' || exit 0

if [ -n "$IONICE_OPTS" ]; then
	if [ -x "$IONICE" ]; then
		RUNNER="$IONICE $IONICE_OPTS"
	else
		echo "ionice not found, running with normal io priority" 1>&2
	fi
fi

exec $RUNNER preload $OPTS -f 2>&1
