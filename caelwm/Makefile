# Offline Nim builds only. Installation and session activation are separate.
NIM ?= /usr/lib/nim/bin/nim
BUILD_DIR ?= build
CACHE_DIR ?= $(BUILD_DIR)/nimcache
VERSION ?= 0.5.2

AUREOLE_SOURCES := $(wildcard aureole/*.nim aureole/model/*.nim aureole/runtime/*.nim aureole/runtime/*.c aureole/startup/*.nim aureole/x11/*.nim aureole/x11/*.c)
AETHER_SOURCES := $(wildcard aether/*.nim aether/wm/*.nim aether/policy/*.nim)
BOREALIS_SOURCES := $(wildcard borealis/*.nim borealis/*.cfg)

.PHONY: all aureole borealis aether aetherd
all: aureole borealis aether aetherd

aureole: $(BUILD_DIR)/aureole
borealis: $(BUILD_DIR)/borealis
aether: $(BUILD_DIR)/aether
aetherd: $(BUILD_DIR)/aetherd

$(BUILD_DIR)/aureole: $(AUREOLE_SOURCES)
	mkdir -p "$(BUILD_DIR)" "$(CACHE_DIR)/aureole"
	$(NIM) c --hints:off --warnings:on --path:aureole --nimcache:"$(CACHE_DIR)/aureole" --out:"$@" -d:LegacyVersion=$(VERSION) aureole/aureole.nim

$(BUILD_DIR)/borealis: $(BOREALIS_SOURCES)
	mkdir -p "$(BUILD_DIR)" "$(CACHE_DIR)/borealis"
	$(NIM) c -d:release -d:noSignalHandler -d:clientVersion=$(VERSION) --warnings:on --path:borealis --nimcache:"$(CACHE_DIR)/borealis" --out:"$@" borealis/borealis.nim

$(BUILD_DIR)/aether: $(AETHER_SOURCES)
	mkdir -p "$(BUILD_DIR)" "$(CACHE_DIR)/aether"
	$(NIM) c -d:release --warnings:on --path:aether --nimcache:"$(CACHE_DIR)/aether" --out:"$@" aether/aether.nim

$(BUILD_DIR)/aetherd: $(AETHER_SOURCES)
	mkdir -p "$(BUILD_DIR)" "$(CACHE_DIR)/aetherd"
	$(NIM) c -d:release --warnings:on --path:aether --nimcache:"$(CACHE_DIR)/aetherd" --out:"$@" aether/aetherd.nim

# Installation is deliberately documented separately; there is no install target.
