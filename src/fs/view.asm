;==============================================================================
; fs/view.asm — F3 text view of the file under the cursor
;
; Reads the file into the free TPA above the stack (stops at Ctrl-Z).
; Space/Down = next page, Up = previous, Esc = back to the panels.
;==============================================================================

        INCLUDE "include/cpm.inc"
        INCLUDE "include/mcx.inc"
        INCLUDE "include/keys.inc"

VIEW_ROWS       EQU     22
VIEW_COLS       EQU     80

;------------------------------------------------------------------------------
; view_show — CY if the screen was not taken (caller shows view_msg only)
;------------------------------------------------------------------------------
view_show:
        XOR     A
        LD      (view_trunc),A
        CALL    file_take_current
        JP      C,.vs_nofile
        CALL    view_load
        JP      C,.vs_fail

        LD      HL,0
        LD      (view_pos),HL
.vs_page:
        CALL    term_rev_off
        CALL    term_cls
        LD      A,1
        LD      (view_draw),A
        CALL    view_walk
        CALL    view_footer
        CALL    keys_get
        CP      KEY_ESC
        RET     Z
        CP      KEY_CTRL_C
        RET     Z
        CP      KEY_F10
        RET     Z
        CP      KEY_UP
        JR      Z,.vs_up
        CP      KEY_DOWN
        JR      Z,.vs_dn
        CP      ' '
        JR      Z,.vs_dn
        CP      KEY_ENTER
        JR      Z,.vs_dn
        JR      .vs_page

.vs_dn:
        LD      A,(view_eof)
        OR      A
        JR      NZ,.vs_page
        LD      HL,(view_next)
        LD      DE,(view_pos)
        OR      A
        SBC     HL,DE
        JR      Z,.vs_page
        LD      HL,(view_next)
        LD      (view_pos),HL
        JR      .vs_page

.vs_up:
        LD      HL,(view_pos)
        LD      A,H
        OR      L
        JR      Z,.vs_page
        LD      (view_goal),HL
        LD      HL,0
.vs_up_lp:
        LD      (view_try),HL
        LD      (view_pos),HL
        XOR     A
        LD      (view_draw),A
        CALL    view_walk
        LD      HL,(view_next)
        LD      DE,(view_try)
        OR      A
        SBC     HL,DE
        JR      Z,.vs_up_use
        LD      HL,(view_next)
        LD      DE,(view_goal)
        OR      A
        SBC     HL,DE
        JR      NC,.vs_up_use
        LD      HL,(view_next)
        JR      .vs_up_lp
.vs_up_use:
        LD      HL,(view_try)
        LD      (view_pos),HL
        JP      .vs_page

.vs_nofile:
        LD      DE,msg_nofile
        JR      .vs_err
.vs_fail:
        LD      DE,msg_view_open
.vs_err:
        LD      (view_msg),DE
        SCF
        RET

;------------------------------------------------------------------------------
; view_load — open file_src_* into [stack_top, BDOS-256)
;------------------------------------------------------------------------------
view_load:
        LD      A,(file_src_drv)
        LD      C,A
        LD      HL,file_src_name
        LD      DE,view_fcb
        CALL    file_set_fcb
        LD      DE,view_fcb
        LD      C,F_OPEN
        CALL    BDOS
        CP      0FFh
        SCF
        RET     Z
        XOR     A
        LD      (view_fcb+FCB_CR),A
        LD      (view_trunc),A

        LD      HL,stack_top
        LD      (view_buf),HL
        LD      HL,(BDOS+1)
        LD      DE,256
        OR      A
        SBC     HL,DE
        LD      (view_end),HL
        LD      HL,0
        LD      (view_len),HL

        LD      HL,(view_end)
        LD      DE,(view_buf)
        OR      A
        SBC     HL,DE
        JR      C,.vl_nomem
        LD      DE,128
        SBC     HL,DE
        JR      C,.vl_nomem

.vl_rd:
        LD      HL,(view_buf)
        LD      DE,(view_len)
        ADD     HL,DE
        LD      DE,128
        ADD     HL,DE
        LD      DE,(view_end)
        OR      A
        SBC     HL,DE
        JR      C,.vl_room
        JR      NZ,.vl_full
.vl_room:
        LD      HL,(view_buf)
        LD      DE,(view_len)
        ADD     HL,DE
        EX      DE,HL
        LD      C,F_DMAOFF
        CALL    BDOS
        LD      DE,view_fcb
        LD      C,F_READ
        CALL    BDOS
        OR      A
        JR      Z,.vl_got
        CP      1
        JR      Z,.vl_done
        JR      .vl_io
.vl_got:
        LD      HL,(view_buf)
        LD      DE,(view_len)
        ADD     HL,DE
        LD      B,128
.vl_sc:
        LD      A,(HL)
        CP      1Ah
        JR      Z,.vl_cut
        INC     HL
        DJNZ    .vl_sc
        LD      HL,(view_len)
        LD      DE,128
        ADD     HL,DE
        LD      (view_len),HL
        JR      .vl_rd
.vl_cut:
        LD      DE,(view_buf)
        OR      A
        SBC     HL,DE
        LD      (view_len),HL
        JR      .vl_done
.vl_full:
        LD      A,1
        LD      (view_trunc),A
