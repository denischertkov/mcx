# mcx

Midnight Commander-like dual-panel file manager for **CP/M 2.2** on **Z80**
(Grant Searle SBC–compatible machines), assembled with **sjasmplus**.

Target console: **VT100/ANSI**, 80×24 (Linux serial terminal).

## Requirements

- [sjasmplus](https://github.com/z00m128/sjasmplus) on the build host
- Way to copy `.COM` files onto the CP/M machine

```bash
# example: build sjasmplus from the official source release, then:
export PATH="$HOME/.local/bin:$PATH"
```

## Build

```bash
make            # → build/KEYPROBE.COM
make clean
```

## Iteration 1 — KEYPROBE

`KEYPROBE.COM` dumps the raw byte sequence for each keypress (hex).

```text
A> KEYPROBE
KEY: 1B 5B 41          ← Up arrow (ESC [ A)
```

Calibrated sequences and drive-select fallback: [docs/keys.md](docs/keys.md).

**Note:** Alt-F1/Alt-F2 are captured by the Linux host and never reach CP/M.
MCX will use **Ctrl-L** / **Ctrl-R** (then a drive letter) instead.

## Layout (growing)

```text
src/include/   CP/M constants
src/bdos/      BDOS wrappers
src/term/      VT100/ANSI helpers
tools/         KEYPROBE and other host-side helpers
docs/          keymap notes from hardware
build/         generated .COM (gitignored)
```

## Status

- **Done:** scaffold, BDOS/ANSI, KEYPROBE (fix: preserve A across BDOS print)
- **Next:** dual-panel shell + directory listing using [docs/keys.md](docs/keys.md)
