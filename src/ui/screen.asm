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
        CALL    term_cls

        ; left panel
        LD      IX,panel_left
        LD      C,1
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      NZ,.sd_left_inact
        LD      A,1
.sd_left_inact:
        CALL    panel_draw

        ; vertical separator
        LD      B,1
.sd_sep:
        PUSH    BC
        LD      C,40
        CALL    term_cup
        LD      A,'|'
        CALL    bdos_conout
        POP     BC
        INC     B
        LD      A,B
        CP      23
        JR      C,.sd_sep

        ; right panel
        LD      IX,panel_right
        LD      C,41
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
        LD      C,1
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      NZ,.st_lh
        LD      A,1
.st_lh: CALL    panel_draw_header

        LD      IX,panel_right
        LD      C,41
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      Z,.st_rh
        LD      A,1
.st_rh: CALL    panel_draw_header

        LD      IX,panel_left
        LD      L,(IX+P_CURSOR)
        LD      H,(IX+P_CURSOR+1)
        LD      C,1
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      NZ,.st_lc
        LD      A,1
.st_lc: CALL    panel_draw_index

        LD      IX,panel_right
        LD      L,(IX+P_CURSOR)
        LD      H,(IX+P_CURSOR+1)
        LD      C,41
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
        LD      C,1
        RET     Z
        LD      C,41
        RET

sn_col:         DB      0
