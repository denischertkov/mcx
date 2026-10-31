# MCX

MCX is a dual-panel file manager for **CP/M 2.2** on **Z80**, assembled with
**sjasmplus**. It targets an 80×24 VT100/ANSI console, such as a Linux serial
terminal connected to a Grant Searle SBC-compatible machine.

## Build

Install [sjasmplus](https://github.com/z00m128/sjasmplus) on the build host and
make it available on `PATH` (or set `SJASMPLUS` to its executable):

```bash
make           # build MCX.COM, KEYPROBE.COM, and ATTRTEST.COM
make mcx       # build only the file manager
make keyprobe  # build only the keyboard probe
make attrtest  # build only the terminal attribute test
make clean
```

Copy `build/MCX.COM` to the CP/M machine. Start with the current logged-in
drive in both panels, or choose initial panel drives on the command line:

```text
A> MCX
A> MCX B:
A> MCX B: C:
A> MCX /b B: C:
```

The first drive argument selects the left panel, the second the right. Drives
may be specified as `A:` through `P:`. `/c` selects color (the default); `/b`
selects monochrome. Options and drive arguments can be mixed, and the last
color option takes effect.

## Controls

| Key | Action |
|-----|--------|
| Up / Down | Move through the active panel |
| Home / End | Select the first / last entry |
| Tab | Switch active panel |
| Ctrl-L / Ctrl-R | Choose a drive for the left / right panel |
| Enter | Not implemented; displays a status message |
| F1 | Show keyboard help |
| F3 | View the selected file as text |
| F4 | Edit the selected text file |
| F5 | Copy the selected file to the other panel's drive |
| F6 | Rename the selected file in its current drive |
| F8 | Delete the selected file after `Y` confirmation |
| F10 / Ctrl-C | Quit to CP/M |

The drive picker lists drives detected by the BIOS, falling back to the BDOS
login vector when needed. Select with arrows and Enter, type a drive letter
from A to P, or press Esc to cancel. Alt-F1/Alt-F2 are commonly captured by
the Linux host, so Ctrl-L/Ctrl-R are used instead.

### Viewer and editor

The F3 viewer displays text, treating tabs as tab stops and non-printable
bytes as periods. Up/Down scroll one line; PgUp/PgDn or Space scroll a page.
Esc, Ctrl-C, or F10 returns to the panels. The viewer reads into available TPA
memory and indicates when the file is truncated.

The F4 editor supports cursor movement, text insertion, Backspace, Delete,
and page movement. Enter inserts a line break. F2 saves and stays in the
editor; Esc or F10 exits. If there are unsaved changes, confirm with `Y` or
Enter to save, or press `N` to discard. Files too large for the available
editor buffer cannot be edited. The editor writes the edited contents back to
the selected file.

F5 copies using the original filename and refuses to copy to the same drive;
when the destination already exists, confirm overwrite with `Y` or Enter.
F6 accepts an 8.3 filename. F8 only deletes after the `Y` confirmation.

## Keyboard calibration

`KEYPROBE.COM` prints the raw hexadecimal bytes received for each keypress.
Measured sequences and parser notes are in [docs/keys.md](docs/keys.md).

## Source layout

- `src/` — MCX, CP/M/BDOS, keyboard, terminal, file, and UI modules
- `tools/` — KEYPROBE and terminal attribute test programs
- `docs/` — measured keyboard sequences
- `build/` — generated `.COM` files

Denis Chertkov, denis@chertkov.info, 20261031
