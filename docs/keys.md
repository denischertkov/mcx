# MCX key sequences (Grant Searle SBC + Linux VT100/ANSI)

Calibrated from KEYPROBE on real hardware (2026-10-31).

## Bug note (fixed)

Early KEYPROBE printed `00` as the first byte of every line because
`bdos_print` clobbered `A` before the hex dump. Trailing ESC bytes inside
a drained burst were correct (`1B`). Rebuild KEYPROBE after the fix and
re-check Tab / Enter / BS (expected `09` / `0D` / `08`).

## Decoded map

| Key | Bytes (hex) | VT100 meaning |
|-----|-------------|----------------|
| Left | `1B 5B 44` | CSI `D` |
| Up | `1B 5B 41` | CSI `A` |
| Right | `1B 5B 43` | CSI `C` |
| Down | `1B 5B 42` | CSI `B` |
| F1 | `1B 4F 50` | SS3 `P` |
| F2 | `1B 4F 51` | SS3 `Q` |
| F3 | `1B 4F 52` | SS3 `R` |
| F4 | `1B 4F 53` | SS3 `S` |
| F5 | `1B 5B 31 35 7E` | CSI `15~` |
| F6 | `1B 5B 31 36 7E` | CSI `16~` |
| F7 | `1B 5B 31 37 7E` | CSI `17~` |
| F8 | `1B 5B 31 38 7E` | CSI `18~` |
| F9 | `1B 5B 31 39 7E` | CSI `19~` |
| F10 | `1B 5B 32 31 7E` | CSI `21~` |
| Del | `1B 5B 33 7E` | CSI `3~` |
| Tab | `09` (confirm after KEYPROBE fix) | HT |
| Enter | `0D` (confirm after KEYPROBE fix) | CR |
| BS | `08` (confirm after KEYPROBE fix) | BS |

## Alt-F1 / Alt-F2

Not available: the Linux host captures these combos before they reach the
serial session.

**MCX fallback (iteration 2+):**

| Action | Key |
|--------|-----|
| Change left panel drive | `Ctrl-L` then drive letter |
| Change right panel drive | `Ctrl-R` then drive letter |

`Ctrl-L` / `Ctrl-R` should be verified with the fixed KEYPROBE (`0C` / `12`).
