;==============================================================================
; term/ansi.asm — minimal VT100/ANSI terminal helpers for 80x24 consoles
;
; Public entry points:
;   term_cls      clear screen + home cursor (blue if color_on)
;   term_reset    default colors, clear — used on quit
;   term_home     cursor to (1,1)
;   term_cup      B=row (1..24), C=col (1..80) — CUP
;   term_rev_on   reverse video on (SGR 7)
;   term_rev_off  reverse off; in color mode keeps blue/white (SGR 27)
;   term_puts     HL → zero-terminated string via console
;
; color_on = 1 (default): bold white on blue, ESC[0;1;37;44m before CLS.
; color_on = 0 (/b): previous black-and-white behaviour.
; Reverse-off must not be ESC[0m while color is on — that wipes the blue.
;
; Depends on: bdos/bdos.asm (bdos_conout, bdos_print)
;==============================================================================

        INCLUDE "include/cpm.inc"

;------------------------------------------------------------------------------
; term_cls — base color (if on), erase display, cursor home.
; Erase uses the current background, so the SGR goes out before ESC[2J.
;------------------------------------------------------------------------------
term_cls:
        PUSH    DE
        LD      A,(color_on)
        OR      A
        JR      Z,.tc_clr
        LD      DE,ansi_blue
        CALL    bdos_print
.tc_clr:
        LD      DE,ansi_cls
        CALL    bdos_print
        POP     DE
        RET

;------------------------------------------------------------------------------
; term_reset — ESC[0m and clear, so the CP/M prompt is not left on blue
;------------------------------------------------------------------------------
term_reset:
        PUSH    DE
        LD      DE,ansi_rev_off
        CALL    bdos_print
        LD      DE,ansi_cls
        CALL    bdos_print
        POP     DE
        RET

;------------------------------------------------------------------------------
; term_home — cursor to row 1, column 1
;------------------------------------------------------------------------------
term_home:
        PUSH    DE
        LD      DE,ansi_home
        CALL    bdos_print
        POP     DE
        RET

;------------------------------------------------------------------------------
; term_cup — set cursor position; B = row (1-based), C = col (1-based)
; Emits ESC [ row ; col H with decimal ASCII.
;------------------------------------------------------------------------------
term_cup:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      A,ESC
        CALL    bdos_conout
        LD      A,'['
        CALL    bdos_conout
        LD      A,B                      ; row
        CALL    term_put_dec
        LD      A,';'
        CALL    bdos_conout
        LD      A,C                      ; col
        CALL    term_put_dec
        LD      A,'H'
        CALL    bdos_conout
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; term_rev_on / term_rev_off — SGR reverse / reset
;------------------------------------------------------------------------------
term_rev_on:
        PUSH    DE
        LD      DE,ansi_rev_on
        CALL    bdos_print
        POP     DE
        RET

term_rev_off:
        PUSH    DE
        LD      A,(color_on)
        OR      A
        LD      DE,ansi_rev_off
        JR      Z,.tro
        LD      DE,ansi_rev_keep
.tro:
        CALL    bdos_print
        POP     DE
        RET

;------------------------------------------------------------------------------
; term_puts — print zero-terminated string at HL
;------------------------------------------------------------------------------
term_puts:
        PUSH    AF
        PUSH    HL
.puts_loop:
        LD      A,(HL)
        OR      A
        JR      Z,.puts_done
        CALL    bdos_conout
        INC     HL
        JR      .puts_loop
.puts_done:
        POP     HL
        POP     AF
        RET

;------------------------------------------------------------------------------
; term_put_dec — print A (0..99) as 1–2 decimal digits (no leading zero if <10
; for single digit CUP is fine either way; we always print at least one digit)
;------------------------------------------------------------------------------
term_put_dec:
        PUSH    AF
        PUSH    BC
        LD      B,0                      ; tens
.td_div:
        CP      10
        JR      C,.td_ones
        SUB     10
        INC     B
        JR      .td_div
.td_ones:
        LD      C,A                      ; ones
        LD      A,B
        OR      A
        JR      Z,.td_skip_tens
        ADD     A,'0'
        CALL    bdos_conout
.td_skip_tens:
        LD      A,C
        ADD     A,'0'
        CALL    bdos_conout
        POP     BC
        POP     AF
        RET

; --- ANSI string constants ($-terminated for BDOS func 9) --------------------
ansi_cls:       DB      ESC,"[2J",ESC,"[H$"
ansi_home:      DB      ESC,"[H$"
ansi_rev_on:    DB      ESC,"[7m$"
ansi_rev_off:   DB      ESC,"[0m$"
ansi_rev_keep:  DB      ESC,"[27m$"
ansi_blue:      DB      ESC,"[0;1;37;44m$"

; 1 = blue background / white text (default and /c). 0 = /b.
color_on:       DB      1
