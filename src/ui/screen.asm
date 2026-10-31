;==============================================================================
; ui/screen.asm — screen redraw helpers (full and dirty)
;
; Public entry points:
;   screen_draw_all     full clear + both panels + chrome
;   screen_tab_switch   after active_panel flipped — both panels (no CLS)
;   screen_nav_update   after cursor move: DE=old cursor, BC=old scroll (active)
;
; Globals: panel_left, panel_right, active_panel
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

        LD      IX,panel_left
        LD      C,1
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      NZ,.sd_li
        LD      A,1
.sd_li: CALL    panel_draw

        LD      B,1
.sd_sep:
        PUSH    BC
        LD      C,40
        CALL    term_cup
        CALL    term_rev_off
        LD      A,'|'
        CALL    bdos_conout
        POP     BC
        INC     B
        LD      A,B
        CP      23
        JR      C,.sd_sep

        LD      IX,panel_right
        LD      C,41
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      Z,.sd_ri
        LD      A,1
.sd_ri: CALL    panel_draw

        CALL    status_clear
        CALL    status_draw_fkeys

        POP     IX
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; screen_tab_switch — repaint both panels (avoids half-updated cursor marks)
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
        JR      NZ,.st_li
        LD      A,1
.st_li: CALL    panel_draw

        LD      IX,panel_right
        LD      C,41
        LD      A,(active_panel)
        OR      A
        LD      A,0
        JR      Z,.st_ri
        LD      A,1
.st_ri: CALL    panel_draw

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
        JR      NZ,.sn_full
        LD      A,H
        CP      B
        JR      NZ,.sn_full

        CALL    screen_active_col
        LD      A,C
        LD      (sn_col),A

        EX      DE,HL                   ; HL = old cursor
        LD      A,(sn_col)
        LD      C,A
        XOR     A                       ; no highlight
        CALL    panel_draw_index

        LD      L,(IX+P_CURSOR)
        LD      H,(IX+P_CURSOR+1)
        LD      A,(sn_col)
        LD      C,A
        LD      A,1
        CALL    panel_draw_index
        JR      .sn_done

.sn_full:
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
; screen_active_col — C = 1 or 41 from active_panel
;------------------------------------------------------------------------------
screen_active_col:
        LD      A,(active_panel)
        OR      A
        LD      C,1
        RET     Z
        LD      C,41
        RET

sn_col:         DB      0
