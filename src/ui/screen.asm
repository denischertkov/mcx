;==============================================================================
; ui/screen.asm — full-screen redraw of both panels + chrome
;
; Public entry points:
;   screen_draw_all     full clear + both panels + chrome
;   screen_tab_switch   headers + the two cursor rows (no CLS)
;   screen_nav_update   one panel after a cursor move
;                       IX=active, DE=old cursor, BC=old scroll
;
; Globals read:
;   panel_left, panel_right, active_panel (0=left, 1=right)
;==============================================================================

        INCLUDE "include/mcx.inc"

;------------------------------------------------------------------------------
; screen_draw_all
;------------------------------------------------------------------------------
screen_draw_all:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX

        CALL    term_rev_off
        CALL    term_gfx_off
        CALL    term_cls
        CALL    screen_draw_frame

        ; left panel
        LD      IX,panel_left
        LD      C,PANEL_LEFT_COL
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      NZ,.sd_left_inact
        LD      A,1
.sd_left_inact:
        CALL    panel_draw

        ; right panel
        LD      IX,panel_right
        LD      C,PANEL_RIGHT_COL
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      Z,.sd_right_inact
        LD      A,1
.sd_right_inact:
        CALL    panel_draw

        CALL    status_clear
        CALL    status_draw_fkeys

        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; screen_tab_switch — active_panel already flipped; no CLS
;------------------------------------------------------------------------------
screen_tab_switch:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IX
        CALL    term_rev_off

        LD      IX,panel_left
        LD      C,PANEL_LEFT_COL
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      NZ,.st_lh
        LD      A,1
.st_lh: CALL    panel_draw_header

        LD      IX,panel_right
        LD      C,PANEL_RIGHT_COL
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      Z,.st_rh
        LD      A,1
.st_rh: CALL    panel_draw_header

        LD      IX,panel_left
        LD      L,(IX+P_CURSOR)
        LD      H,(IX+P_CURSOR+1)
        LD      C,PANEL_LEFT_COL
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      NZ,.st_lc
        LD      A,1
.st_lc: CALL    panel_draw_index

        LD      IX,panel_right
        LD      L,(IX+P_CURSOR)
        LD      H,(IX+P_CURSOR+1)
        LD      C,PANEL_RIGHT_COL
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      Z,.st_rc
        LD      A,1
.st_rc: CALL    panel_draw_index

        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; screen_nav_update — IX=active panel; DE=old cursor; BC=old scroll
;------------------------------------------------------------------------------
screen_nav_update:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      L,(IX+P_SCROLL)
        LD      H,(IX+P_SCROLL+1)
        LD      A,L
        CP      C
        JR      NZ,.sn_panel
        LD      A,H
        CP      B
        JR      NZ,.sn_panel

        CALL    screen_active_col
        LD      A,C
        LD      (sn_col),A

        EX      DE,HL
        LD      A,(sn_col)
        LD      C,A
        XOR     A
        CALL    panel_draw_index

        LD      L,(IX+P_CURSOR)
        LD      H,(IX+P_CURSOR+1)
        LD      A,(sn_col)
        LD      C,A
        LD      A,1
        CALL    panel_draw_index
        JR      .sn_done

.sn_panel:
        CALL    screen_active_col
        LD      A,1
        CALL    panel_draw

.sn_done:
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
screen_active_col:
        LD      A,(active_panel)
        OR      A
        LD      C,PANEL_LEFT_COL
        RET     Z
        LD      C,PANEL_RIGHT_COL
        RET

;------------------------------------------------------------------------------
; screen_draw_frame — box around both panels. Row 1 top, row 22 bottom,
; bars in columns 1, 40 and 80. Leaves G0 in US-ASCII.
; DEC graphics: l q k / m j / x / w v
;------------------------------------------------------------------------------
screen_draw_frame:
        CALL    term_gfx_on
        LD      B,1
        CALL    frame_horiz
        LD      B,FRAME_BOTTOM
        CALL    frame_horiz
        LD      B,2
.sf_vert:
        PUSH    BC
        LD      C,1
        CALL    frame_bar
        LD      C,PANEL_GAP_COL
        CALL    frame_bar
        LD      C,SCR_COLS
        CALL    frame_bar
        POP     BC
        INC     B
        LD      A,B
        CP      FRAME_BOTTOM
        JR      C,.sf_vert
        CALL    term_gfx_off
        RET

; B = row, graphics charset already on. Top uses l/w/k, bottom m/v/j.
frame_horiz:
        PUSH    BC
        LD      C,1
        CALL    term_cup
        LD      A,B
        CP      1
        LD      A,'l'
        JR      Z,.fh_l
        LD      A,'m'
.fh_l:  CALL    bdos_conout
        LD      B,PANEL_WIDTH
        CALL    frame_q
        POP     BC
        PUSH    BC
        LD      A,B
        CP      1
        LD      A,'w'
        JR      Z,.fh_m
        LD      A,'v'
.fh_m:  CALL    bdos_conout
        LD      B,PANEL_WIDTH_R
        CALL    frame_q
        POP     BC
        LD      A,B
        CP      1
        LD      A,'k'
        JR      Z,.fh_r
        LD      A,'j'
.fh_r:  CALL    bdos_conout
        RET

; B = row, C = column. Graphics charset on.
frame_bar:
        CALL    term_cup
        LD      A,'x'
        CALL    bdos_conout
        RET

; B = count of horizontal line chars. BDOS clobbers A.
frame_q:
.fq:    LD      A,'q'
        CALL    bdos_conout
        DJNZ    .fq
        RET

sn_col:         DB      0
