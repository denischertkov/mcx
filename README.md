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

`KEYPROBE.COM` dumps the raw byte sequence for each keypress (hex). Use it on
the real machine to calibrate MCX keymaps (arrows, F-keys, Alt-F1/F2).

On CP/M:

```text
A> KEYPROBE
MCX KEYPROBE - press keys; Ctrl-C to quit
...
KEY: 1B 5B 41          ← example: Up arrow (ESC [ A)
```

Please capture lines for at least:

| Key        | Purpose              |
|------------|----------------------|
| ↑ ↓ ← →    | panel navigation     |
| F1…F10     | commands             |
| Alt-F1     | left panel drive     |
| Alt-F2     | right panel drive    |
| Tab        | switch panel         |
| Enter      | run / confirm        |
| BS / Del   | editing              |
| Ctrl-C     | should exit KEYPROBE |

Paste the hex dump into the PR or a follow-up comment.

## Layout (growing)

```text
src/include/   CP/M constants
src/bdos/      BDOS wrappers
src/term/      VT100/ANSI helpers
tools/         KEYPROBE and other host-side helpers
build/         generated .COM (gitignored)
```

## Status

- **Done:** scaffold, BDOS/ANSI modules, KEYPROBE
- **Next:** dual-panel shell + directory listing (after keymap calibration)
