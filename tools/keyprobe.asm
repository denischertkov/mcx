;==============================================================================
; tools/keyprobe.asm — KEYPROBE.COM
;
; Calibration utility for MCX keymaps on a real CP/M 2.2 + VT100/ANSI console.
; Prints the raw byte sequence received for each keypress as hex.
;
; Usage on the machine:
;   KEYPROBE
;   Press keys of interest: arrows, F1–F10, Alt-F1, Alt-F2, Tab, Enter, etc.
;   After each press, a line of hex bytes is printed until input goes idle.
;   Ctrl-C exits to CCP.
;
; Paste the output back into the MCX PR/issue so keymap.asm can be calibrated
; for your Linux terminal + serial + Grant Searle SBC stack.
;==============================================================================

        OPT     reset
        DEVICE  NOSLOT64K
        OUTPUT  "build/KEYPROBE.COM"

        INCLUDE "include/cpm.inc"

        ORG     TPA_START

;------------------------------------------------------------------------------
; Entry — banner, then probe loop
;------------------------------------------------------------------------------
start:
        LD      SP,stack_top
        LD      DE,msg_banner
        CALL    bdos_print

main_loop:
        CALL    wait_char
        CP      CTRL_C
        JP      Z,do_exit

        LD      DE,msg_prefix
        CALL    bdos_print

        CALL    print_hex_byte          ; first byte already in A
        CALL    drain_sequence

        LD      DE,msg_crlf
        CALL    bdos_print
        JR      main_loop

do_exit:
        LD      DE,msg_bye
        CALL    bdos_print
        JP      bdos_exit

;------------------------------------------------------------------------------
; wait_char — block until a raw character arrives → A (no echo)
;------------------------------------------------------------------------------
wait_char:
.wc_poll:
        CALL    bdos_conin_nb
        OR      A
        JR      Z,.wc_poll
        RET

;------------------------------------------------------------------------------
; drain_sequence — poll for follow-up bytes of an ESC / Alt sequence
; Uses a software spin budget (no RTC). Tuned for typical serial VT100 bursts.
;------------------------------------------------------------------------------
drain_sequence:
        LD      B,12                     ; max extra bytes per key
.ds_next:
        PUSH    BC
        CALL    poll_with_budget
        POP     BC
        OR      A
        RET     Z
        CALL    print_hex_byte
        DJNZ    .ds_next
        RET

;------------------------------------------------------------------------------
; poll_with_budget — return A=char or 0 on timeout
;------------------------------------------------------------------------------
poll_with_budget:
        LD      DE,4000
.pb_outer:
        PUSH    DE
        CALL    bdos_conin_nb
        POP     DE
        OR      A
        RET     NZ
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,.pb_outer
        XOR     A
        RET

;------------------------------------------------------------------------------
; print_hex_byte — emit " HH" for value in A (A preserved)
;------------------------------------------------------------------------------
print_hex_byte:
        PUSH    AF
        PUSH    AF
        LD      A,' '
        CALL    bdos_conout
        POP     AF
        PUSH    AF
        RRA
        RRA
        RRA
        RRA
        AND     0Fh
        CALL    hex_digit
        CALL    bdos_conout
        POP     AF
        AND     0Fh
        CALL    hex_digit
        CALL    bdos_conout
        POP     AF
        RET

;------------------------------------------------------------------------------
; hex_digit — A = 0..15 → ASCII '0'..'9'/'A'..'F'
;------------------------------------------------------------------------------
hex_digit:
        CP      10
        JR      C,.hd_num
        ADD     A,'A'-10
        RET
.hd_num:
        ADD     A,'0'
        RET

; --- messages ----------------------------------------------------------------
msg_banner:
        DB      "MCX KEYPROBE - press keys; Ctrl-C to quit",CR,LF
        DB      "Each line = raw bytes for one key (hex)",CR,LF
        DB      "Try: arrows F1-F10 Alt-F1 Alt-F2 Tab Enter BS Del",CR,LF
        DB      "$"

msg_prefix:
        DB      "KEY:$"

msg_crlf:
        DB      CR,LF,"$"

msg_bye:
        DB      CR,LF,"KEYPROBE exit",CR,LF,"$"

; Library modules (code + their data)
        INCLUDE "bdos/bdos.asm"
        INCLUDE "term/ansi.asm"

        DS      128
stack_top:
