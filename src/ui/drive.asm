;==============================================================================
; ui/drive.asm — Norton Commander-style drive picker
;
; Public entry points:
;   drive_pick    list available drives; → A = 0..15 or 0FFh if cancel
;
; Discovers drives with BIOS SELDSK (HL=0 means absent). If none found, falls
; back to BDOS function 24 login vector bits.
;==============================================================================

        INCLUDE "include/cpm.inc"
        INCLUDE "include/keys.inc"

DRV_MENU_ROW    EQU     6
DRV_MENU_COL    EQU     30

;------------------------------------------------------------------------------
; drive_pick
;------------------------------------------------------------------------------
drive_pick:
        PUSH    BC
        PUSH    DE
        PUSH    HL

        CALL    drive_probe
        LD      A,(drv_count)
        OR      A
        JR      NZ,.dp_have
        XOR     A
        LD      (drv_list),A
        LD      A,1
        LD      (drv_count),A

.dp_have:
        XOR     A
        LD      (drv_sel),A
        CALL    drive_menu_draw

.dp_loop:
        CALL    keys_get
        CP      KEY_UP
        JR      Z,.dp_up
        CP      KEY_DOWN
        JR      Z,.dp_down
        CP      KEY_ENTER
        JR      Z,.dp_enter
        CP      KEY_ESC
        JR      Z,.dp_cancel
        CP      KEY_CTRL_C
        JR      Z,.dp_cancel
        CALL    drive_hotkey
        CP      0FFh
        JR      Z,.dp_loop
        JR      .dp_ret

.dp_up:
        LD      A,(drv_sel)
        OR      A
        JR      Z,.dp_loop
        DEC     A
        LD      (drv_sel),A
        CALL    drive_menu_draw
        JR      .dp_loop

.dp_down:
        LD      A,(drv_sel)
        INC     A
        LD      HL,drv_count
        CP      (HL)
        JR      NC,.dp_loop
        LD      (drv_sel),A
        CALL    drive_menu_draw
        JR      .dp_loop

.dp_enter:
        LD      A,(drv_sel)
        LD      HL,drv_list
        LD      E,A
        LD      D,0
        ADD     HL,DE
        LD      A,(HL)
        JR      .dp_ret

.dp_cancel:
        LD      A,0FFh
.dp_ret:
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; drive_hotkey — letter A-P → drive if listed, else FFh
;------------------------------------------------------------------------------
drive_hotkey:
        CP      'a'
        JR      C,.dh_u
        CP      'z'+1
        JR      NC,.dh_u
        SUB     20h
.dh_u:  CP      'A'
        JR      C,.dh_no
        CP      'P'+1
        JR      NC,.dh_no
        SUB     'A'
        LD      B,A
        LD      A,(drv_count)
        OR      A
        JR      Z,.dh_no
        LD      C,A
        LD      HL,drv_list
.dh_lp: LD      A,(HL)
        CP      B
        JR      Z,.dh_ok
        INC     HL
        DEC     C
        JR      NZ,.dh_lp
.dh_no: LD      A,0FFh
        RET
.dh_ok: LD      A,B
        RET

;------------------------------------------------------------------------------
; drive_menu_draw
;------------------------------------------------------------------------------
drive_menu_draw:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      B,DRV_MENU_ROW
        LD      C,DRV_MENU_COL
        CALL    term_cup
        LD      DE,msg_drv_title
        CALL    bdos_print

        LD      A,(drv_count)
        LD      B,A
        LD      HL,drv_list
        XOR     A                       ; index
.dmd_row:
        PUSH    AF
        PUSH    BC
        PUSH    HL

        LD      C,DRV_MENU_COL
        ADD     A,DRV_MENU_ROW+1
        LD      B,A
        CALL    term_cup

        POP     HL
        POP     BC
        POP     AF
        PUSH    AF
        PUSH    BC
        PUSH    HL

        LD      C,A
        LD      A,(drv_sel)
        CP      C
        JR      NZ,.dmd_norm
        LD      A,'>'
        CALL    bdos_conout
        LD      A,'>'
        CALL    bdos_conout
        LD      A,'>'
        CALL    bdos_conout
        JR      .dmd_name
.dmd_norm:
        LD      A,' '
        CALL    bdos_conout
        LD      A,' '
        CALL    bdos_conout
        LD      A,' '
        CALL    bdos_conout
.dmd_name:
        POP     HL
        PUSH    HL
        LD      A,(HL)
        ADD     A,'A'
        CALL    bdos_conout
        LD      A,':'
        CALL    bdos_conout
        LD      A,' '
        CALL    bdos_conout
        CALL    bdos_conout

        POP     HL
        POP     BC
        POP     AF
        INC     HL
        INC     A
        DJNZ    .dmd_row

        LD      A,(drv_count)
        ADD     A,DRV_MENU_ROW+1
        LD      B,A
        LD      C,DRV_MENU_COL
        CALL    term_cup
        LD      DE,msg_drv_hint
        CALL    bdos_print

        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; drive_probe
;------------------------------------------------------------------------------
drive_probe:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        XOR     A
        LD      (drv_count),A

        LD      HL,(0001h)
        LD      DE,24
        ADD     HL,DE
        LD      (drv_bios_sel),HL

        XOR     A
.dpr_lp:
        PUSH    AF
        LD      C,A
        LD      HL,(drv_bios_sel)
        CALL    drive_jp_hl
        LD      A,H
        OR      L
        POP     BC                      ; B = drive (from PUSH AF)
        JR      Z,.dpr_nx
        LD      A,(drv_count)
        LD      E,A
        LD      D,0
        LD      HL,drv_list
        ADD     HL,DE
        LD      (HL),B
        INC     A
        LD      (drv_count),A
.dpr_nx:
        LD      A,B
        INC     A
        CP      16
        JR      C,.dpr_lp

        LD      A,(drv_count)
        OR      A
        CALL    Z,drive_probe_login

        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; drive_probe_login — BDOS 24 bitmap → list
;------------------------------------------------------------------------------
drive_probe_login:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        XOR     A
        LD      (drv_count),A
        LD      C,24
        CALL    BDOS
        LD      B,0
.dpl:
        BIT     0,L
        JR      Z,.dpl_n
        LD      A,(drv_count)
        LD      E,A
        LD      D,0
        PUSH    HL
        LD      HL,drv_list
        ADD     HL,DE
        LD      (HL),B
        POP     HL
        INC     A
        LD      (drv_count),A
.dpl_n: SRL     H
        RR      L
        INC     B
        LD      A,B
        CP      16
        JR      C,.dpl
        POP     HL
        POP     DE
        POP     BC
        RET

drive_jp_hl:
        JP      (HL)

msg_drv_title:  DB      " Select drive $"
msg_drv_hint:   DB      " Enter/Esc $"

drv_count:      DB      0
drv_sel:        DB      0
drv_list:       DS      16
drv_bios_sel:   DW      0
