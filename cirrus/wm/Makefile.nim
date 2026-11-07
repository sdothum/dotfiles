NIM ?= nim
NIM_OUT ?= /tmp/cirrus-nim
NIMCACHE ?= /tmp/cirrus-nimcache
SOURCE := cirrus_nim
NIM_VERSION ?= $(shell git describe 2>/dev/null || cat VERSION)

.PHONY: cirrus-nim

cirrus-nim:
	$(NIM) c --hints:off --warnings:on --path:$(SOURCE) --nimcache:$(NIMCACHE) --out:$(NIM_OUT) -d:LegacyVersion=$(NIM_VERSION) $(SOURCE)/main.nim
