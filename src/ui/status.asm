;==============================================================================
; ui/status.asm — status line (row 23) and F-key legend (row 24)
;
; Public entry points:
;   status_draw_fkeys   paint bottom legend
;   status_msg          DE → $-terminated message on row 23
;   status_clear        clear row 23
;   status_prompt_drv   A='L'/'R' prompt; → A = drive 0..15 or 0FFh cancel
;==============================================================================

        INCLUDE "include/cpm.inc"
        INCLUDE "include/mcx.inc"
        INCLUDE "include/keys.inc"

;------------------------------------------------------------------------------
; status_draw_fkeys — row 24 legend
;------------------------------------------------------------------------------
status_draw_fkeys:
        PUSH    BC
        PUSH    DE
        LD      B,24
        LD      C,1
        CALL    term_cup
        CALL    term_rev_off
        CALL    term_rev_on
        LD      DE,msg_fkeys
        CALL    bdos_print
        LD      B,12
.sdf_pad:
        LD      A,' '
        CALL    bdos_conout
        DJNZ    .sdf_pad
        CALL    term_rev_off
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; status_clear — erase row 23
;------------------------------------------------------------------------------
status_clear:
        PUSH    BC
        PUSH    AF
        LD      B,23
        LD      C,1
        CALL    term_cup
        LD      B,SCR_COLS
.sc_lp:
        LD      A,' '
        CALL    bdos_conout
        DJNZ    .sc_lp
        POP     AF
        POP     BC
        RET

;------------------------------------------------------------------------------
; status_msg — DE → $-string on row 23
;------------------------------------------------------------------------------
status_msg:
        PUSH    DE
        CALL    status_clear
        LD      B,23
        LD      C,1
        CALL    term_cup
        POP     DE
        PUSH    DE
        CALL    bdos_print
        POP     DE
        RET

;------------------------------------------------------------------------------
; status_prompt_drv — prompt for drive letter; A in = unused
; Returns A = 0..15 drive index, or 0FFh if Esc/Ctrl-C
;------------------------------------------------------------------------------
status_prompt_drv:
        PUSH    DE
        LD      DE,msg_drv_prompt
        CALL    status_msg
.sp_wait:
        CALL    keys_get
        CP      KEY_ESC
        JR      Z,.sp_cancel
        CP      KEY_CTRL_C
        JR      Z,.sp_cancel
        CP      'a'
        JR      C,.sp_up
        CP      'z'+1
        JR      NC,.sp_up
        SUB     20h                     ; a..z → A..Z
.sp_up:
        CP      'A'
        JR      C,.sp_wait
        CP      'P'+1
        JR      NC,.sp_wait
        SUB     'A'
        POP     DE
        RET
.sp_cancel:
        LD      A,0FFh
        POP     DE
        RET

msg_fkeys:
        DB      "MCX0.2l 1Help 3View 4Edit 5Copy 6Ren 10Quit"
        DB      " ^L/^R drive Tab$"

msg_drv_prompt:
        DB      "Drive (A-P), Esc=cancel: $"
