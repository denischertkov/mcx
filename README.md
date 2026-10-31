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
make            # → build/KEYPROBE.COM and build/MCX.COM
make mcx        # file manager only
make keyprobe   # calibration tool only
make clean
```

Copy `MCX.COM` to the CP/M machine and run `MCX` or `MCX B: C:`.

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

- **Done:** scaffold, KEYPROBE, calibrated keymap ([docs/keys.md](docs/keys.md))
- **Done (iter 2):** dual panels, dir listing, Tab/arrows, Ctrl-L/R drives, F1 help, F10 quit
- **Next (iter 3):** F3 view, F4 edit, F5 copy, F6 rename, Enter run
