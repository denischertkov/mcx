# MCX — Midnight Commander-like shell for CP/M 2.2 (Z80)
# Assembler: sjasmplus (https://github.com/z00m128/sjasmplus)

SJASMPLUS ?= $(shell command -v sjasmplus 2>/dev/null || echo $(HOME)/.local/bin/sjasmplus)
SJFLAGS   := --nologo -I src

.PHONY: all clean keyprobe

all: keyprobe

keyprobe: build/KEYPROBE.COM

build/KEYPROBE.COM: tools/keyprobe.asm src/include/cpm.inc src/bdos/bdos.asm src/term/ansi.asm
	mkdir -p build
	$(SJASMPLUS) $(SJFLAGS) tools/keyprobe.asm

clean:
	rm -rf build