.vl_done:
        LD      DE,view_fcb
        LD      C,F_CLOSE
        CALL    BDOS
        XOR     A
        RET
.vl_nomem:
.vl_io:
        LD      DE,view_fcb
        LD      C,F_CLOSE
        CALL    BDOS
        SCF
        RET

;------------------------------------------------------------------------------
; view_walk — one page from (view_pos). Draws when view_draw ≠ 0.
; Sets view_next and view_eof.
;------------------------------------------------------------------------------
view_walk:
        LD      HL,(view_pos)
        LD      (vw_off),HL
        LD      A,1
        LD      (vw_row),A
        LD      B,VIEW_ROWS
.vw_row:
        PUSH    BC
        LD      A,(view_draw)
        OR      A
        JR      Z,.vw_ncol
        LD      A,(vw_row)
        LD      B,A
        LD      C,1
        CALL    term_cup
.vw_ncol:
        XOR     A
        LD      (vw_col),A
.vw_ch:
        LD      A,(vw_col)
        CP      VIEW_COLS
        JR      Z,.vw_nextrow
        CALL    view_peek
        JR      C,.vw_eof
        CP      0Dh
        JR      Z,.vw_cr
        CP      0Ah
        JR      Z,.vw_lf
        CP      09h
        JR      Z,.vw_tab
        CP      20h
        JR      C,.vw_dot
        CP      7Fh
        JR      NC,.vw_dot
        JR      .vw_emit
.vw_dot:
        LD      A,'.'
.vw_emit:
        LD      C,A
        CALL    view_skip
        LD      A,(view_draw)
        OR      A
        JR      Z,.vw_col1
        LD      A,C
        CALL    bdos_conout
.vw_col1:
        LD      HL,vw_col
        INC     (HL)
        JR      .vw_ch
.vw_tab:
        CALL    view_skip
.vw_tabsp:
        LD      A,(vw_col)
        CP      VIEW_COLS
        JR      Z,.vw_nextrow
        LD      A,(view_draw)
        OR      A
        JR      Z,.vw_tabc
        LD      A,' '
        CALL    bdos_conout
.vw_tabc:
        LD      HL,vw_col
        INC     (HL)
        LD      A,(HL)
        AND     7
        JR      NZ,.vw_tabsp
        JR      .vw_ch
.vw_cr:
        CALL    view_skip
        CALL    view_peek
        JR      C,.vw_nextrow
        CP      0Ah
        JR      NZ,.vw_nextrow
        CALL    view_skip
        JR      .vw_nextrow
.vw_lf:
        CALL    view_skip
.vw_nextrow:
        LD      HL,vw_row
        INC     (HL)
        POP     BC
        DEC     B
        JP      NZ,.vw_row
        JR      .vw_set
.vw_eof:
        POP     BC
        LD      A,1
        LD      (view_eof),A
        JR      .vw_set2
.vw_set:
        XOR     A
        LD      (view_eof),A
.vw_set2:
        LD      HL,(vw_off)
        LD      (view_next),HL
        LD      DE,(view_len)
        OR      A
        SBC     HL,DE
        RET     C
        LD      A,1
        LD      (view_eof),A
        RET

; view_peek — A = byte at vw_off, CY if past view_len
view_peek:
        PUSH    HL
        LD      HL,(vw_off)
        LD      DE,(view_len)
        OR      A
        SBC     HL,DE
        POP     HL
        JR      C,.vp_ok
        SCF
        RET
.vp_ok:
        PUSH    HL
        LD      HL,(view_buf)
        LD      DE,(vw_off)
        ADD     HL,DE
        LD      A,(HL)
        POP     HL
        OR      A
        RET

view_skip:
        PUSH    HL
        LD      HL,(vw_off)
        INC     HL
        LD      (vw_off),HL
        POP     HL
        RET

;------------------------------------------------------------------------------
; view_footer — name on row 23, key hint on row 24
;------------------------------------------------------------------------------
view_footer:
        LD      HL,file_src_name
        LD      DE,view_name
        CALL    panel_fmt_name
        LD      B,23
        LD      C,1
        CALL    term_cup
        LD      DE,msg_view
        CALL    bdos_print
        LD      HL,view_name
        CALL    term_puts
        LD      A,(view_trunc)
        OR      A
        JR      Z,.vf_bar
        LD      DE,msg_view_cut
        CALL    bdos_print
.vf_bar:
        LD      B,24
        LD      C,1
        CALL    term_cup
        CALL    term_rev_on
        LD      DE,msg_view_keys
        CALL    bdos_print
        LD      B,20
.vf_pad:
        LD      A,' '
        CALL    bdos_conout
        DJNZ    .vf_pad
        CALL    term_rev_off
        RET

view_draw:      DB      0
view_trunc:     DB      0
view_eof:       DB      0
view_pos:       DW      0
view_next:      DW      0
view_goal:      DW      0
view_try:       DW      0
view_len:       DW      0
view_buf:       DW      0
view_end:       DW      0
vw_off:         DW      0
vw_row:         DB      0
vw_col:         DB      0
view_msg:       DW      msg_nofile
view_name:      DS      14
view_fcb:       DS      FCB_SIZE

msg_view:       DB      "View $"
msg_view_cut:   DB      " [cut]$"
msg_view_keys:  DB      " Space/Dn next   Up prev   Esc back$"
msg_view_open:  DB      "Cannot open$"
