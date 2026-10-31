;==============================================================================
; ui/screen.asm — full-screen redraw of both panels + chrome
;
; Public entry points:
;   screen_draw_all   redraw everything from panel structs + active flag
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
