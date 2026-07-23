__NAME__ = faouzia
__NAME_CLIENT__ = sirocco
__CONFIG_NAME__ = faouziarc
VERCMD ?= git describe 2> /dev/null
__THIS_VERSION__ = $(shell $(VERCMD) || cat VERSION)

PREFIX    ?= /usr/local
MANPREFIX ?= $(PREFIX)/share/man
MANDIR    ?= $(MANPREFIX)/man1
DOCPREFIX ?= $(PREFIX)/share/doc
XSESSIONS ?= $(PREFIX)/share/xsessions

CFLAGS += -std=c99 -Wall -Wextra -O2
LDFLAGS += -lm -lxcb -lxcb-ewmh -lxcb-icccm -lxcb-randr -lxcb-keysyms -lxcb-render
