# MCX key sequences (Grant Searle SBC + Linux VT100/ANSI)

Calibrated with fixed KEYPROBE on real hardware (2026-10-31).

## Confirmed dump

| Key | Bytes (hex) | Notes |
|-----|-------------|--------|
| Left | `1B 5B 44` | CSI `D`; first press after idle sometimes `1B 44` (VT52-style) |
| Up | `1B 5B 41` | CSI `A` |
| Right | `1B 5B 43` | CSI `C` |
| Down | `1B 5B 42` | CSI `B` |
| F1 | `1B 4F 50` | SS3 `P` |
| F2 | `1B 4F 51` | SS3 `Q` |
| F3 | `1B 4F 52` | SS3 `R` |
| F4 | `1B 4F 53` | SS3 `S` |
| F5 | `1B 5B 31 36 7E` | CSI `16~` on this minicom; `15~` also accepted |
| F6 | `1B 5B 31 37 7E` | CSI `17~` |
| F7 | `1B 5B 31 38 7E` | CSI `18~` |
| F8 | `1B 5B 31 39 7E` | CSI `19~` |
| F9 | `1B 5B 32 30 7E` | CSI `20~` (xterm). Not F10 |
| F10 | `1B 5B 32 31 7E` | CSI `21~` |
| Esc | `1B`, or `1B` plus a non-CSI byte, or `1B 5B 32 37 7E` | bare Esc, Esc+junk, CSI `27~` |
| Tab | `09` | |
| Enter | `0D` | |
| BS | `08` | |
| Del | `1B 5B 33 7E` | CSI `3~` |
| PgUp | `1B 5B 35 7E` | CSI `5~` |
| PgDn | `1B 5B 36 7E` | CSI `6~` |
| Home | `1B 5B 48` or `1B 4F 48` | CSI `H` / SS3 `H`; also `1~` and `7~` |
| End | `1B 5B 46` or `1B 4F 46` | CSI `F` / SS3 `F`; also `4~` and `8~` |
| Ctrl-L | `0C` | left panel drive select |
| Ctrl-R | `12` | right panel drive select |
| Ctrl-C | `03` | |

## Drive select

Alt-F1/Alt-F2 never reach the serial session (Linux host grabs them).

MCX uses **Ctrl-L** / **Ctrl-R** to open a drive picker (available drives via
BIOS SELDSK, arrows/Enter or letter, Esc cancels).

## Parser notes

- Accept VT52 arrow forms `ESC A/B/C/D` as well as CSI `ESC [ A/B/C/D` (covers the rare `1B 44` left).
- After seeing `ESC`, the input reader uses a longer poll budget so `[` is not dropped.
