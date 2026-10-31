;==============================================================================
; ui/status.asm — status line (row 23) and F-key legend (row 24)
;
; Public entry points:
;   status_draw_fkeys   paint bottom legend
;   status_msg          DE → $-terminated message on row 23
;   status_clear        clear row 23
;   status_prompt_drv   A='L'/'R' prompt; → A = drive 0..15 or 0FFh cancel
;   status_edit_name    DE=prompt $, HL=initial zstring
;                       → CY cancel, else HL = name_edit zstring
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

;------------------------------------------------------------------------------
; status_edit_name — one-line 8.3 name. Letters, digits, one dot.
; Esc/Ctrl-C or empty Enter cancels (CY).
;------------------------------------------------------------------------------
status_edit_name:
        LD      (se_prompt),DE
        LD      DE,name_edit
        LD      B,12
.se_cp:
        LD      A,(HL)
        OR      A
        JR      Z,.se_cp0
        LD      (DE),A
        INC     HL
        INC     DE
        DJNZ    .se_cp
.se_cp0:
        XOR     A
        LD      (DE),A
.se_loop:
        CALL    status_edit_draw
        CALL    keys_get
        CP      KEY_ESC
        JP      Z,.se_cancel
        CP      KEY_CTRL_C
        JP      Z,.se_cancel
        CP      KEY_ENTER
        JR      Z,.se_enter
        CP      KEY_BS
        JR      Z,.se_bs
        CP      7Fh
        JR      Z,.se_bs
        CP      KEY_DEL
        JR      Z,.se_bs
        CP      ' '
        JR      C,.se_loop
        CALL    upcase
        CP      '.'
        JR      Z,.se_dot
        CP      '0'
        JR      C,.se_loop
        CP      '9'+1
        JR      C,.se_store
        CP      'A'
        JR      C,.se_loop
        CP      'Z'+1
        JR      NC,.se_loop
        JR      .se_store
.se_dot:
        CALL    se_len
        LD      A,B
        OR      A
        JR      Z,.se_loop
        CALL    se_has_dot
        JR      C,.se_loop
        LD      A,'.'
.se_store:
        PUSH    AF
        CALL    se_len
        LD      A,B
        CP      12
        JR      NC,.se_drop
        POP     AF
        PUSH    AF
        CP      '.'
        JR      Z,.se_put
        CALL    se_has_dot
        JR      NC,.se_name_lim
        CALL    se_ext_len
        CP      3
        JR      NC,.se_drop
        JR      .se_put
.se_name_lim:
        CALL    se_len
        LD      A,B
        CP      8
        JR      NC,.se_drop
.se_put:
        POP     AF
        LD      (HL),A
        INC     HL
        LD      (HL),0
        JP      .se_loop
.se_drop:
        POP     AF
        JP      .se_loop
.se_bs:
        CALL    se_len
        LD      A,B
        OR      A
        JP      Z,.se_loop
        DEC     HL
        LD      (HL),0
        JP      .se_loop
.se_enter:
        CALL    se_len
        LD      A,B
        OR      A
        JR      Z,.se_cancel
        LD      HL,name_edit
        OR      A
        RET
.se_cancel:
        SCF
        RET

status_edit_draw:
        CALL    term_rev_off
        CALL    status_clear
        LD      B,23
        LD      C,1
        CALL    term_cup
        LD      DE,(se_prompt)
        CALL    bdos_print
        LD      HL,name_edit
        CALL    term_puts
        CALL    term_rev_on
        LD      A,' '
        CALL    bdos_conout
        CALL    term_rev_off
        RET

; se_len — B = length, HL → terminating 0
se_len:
        LD      HL,name_edit
        LD      B,0
.sel:
        LD      A,(HL)
        OR      A
        RET     Z
        INC     HL
        INC     B
        JR      .sel

; se_has_dot — CY if name_edit contains '.'
se_has_dot:
        PUSH    HL
        LD      HL,name_edit
.shd:
        LD      A,(HL)
        OR      A
        JR      Z,.shd_no
        CP      '.'
        JR      Z,.shd_yes
        INC     HL
        JR      .shd
.shd_yes:
        POP     HL
        SCF
        RET
.shd_no:
        POP     HL
        OR      A
        RET

; se_ext_len — A = chars after the dot (0 if none)
se_ext_len:
        PUSH    HL
        LD      HL,name_edit
.sxe:
        LD      A,(HL)
        OR      A
        JR      Z,.sxe0
        CP      '.'
        JR      Z,.sxe_dot
        INC     HL
        JR      .sxe
.sxe_dot:
        LD      B,0
.sxe_n:
        INC     HL
        LD      A,(HL)
        OR      A
        JR      Z,.sxe_a
        INC     B
        JR      .sxe_n
.sxe_a:
        LD      A,B
        POP     HL
        RET
.sxe0:
        XOR     A
        POP     HL
        RET

se_prompt:      DW      0
name_edit:      DS      13

msg_fkeys:
        DB      "MCX0.5a 1Help 3View 4Edit 5Copy 6Ren 10Quit"
        DB      " ^L/^R drive Tab$"

msg_drv_prompt:
        DB      "Drive (A-P), Esc=cancel: $"
