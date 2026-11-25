# Offline Nim builds. Installation copies existing artifacts; activation is separate.
NIM ?= /usr/lib/nim/bin/nim
BUILD_DIR ?= build
CACHE_DIR ?= $(BUILD_DIR)/nimcache
VERSION ?= 0.5.2

PREFIX ?= /usr/local
DESTDIR ?=
BINDIR ?= $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man
INSTALL ?= install

PROGRAMS := aureole borealis aether aetherd
MANPAGES := aureole/man/aureole.1 borealis/man/borealis.1 aether/man/aether.1 aether/man/aetherd.1

AUREOLE_SOURCES := $(wildcard aureole/*.nim aureole/model/*.nim aureole/runtime/*.nim aureole/runtime/*.c aureole/startup/*.nim aureole/x11/*.nim aureole/x11/*.c)
AETHER_SOURCES := $(wildcard aether/*.nim aether/wm/*.nim aether/policy/*.nim)
BOREALIS_SOURCES := $(wildcard borealis/*.nim borealis/*.cfg)

.PHONY: all aureole borealis aether aetherd install uninstall clean
all: aureole borealis aether aetherd

aureole: $(BUILD_DIR)/aureole
borealis: $(BUILD_DIR)/borealis
aether: $(BUILD_DIR)/aether
aetherd: $(BUILD_DIR)/aetherd

$(BUILD_DIR)/aureole: $(AUREOLE_SOURCES) Makefile
	mkdir -p "$(BUILD_DIR)" "$(CACHE_DIR)/aureole"
	$(NIM) c --hints:off --warnings:on --path:aureole --nimcache:"$(CACHE_DIR)/aureole" --out:"$@" -d:LegacyVersion=$(VERSION) aureole/aureole.nim

$(BUILD_DIR)/borealis: $(BOREALIS_SOURCES) Makefile
	mkdir -p "$(BUILD_DIR)" "$(CACHE_DIR)/borealis"
	$(NIM) c -d:release -d:noSignalHandler -d:clientVersion=$(VERSION) --warnings:on --path:borealis --nimcache:"$(CACHE_DIR)/borealis" --out:"$@" borealis/borealis.nim

$(BUILD_DIR)/aether: $(AETHER_SOURCES) Makefile
	mkdir -p "$(BUILD_DIR)" "$(CACHE_DIR)/aether"
	$(NIM) c -d:release --warnings:on --path:aether --nimcache:"$(CACHE_DIR)/aether" --out:"$@" aether/aether.nim

$(BUILD_DIR)/aetherd: $(AETHER_SOURCES) Makefile
	mkdir -p "$(BUILD_DIR)" "$(CACHE_DIR)/aetherd"
	$(NIM) c -d:release --warnings:on --path:aether --nimcache:"$(CACHE_DIR)/aetherd" --out:"$@" aether/aetherd.nim

# Deliberately no build prerequisites: sudo make install must not compile.
# Check every input before creating destinations or copying any files.
install:
	@set -eu; \
	for name in $(PROGRAMS); do \
		test -f "$(BUILD_DIR)/$$name" && test -x "$(BUILD_DIR)/$$name" || { \
			echo "Missing executable $(BUILD_DIR)/$$name; run make as your normal user first." >&2; exit 1; }; \
	done; \
	for page in $(MANPAGES); do \
		test -f "$$page" && test -r "$$page" || { \
			echo "Missing manual $$page" >&2; exit 1; }; \
	done
	$(INSTALL) -d -m 0755 "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(MANDIR)/man1"
	@set -e; for name in $(PROGRAMS); do \
		$(INSTALL) -m 0755 "$(BUILD_DIR)/$$name" "$(DESTDIR)$(BINDIR)/$$name"; \
	done
	@set -e; for page in $(MANPAGES); do \
		$(INSTALL) -m 0644 "$$page" "$(DESTDIR)$(MANDIR)/man1/$${page##*/}"; \
	done

# Remove exactly the eight installed names, leaving shared directories intact.
uninstall:
	@set -e; for name in $(PROGRAMS); do \
		rm -f -- "$(DESTDIR)$(BINDIR)/$$name" "$(DESTDIR)$(MANDIR)/man1/$$name.1"; \
	done

# Never recursively remove BUILD_DIR: it can contain retained verification logs.
clean:
	@set -eu; for dir in "$(abspath $(BUILD_DIR))" "$(abspath $(CACHE_DIR))"; do \
		case "$$dir" in ""|/|"$(CURDIR)"|"$(CURDIR)/aureole"|"$(CURDIR)/aureole/"*|"$(CURDIR)/borealis"|"$(CURDIR)/borealis/"*|"$(CURDIR)/aether"|"$(CURDIR)/aether/"*|"$(CURDIR)/shared"|"$(CURDIR)/shared/"*) \
			echo "Refusing clean with unsafe build/cache directory: $$dir" >&2; exit 1;; \
		esac; \
	done
	@set -e; for name in $(PROGRAMS); do \
		rm -f -- "$(BUILD_DIR)/$$name"; \
		rm -rf -- "$(CACHE_DIR)/$$name"; \
	done
