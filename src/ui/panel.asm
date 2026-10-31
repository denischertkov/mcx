;==============================================================================
; ui/panel.asm — draw one file panel and manage cursor/scroll
;
; Public entry points:
;   panel_draw        IX → panel, C = left col (1-based), A≠0 if active
;   panel_draw_header IX, C=col, A≠0 active — row 1 only
;   panel_draw_index  IX, C=col, HL=file index, A≠0 highlight — one list row
;   panel_cursor_up   IX → panel
;   panel_cursor_down IX → panel
;   panel_fmt_name    HL → 11-char FCB name, DE → dest buffer (13 bytes max)
;==============================================================================

        INCLUDE "include/cpm.inc"
        INCLUDE "include/mcx.inc"

;------------------------------------------------------------------------------
; panel_draw — IX=panel, C=start column (1 or 41), A=0 inactive / ≠0 active
;------------------------------------------------------------------------------
panel_draw:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      (pd_active),A
        LD      A,C
        LD      (pd_col),A

        ; header row 1: " A: " or reverse if active
        LD      B,1
        LD      A,(pd_col)
        LD      C,A
        CALL    term_cup

        LD      A,(pd_active)
        OR      A
        CALL    NZ,term_rev_on

        LD      A,' '
        CALL    bdos_conout
        LD      A,(IX+P_DRIVE)
        ADD     A,'A'
        CALL    bdos_conout
        LD      A,':'
        CALL    bdos_conout
        LD      A,' '
        CALL    bdos_conout

        LD      A,(pd_active)
        OR      A
        CALL    NZ,term_rev_off

        ; list rows 2 .. 2+PANEL_ROWS-1
        LD      L,(IX+P_SCROLL)
        LD      H,(IX+P_SCROLL+1)
        LD      (pd_idx),HL
        LD      B,PANEL_ROWS
        LD      A,2
        LD      (pd_row),A

.pd_row_loop:
        PUSH    BC
        ; cursor position
        LD      A,(pd_row)
        LD      B,A
        LD      A,(pd_col)
        LD      C,A
        CALL    term_cup

        ; clear panel width with spaces first
        LD      B,PANEL_WIDTH
.pd_clr:
        LD      A,' '
        CALL    bdos_conout
        DJNZ    .pd_clr

        ; re-cup
        LD      A,(pd_row)
        LD      B,A
        LD      A,(pd_col)
        LD      C,A
        CALL    term_cup

        ; if idx >= count → empty row
        LD      HL,(pd_idx)
        LD      E,(IX+P_COUNT)
        LD      D,(IX+P_COUNT+1)
        OR      A
        SBC     HL,DE
        JR      NC,.pd_next_row

        ; highlight if idx == cursor and active
        LD      HL,(pd_idx)
        LD      E,(IX+P_CURSOR)
        LD      D,(IX+P_CURSOR+1)
        OR      A
        SBC     HL,DE
        JR      NZ,.pd_no_hi
        LD      A,(pd_active)
        OR      A
        JR      Z,.pd_no_hi
        CALL    term_rev_on
        LD      A,1
        LD      (pd_hi),A
        JR      .pd_name
.pd_no_hi:
        XOR     A
        LD      (pd_hi),A

.pd_name:
        CALL    panel_name_at_idx       ; HL → name for pd_idx
        LD      DE,pd_nbuf
        CALL    panel_fmt_name
        LD      HL,pd_nbuf
        CALL    term_puts

        LD      A,(pd_hi)
        OR      A
        CALL    NZ,term_rev_off

.pd_next_row:
        LD      HL,(pd_idx)
        INC     HL
        LD      (pd_idx),HL
        LD      A,(pd_row)
        INC     A
        LD      (pd_row),A
        POP     BC
        DJNZ    .pd_row_loop

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; panel_name_at_idx — IX=panel, (pd_idx)=index → HL → 11-char name
;------------------------------------------------------------------------------
panel_name_at_idx:
        LD      HL,(pd_idx)
        ; *12
        ADD     HL,HL
        ADD     HL,HL
        LD      E,L
        LD      D,H
        ADD     HL,HL
        ADD     HL,DE
        PUSH    IX
        POP     DE
        ADD     HL,DE
        LD      DE,P_NAMES
        ADD     HL,DE
        RET

;------------------------------------------------------------------------------
; panel_fmt_name — HL → 11 raw FCB name, DE → dest "NAME.EXT",0
;------------------------------------------------------------------------------
panel_fmt_name:
        PUSH    BC
        PUSH    HL
        ; copy name chars until space or 8
        LD      B,8
.fn_n:
        LD      A,(HL)
        CP      ' '
        JR      Z,.fn_n_pad
        LD      (DE),A
        INC     DE
        INC     HL
        DJNZ    .fn_n
        JR      .fn_type
.fn_n_pad:
        ; skip rest of name field
        LD      A,B
.fn_ns:
        OR      A
        JR      Z,.fn_type
        INC     HL
        DEC     A
        JR      .fn_ns
.fn_type:
        ; HL at type; if all spaces → no dot
        PUSH    HL
        LD      A,(HL)
        CP      ' '
        JR      NZ,.fn_dot
        INC     HL
        LD      A,(HL)
        CP      ' '
        JR      NZ,.fn_dot
        INC     HL
        LD      A,(HL)
        CP      ' '
        POP     HL
        JR      Z,.fn_done
        PUSH    HL
.fn_dot:
        POP     HL
        LD      A,'.'
        LD      (DE),A
        INC     DE
        LD      B,3
.fn_t:
        LD      A,(HL)
        CP      ' '
        JR      Z,.fn_done
        LD      (DE),A
        INC     DE
        INC     HL
        DJNZ    .fn_t
.fn_done:
        XOR     A
        LD      (DE),A
        POP     HL
        POP     BC
        RET

;------------------------------------------------------------------------------
; panel_draw_header — IX=panel, C=col, A≠0 if active
;------------------------------------------------------------------------------
panel_draw_header:
        PUSH    AF
        PUSH    BC
        LD      (pd_active),A
        LD      A,C
        LD      (pd_col),A
        LD      B,1
        CALL    term_cup
        LD      A,(pd_active)
        OR      A
        CALL    NZ,term_rev_on
        LD      A,' '
        CALL    bdos_conout
        LD      A,(IX+P_DRIVE)
        ADD     A,'A'
        CALL    bdos_conout
        LD      A,':'
        CALL    bdos_conout
        LD      A,' '
        CALL    bdos_conout
        LD      A,(pd_active)
        OR      A
        CALL    NZ,term_rev_off
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; panel_draw_index — IX=panel, C=col, HL=index, A≠0 highlight
; Draws the screen row for that index if it is inside the scroll window.
;------------------------------------------------------------------------------
panel_draw_index:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      (pd_hi),A
        LD      A,C
        LD      (pd_col),A
        LD      (pd_idx),HL

        ; row = 2 + (index - scroll); skip if out of window
        LD      E,(IX+P_SCROLL)
        LD      D,(IX+P_SCROLL+1)
        OR      A
        SBC     HL,DE
        JR      C,.pdi_done              ; above window
        LD      A,L
        CP      PANEL_ROWS
        JR      NC,.pdi_done             ; below window
        ADD     A,2
        LD      (pd_row),A

        LD      B,A
        LD      A,(pd_col)
        LD      C,A
        CALL    term_cup

        LD      B,PANEL_WIDTH
.pdi_clr:
        LD      A,' '
        CALL    bdos_conout
        DJNZ    .pdi_clr

        LD      A,(pd_row)
        LD      B,A
        LD      A,(pd_col)
        LD      C,A
        CALL    term_cup

        ; beyond count?
        LD      HL,(pd_idx)
        LD      E,(IX+P_COUNT)
        LD      D,(IX+P_COUNT+1)
        OR      A
        SBC     HL,DE
        JR      NC,.pdi_done

        LD      A,(pd_hi)
        OR      A
        CALL    NZ,term_rev_on

        CALL    panel_name_at_idx
        LD      DE,pd_nbuf
        CALL    panel_fmt_name
        LD      HL,pd_nbuf
        CALL    term_puts

        LD      A,(pd_hi)
        OR      A
        CALL    NZ,term_rev_off

.pdi_done:
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; panel_cursor_up / panel_cursor_down — adjust cursor and scroll window
;------------------------------------------------------------------------------
panel_cursor_up:
        LD      L,(IX+P_CURSOR)
        LD      H,(IX+P_CURSOR+1)
        LD      A,H
        OR      L
        RET     Z
        DEC     HL
        LD      (IX+P_CURSOR),L
        LD      (IX+P_CURSOR+1),H
        ; if cursor < scroll → scroll = cursor
        LD      E,(IX+P_SCROLL)
        LD      D,(IX+P_SCROLL+1)
        OR      A
        SBC     HL,DE
        RET     NC
        LD      L,(IX+P_CURSOR)
        LD      H,(IX+P_CURSOR+1)
        LD      (IX+P_SCROLL),L
        LD      (IX+P_SCROLL+1),H
        RET

panel_cursor_down:
        LD      L,(IX+P_CURSOR)
        LD      H,(IX+P_CURSOR+1)
        INC     HL
        LD      E,(IX+P_COUNT)
        LD      D,(IX+P_COUNT+1)
        LD      A,D
        OR      E
        RET     Z
        ; if cursor+1 >= count → stop
        PUSH    HL
        OR      A
        SBC     HL,DE
        POP     HL
        RET     NC
        LD      (IX+P_CURSOR),L
        LD      (IX+P_CURSOR+1),H
        ; if cursor >= scroll+PANEL_ROWS → scroll++
        LD      E,(IX+P_SCROLL)
        LD      D,(IX+P_SCROLL+1)
        PUSH    HL
        LD      HL,PANEL_ROWS
        ADD     HL,DE
        EX      DE,HL
        POP     HL
        OR      A
        SBC     HL,DE
        RET     C
        LD      L,(IX+P_SCROLL)
        LD      H,(IX+P_SCROLL+1)
        INC     HL
        LD      (IX+P_SCROLL),L
        LD      (IX+P_SCROLL+1),H
        RET

; locals
pd_active:      DB      0
pd_col:         DB      0
pd_row:         DB      0
pd_hi:          DB      0
pd_idx:         DW      0
pd_nbuf:        DS      14
