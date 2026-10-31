;==============================================================================
; ui/panel.asm — dual-panel drawing and cursor movement
;
; Cursor = reverse-video bar (ESC[7m ... ESC[0m), full panel width.
; Drive menu must never use SGR reverse (see ui/drive.asm).
;==============================================================================

        INCLUDE "include/cpm.inc"
        INCLUDE "include/mcx.inc"

;------------------------------------------------------------------------------
; panel_draw — IX=panel, C=col, A≠0 active
;------------------------------------------------------------------------------
panel_draw:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      (pd_active),A
        LD      A,C
        LD      (pd_col),A
        LD      A,(pd_active)
        CALL    panel_draw_header

        LD      L,(IX+P_SCROLL)
        LD      H,(IX+P_SCROLL+1)
        LD      (pd_idx),HL
        LD      B,PANEL_ROWS
        LD      A,2
        LD      (pd_row),A

.pd_row_loop:
        PUSH    BC
        LD      A,(pd_row)
        LD      B,A
        LD      A,(pd_col)
        LD      C,A
        CALL    term_cup

        XOR     A
        LD      (pd_hi),A
        LD      HL,(pd_idx)
        LD      E,(IX+P_COUNT)
        LD      D,(IX+P_COUNT+1)
        OR      A
        SBC     HL,DE
        JR      NC,.pd_blank

        LD      HL,(pd_idx)
        LD      E,(IX+P_CURSOR)
        LD      D,(IX+P_CURSOR+1)
        OR      A
        SBC     HL,DE
        JR      NZ,.pd_name
        LD      A,(pd_active)
        OR      A
        JR      Z,.pd_name
        LD      A,1
        LD      (pd_hi),A

.pd_name:
        CALL    panel_name_at_idx
        LD      DE,pd_nbuf
        CALL    panel_fmt_name
        LD      HL,pd_nbuf
        LD      A,(pd_hi)
        CALL    panel_put_line
        JR      .pd_next_row

.pd_blank:
        LD      HL,pd_empty
        XOR     A
        CALL    panel_put_line

.pd_next_row:
        LD      HL,(pd_idx)
        INC     HL
        LD      (pd_idx),HL
        LD      A,(pd_row)
        INC     A
        LD      (pd_row),A
        POP     BC
        DJNZ    .pd_row_loop

        CALL    term_rev_off
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; panel_put_line — HL→name, A≠0 reverse bar; always ends with SGR0
;------------------------------------------------------------------------------
panel_put_line:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      (pd_hi),A               ; keep flag out of AF across calls
        CALL    term_rev_off
        LD      A,(pd_hi)
        OR      A
        CALL    NZ,term_rev_on
        LD      B,PANEL_WIDTH
.ppl_ch:
        LD      A,B
        OR      A
        JR      Z,.ppl_done
        LD      A,(HL)
        OR      A
        JR      Z,.ppl_pad
        CALL    bdos_conout
        INC     HL
        DEC     B
        JR      .ppl_ch
.ppl_pad:
        LD      A,B
        OR      A
        JR      Z,.ppl_done
.ppl_sp:
        LD      A,' '
        CALL    bdos_conout
        DJNZ    .ppl_sp
.ppl_done:
        CALL    term_rev_off
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
panel_name_at_idx:
        LD      HL,(pd_idx)
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
panel_fmt_name:
        PUSH    BC
        PUSH    HL
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
        LD      A,B
.fn_ns:
        OR      A
        JR      Z,.fn_type
        INC     HL
        DEC     A
        JR      .fn_ns
.fn_type:
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
; panel_draw_header — active header in reverse
;------------------------------------------------------------------------------
panel_draw_header:
        PUSH    AF
        PUSH    BC
        LD      (pd_active),A
        LD      A,C
        LD      (pd_col),A
        CALL    term_rev_off
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
        LD      B,8
.pdh_pad:
        LD      A,' '
        CALL    bdos_conout
        DJNZ    .pdh_pad
        CALL    term_rev_off
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; panel_draw_index — one row; A≠0 = reverse cursor
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

        LD      E,(IX+P_SCROLL)
        LD      D,(IX+P_SCROLL+1)
        OR      A
        SBC     HL,DE
        JR      C,.pdi_done
        LD      A,L
        CP      PANEL_ROWS
        JR      NC,.pdi_done
        ADD     A,2
        LD      (pd_row),A

        LD      B,A
        LD      A,(pd_col)
        LD      C,A
        CALL    term_cup

        LD      HL,(pd_idx)
        LD      E,(IX+P_COUNT)
        LD      D,(IX+P_COUNT+1)
        OR      A
        SBC     HL,DE
        JR      NC,.pdi_blank

        CALL    panel_name_at_idx
        LD      DE,pd_nbuf
        CALL    panel_fmt_name
        LD      HL,pd_nbuf
        LD      A,(pd_hi)
        CALL    panel_put_line
        JR      .pdi_done

.pdi_blank:
        LD      HL,pd_empty
        XOR     A
        CALL    panel_put_line

.pdi_done:
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

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
        PUSH    HL
        OR      A
        SBC     HL,DE
        POP     HL
        RET     NC
        LD      (IX+P_CURSOR),L
        LD      (IX+P_CURSOR+1),H
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

pd_active:      DB      0
pd_col:         DB      0
pd_row:         DB      0
pd_hi:          DB      0
pd_idx:         DW      0
pd_nbuf:        DS      14
pd_empty:       DB      0
