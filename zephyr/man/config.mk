__NAME__ = zephyr
__NAME_CLIENT__ = zephyr
__CONFIG_NAME__ = zephyr
VERCMD ?= git describe 2> /dev/null
__THIS_VERSION__ = $(shell $(VERCMD) || cat VERSION)

PREFIX    ?= /usr/local
MANPREFIX ?= $(PREFIX)/share/man
MANDIR    ?= $(MANPREFIX)/man1
DOCPREFIX ?= $(PREFIX)/share/doc
XSESSIONS ?= $(PREFIX)/share/xsessions

CFLAGS += -std=c99 -Wall -Wextra -O2
LDFLAGS += -lm -lxcb -lxcb-ewmh -lxcb-icccm -lxcb-randr -lxcb-keysyms -lxcb-render
