;==============================================================================
; mcx.asm — MCX main entry, init, and interactive loop (iteration 2 shell)
;
; Builds MCX.COM. Dual panels, directory listing, navigation, drive change,
; F1 help, F10 quit. File ops (view/edit/copy/rename/run) come in iteration 3.
;==============================================================================

        OPT     reset
        DEVICE  NOSLOT64K
        OUTPUT  "build/MCX.COM"

        INCLUDE "include/cpm.inc"
        INCLUDE "include/keys.inc"
        INCLUDE "include/mcx.inc"

        ORG     TPA_START

;------------------------------------------------------------------------------
; start — SP, parse args, load dirs, draw, main loop
;------------------------------------------------------------------------------
start:
        LD      SP,stack_top

        CALL    bdos_get_drv
        LD      (panel_left+P_DRIVE),A
        LD      (panel_right+P_DRIVE),A
        XOR     A
        LD      (active_panel),A

        CALL    parse_args

        LD      IX,panel_left
        CALL    dir_load
        LD      IX,panel_right
        CALL    dir_load

        CALL    screen_draw_all

main_loop:
        CALL    keys_get
        CP      KEY_F10
        JP      Z,do_quit
        CP      KEY_CTRL_C
        JP      Z,do_quit
        CP      KEY_F1
        JP      Z,do_help
        CP      KEY_TAB
        JP      Z,do_tab
        CP      KEY_UP
        JP      Z,do_up
        CP      KEY_DOWN
        JP      Z,do_down
        CP      KEY_CTRL_L
        JP      Z,do_drv_left
        CP      KEY_CTRL_R
        JP      Z,do_drv_right
        ; stubs reserved for iter 3
        CP      KEY_F3
        JR      Z,do_stub
        CP      KEY_F4
        JR      Z,do_stub
        CP      KEY_F5
        JR      Z,do_stub
        CP      KEY_F6
        JR      Z,do_stub
        CP      KEY_ENTER
        JR      Z,do_stub
        JR      main_loop

do_stub:
        LD      DE,msg_stub
        CALL    status_msg
        JR      main_loop

;------------------------------------------------------------------------------
; do_quit — restore console and warm-boot
;------------------------------------------------------------------------------
do_quit:
        CALL    term_cls
        LD      DE,msg_bye
        CALL    bdos_print
        JP      bdos_exit

;------------------------------------------------------------------------------
; do_help — F1 overlay then full redraw
;------------------------------------------------------------------------------
do_help:
        CALL    help_show
        CALL    screen_draw_all
        JP      main_loop

;------------------------------------------------------------------------------
; do_tab — switch active panel (headers + cursor rows only)
;------------------------------------------------------------------------------
do_tab:
        LD      A,(active_panel)
        XOR     1
        LD      (active_panel),A
        CALL    screen_tab_switch
        JP      main_loop

;------------------------------------------------------------------------------
; do_up / do_down — move cursor; repaint the panel only if it scrolled
;------------------------------------------------------------------------------
do_up:
        CALL    active_ix
        LD      E,(IX+P_CURSOR)
        LD      D,(IX+P_CURSOR+1)
        LD      C,(IX+P_SCROLL)
        LD      B,(IX+P_SCROLL+1)
        CALL    panel_cursor_up
        CALL    screen_nav_update
        JP      main_loop

do_down:
        CALL    active_ix
        LD      E,(IX+P_CURSOR)
        LD      D,(IX+P_CURSOR+1)
        LD      C,(IX+P_SCROLL)
        LD      B,(IX+P_SCROLL+1)
        CALL    panel_cursor_down
        CALL    screen_nav_update
        JP      main_loop

;------------------------------------------------------------------------------
; do_drv_left / do_drv_right — Ctrl-L / Ctrl-R drive menu
;------------------------------------------------------------------------------
do_drv_left:
        CALL    drive_pick
        CP      0FFh
        JR      Z,.ddl_cancel
        LD      (panel_left+P_DRIVE),A
        LD      IX,panel_left
        CALL    dir_load
.ddl_cancel:
        CALL    screen_draw_all
        JP      main_loop

do_drv_right:
        CALL    drive_pick
        CP      0FFh
        JR      Z,.ddr_cancel
        LD      (panel_right+P_DRIVE),A
        LD      IX,panel_right
        CALL    dir_load
.ddr_cancel:
        CALL    screen_draw_all
        JP      main_loop

;------------------------------------------------------------------------------
; active_ix — set IX to active panel
;------------------------------------------------------------------------------
active_ix:
        LD      A,(active_panel)
        OR      A
        JR      NZ,.ai_r
        LD      IX,panel_left
        RET
.ai_r:
        LD      IX,panel_right
        RET

;------------------------------------------------------------------------------
; parse_args — optional "D:" / "D: E:" from CCP tail at 0080h
; Uses arg_left = remaining bytes in the tail while scanning.
;------------------------------------------------------------------------------
parse_args:
        LD      A,(DMA_DEFAULT)
        LD      (arg_left),A
        OR      A
        RET     Z
        LD      HL,DMA_DEFAULT+1
        CALL    skip_spaces
        RET     Z
        CALL    try_drive
        CP      0FFh
        RET     Z
        LD      (panel_left+P_DRIVE),A
        CALL    skip_spaces
        RET     Z
        CALL    try_drive
        CP      0FFh
        RET     Z
        LD      (panel_right+P_DRIVE),A
        RET

; HL→tail; skip spaces. Returns Z if no chars left. A=(HL) if NZ.
skip_spaces:
.ss:
        LD      A,(arg_left)
        OR      A
        RET     Z
        LD      A,(HL)
        CP      ' '
        JR      NZ,.ss_done
        INC     HL
        LD      A,(arg_left)
        DEC     A
        LD      (arg_left),A
        JR      .ss
.ss_done:
        OR      A                       ; NZ — have a character
        RET

; try_drive — "X" or "X:"; A=0..15 or FFh; updates HL/arg_left
try_drive:
        LD      A,(arg_left)
        OR      A
        JR      Z,.td_fail
        LD      A,(HL)
        CALL    upcase
        CP      'A'
        JR      C,.td_fail
        CP      'P'+1
        JR      NC,.td_fail
        SUB     'A'
        LD      B,A
        INC     HL
        LD      A,(arg_left)
        DEC     A
        LD      (arg_left),A
        JR      Z,.td_ok                ; no room for ':'
        LD      A,(HL)
        CP      ':'
        JR      NZ,.td_ok
        INC     HL
        LD      A,(arg_left)
        DEC     A
        LD      (arg_left),A
.td_ok:
        LD      A,B
        RET
.td_fail:
        LD      A,0FFh
        RET

upcase:
        CP      'a'
        RET     C
        CP      'z'+1
        RET     NC
        SUB     20h
        RET

arg_left:       DB      0

msg_bye:        DB      "MCX exit",CR,LF,"$"
msg_stub:       DB      "Not implemented yet (iteration 3)$"

active_panel:   DB      0

; Panels (large)
panel_left:     DS      PANEL_BYTES
panel_right:    DS      PANEL_BYTES

; --- modules -----------------------------------------------------------------
        INCLUDE "bdos/bdos.asm"
        INCLUDE "term/ansi.asm"
        INCLUDE "keys/keymap.asm"
        INCLUDE "keys/input.asm"
        INCLUDE "fs/dir.asm"
        INCLUDE "ui/panel.asm"
        INCLUDE "ui/status.asm"
        INCLUDE "ui/screen.asm"
        INCLUDE "ui/drive.asm"
        INCLUDE "help/help.asm"

        DS      256
stack_top:
