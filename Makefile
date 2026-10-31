# MCX — Midnight Commander-like shell for CP/M 2.2 (Z80)
# Assembler: sjasmplus (https://github.com/z00m128/sjasmplus)

SJASMPLUS ?= $(shell command -v sjasmplus 2>/dev/null || echo $(HOME)/.local/bin/sjasmplus)
SJFLAGS   := --nologo -I src

.PHONY: all clean keyprobe mcx attrtest

all: keyprobe mcx attrtest

keyprobe: build/KEYPROBE.COM
mcx: build/MCX.COM
attrtest: build/ATTRTEST.COM

build/KEYPROBE.COM: tools/keyprobe.asm src/include/cpm.inc src/bdos/bdos.asm src/term/ansi.asm
	mkdir -p build
	$(SJASMPLUS) $(SJFLAGS) tools/keyprobe.asm

build/ATTRTEST.COM: tools/attrtest.asm src/include/cpm.inc src/bdos/bdos.asm
	mkdir -p build
	$(SJASMPLUS) $(SJFLAGS) tools/attrtest.asm

MCX_SRC := src/mcx.asm \
	src/include/cpm.inc src/include/keys.inc src/include/mcx.inc \
	src/bdos/bdos.asm src/term/ansi.asm \
	src/keys/input.asm src/keys/keymap.asm \
	src/fs/dir.asm \
	src/ui/panel.asm src/ui/status.asm src/ui/screen.asm src/ui/drive.asm \
	src/help/help.asm

build/MCX.COM: $(MCX_SRC)
	mkdir -p build
	$(SJASMPLUS) $(SJFLAGS) src/mcx.asm

clean:
	rm -rf build
