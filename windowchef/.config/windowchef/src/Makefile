include config.mk

NAME_DEFINES = -D__NAME__=\"$(__NAME__)\"                 \
			   -D__NAME_CLIENT__=\"$(__NAME_CLIENT__)\"   \
			   -D__THIS_VERSION__=\"$(__THIS_VERSION__)\" \
			   -D__CONFIG_NAME__=\"$(__CONFIG_NAME__)\"   \

SRC = helpers.c wm.c client.c
OBJ = $(SRC:.c=.o)
BIN = $(__NAME__) $(__NAME_CLIENT__)
CFLAGS += $(NAME_DEFINES)

all: $(BIN)

debug: CFLAGS += -O0 -g -DD
debug: $(__NAME__) $(__NAME_CLIENT__)

$(__NAME__): wm.o helpers.o
	@echo $@
	@$(CC) -o $@ $^ $(LDFLAGS)

$(__NAME_CLIENT__): client.o
	@echo $@
	@$(CC) -o $@ $^ $(LDFLAGS)

%.o: %.c
	@echo $@
	@$(CC) -o $@ -c $(CFLAGS) $<

$(OBJ): common.h helpers.h ipc.h types.h config.h

install: all
	mkdir -p "$(DESTDIR)$(PREFIX)/bin"
	install $(__NAME__) "$(DESTDIR)$(PREFIX)/bin/$(__NAME__)"
	install $(__NAME_CLIENT__) "$(DESTDIR)$(PREFIX)/bin/$(__NAME_CLIENT__)"
	mkdir -p "$(DESTDIR)$(DOCPREFIX)/$(__NAME__)/"
	cp -fR contrib "$(DESTDIR)$(DOCPREFIX)/$(__NAME__)/"
	cp -fR examples "$(DESTDIR)$(DOCPREFIX)/$(__NAME__)/"
	cp -f README.md LICENSE "$(DESTDIR)$(DOCPREFIX)/$(__NAME__)/"
	cd ./man; $(MAKE) install
	install -D windowchef.desktop "$(DESTDIR)$(XSESSIONS)/"windowchef.desktop

uninstall:
	rm -f "$(DESTDIR)$(PREFIX)/bin/$(__NAME__)"
	rm -f "$(DESTDIR)$(PREFIX)/bin/$(__NAME_CLIENT__)"
	rm -rf "$(DESTDIR)$(DOCPREFIX)/$(__NAME__)"
	rm -rf "$(DESTDIR)$(XSESSIONS)/windowchef.desktop"
	cd ./man; $(MAKE) uninstall

clean:
	rm -f $(OBJ) $(BIN)
