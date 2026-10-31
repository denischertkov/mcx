# MCX Program Structure

## Overview

MCX is a Z80 assembly file manager for CP/M 2.2. The program targets an 80x24
VT100/ANSI-compatible console. It is assembled as one `.COM` program by
sjasmplus: `src/mcx.asm` is the root source and includes the other MCX modules
into the same address space. The modules are source-level boundaries, not
separately linked binaries.

The main runtime path is:

1. Initialize the stack and set both panels to the current CP/M drive.
2. Parse the command tail for initial panel drives and color options.
3. Load each panel's directory and draw the screen.
4. Read logical key events and dispatch navigation, drive selection, file
   operations, help, or quit.
5. Redraw only the affected screen regions when possible; operations that
   change directory contents request a full redraw.

The central loop and the initial setup live in [`../src/mcx.asm`](../src/mcx.asm).

## Source Map

| Path | Responsibility |
|------|----------------|
| `src/mcx.asm` | Program entry, command-tail parsing, active-panel selection, main input loop, and dispatch to features. |
| `src/bdos/bdos.asm` | Thin wrappers for CP/M BDOS calls, including console I/O, drive selection, DMA setup, file search, and return to the CCP. |
| `src/term/ansi.asm` | ANSI cursor positioning, screen clearing, color selection, and reverse-video helpers. |
| `src/keys/input.asm` | Reads raw console input through BDOS and recognizes escape-sequence prefixes. |
| `src/keys/keymap.asm` | Maps VT100/VT52 byte sequences to logical key codes. |
| `src/fs/dir.asm` | Selects a panel's drive and loads directory entries using CP/M search calls. It strips attribute bits and avoids duplicate names from multi-extent files. |
| `src/fs/file.asm` | Shared file-selection and FCB helpers, plus copy, rename, and delete operations. |
| `src/fs/view.asm` | Reads a selected file into available TPA memory and renders it as text. It also provides buffer and rendering helpers used by the editor. |
| `src/fs/edit.asm` | Text editing, cursor movement, insertion/deletion, and saving the selected file. It uses the viewer's text buffer. |
| `src/ui/panel.asm` | Draws a panel and its entries; maintains the panel cursor and scroll position; formats CP/M filenames. |
| `src/ui/screen.asm` | Draws the frame and both panels, and performs targeted updates for navigation or panel switching. |
| `src/ui/status.asm` | Status and function-key rows, drive prompts, and 8.3 filename input. |
| `src/ui/drive.asm` | Drive picker. Probes available drives through the BIOS and falls back to the BDOS login vector. |
| `src/help/help.asm` | F1 help text and its wait-for-key overlay. |
| `src/include/cpm.inc` | CP/M entry points, BDOS function numbers, FCB offsets, and control characters. |
| `src/include/keys.inc` | Logical key-code constants shared by the input parser and feature handlers. |
| `src/include/mcx.inc` | Screen dimensions, panel geometry, panel limits, and panel-structure offsets. |
| `tools/keyprobe.asm` | Builds `KEYPROBE.COM`, which prints raw key bytes for keyboard calibration. |
| `tools/attrtest.asm` | Builds `ATTRTEST.COM`, which tests terminal reverse-video behavior. |
| `docs/keys.md` | Measured terminal key sequences and parser notes. |

## Main Components

### Input and dispatch

`keys_get` in `src/keys/input.asm` converts raw console bytes into the logical
codes declared in `src/include/keys.inc`. Printable and control characters are
returned as ASCII; special keys use codes above `7Fh`. The keymap handles ANSI
CSI/SS3 sequences as well as supported VT52 forms. The main loop in
`src/mcx.asm` owns the application-level dispatch and calls feature entry
points.

### Panels and shared state

The left and right panel states are stored in `panel_left` and `panel_right`
in `src/mcx.asm`. Each panel has a drive number, entry count, cursor index,
scroll offset, and a fixed-capacity name list. Layout constants and structure
offsets are defined in `src/include/mcx.inc`; each filename is held in
CP/M-style 11-byte 8.3 form. `active_panel` determines which panel receives
navigation and file-operation commands.

Directory loading is separate from presentation: `dir_load` fills a panel's
name list, while `panel_draw` and `screen_draw_all` render that state. This
keeps directory operations independent from cursor painting and screen framing.

### CP/M and terminal boundaries

BDOS access is centralized in `src/bdos/bdos.asm`, with shared operating-system
constants in `src/include/cpm.inc`. Directory and file operations use CP/M
FCBs and BDOS calls; directory enumeration also uses the BDOS DMA buffer.
The drive picker and directory loading use BIOS drive-selection facilities
where needed. Console presentation goes through BDOS output and the ANSI
helpers in `src/term/ansi.asm`.

### File features

F3 opens the selected file and reads it into the available TPA buffer, stopping
at CP/M's `Ctrl-Z` text-file marker. It shows up to 22 lines at a time; tabs
expand to tab stops and other non-printable bytes are shown as periods. If the
file exceeds available memory, the viewer marks the display as truncated.
Up/Down scroll one line; PgUp/PgDn and Space move by a page. Esc, Ctrl-C, or
F10 returns to the panels.

F4 uses the same buffer, but refuses to open a file that was truncated. The
editor supports arrow-key movement, PgUp/PgDn, printable-character insertion,
Backspace, Delete, and Enter for a CR/LF line break. A modified marker appears
while there are unsaved changes. F2 saves and stays in the editor; Esc or F10
exits immediately if unchanged, otherwise it asks whether to save. Answer
`Y` or Enter to save and exit, or `N` to discard the changes.

Saving writes the edited contents to `MCXEDTMP.$$$` before replacing the
original file. If the replacement rename fails, the temporary file is kept
and reported as `MCXEDTMP.$$$` rather than silently discarding the saved text.

F5 copies the selected file under its existing name to the drive shown in the
other panel. Copying to the same drive is refused. If the destination already
contains that filename, `Y` or Enter confirms overwrite; any other key cancels
the operation. On success, the destination panel's directory is reloaded.

F6 renames the selected file on the active panel's drive. The new name must
follow CP/M's 8.3 format and contain letters and digits, with at most one dot;
input is converted to uppercase. An unchanged name or a name already present
on that drive is rejected. Esc or Ctrl-C cancels name entry. On success, the
active panel's directory is reloaded.

F8 deletes after confirmation. Enter-to-run is not implemented in the current
main loop.

### Screen updates

`src/ui/screen.asm` coordinates the full-screen layout. It delegates panel
content to `src/ui/panel.asm` and the lower rows to `src/ui/status.asm`.
Navigation usually repaints only the old and new cursor rows; when scrolling,
the active panel is redrawn. Feature screens such as help, view, and edit take
over the console and return to a full panel redraw.

## Build and Outputs

The Makefile builds all programs with sjasmplus:

- `make` builds `MCX.COM`, `KEYPROBE.COM`, and `ATTRTEST.COM` under `build/`.
- `make mcx` builds only the file manager.
- `make keyprobe` and `make attrtest` build the corresponding diagnostic tools.
- `make clean` removes the generated `build/` directory.

`build/MCX.COM` is assembled from `src/mcx.asm`; the Makefile lists its included
source files as dependencies so changes to a module trigger a rebuild. The
other two `.COM` programs are assembled from their matching sources under
`tools/` and use the shared BDOS support where required.
