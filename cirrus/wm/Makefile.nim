NIM ?= nim
NIM_OUT ?= /tmp/cirrus-nim
NIMCACHE ?= /tmp/cirrus-nimcache
SOURCE := cirrus_nim

.PHONY: cirrus-nim

cirrus-nim:
	$(NIM) c --hints:off --warnings:on --path:$(SOURCE) --nimcache:$(NIMCACHE) --out:$(NIM_OUT) $(SOURCE)/main.nim
