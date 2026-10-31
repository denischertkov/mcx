;==============================================================================
; tools/attrtest.asm — ATTRTEST.COM
;
; Prints labelled reverse-video samples via the same BDOS CONOUT path as MCX.
; Run under the same minicom session you use for MCX and report which lines
; look correct (only the word REV inverted, text after it normal).
;
; Press any key between screens; Ctrl-C quits early.
;==============================================================================

        OPT     reset
        DEVICE  NOSLOT64K
        OUTPUT  "build/ATTRTEST.COM"

        INCLUDE "include/cpm.inc"

        ORG     TPA_START

start:
        LD      SP,stack_top
        LD      DE,msg_banner
        CALL    bdos_print
        CALL    wait_key
        CP      CTRL_C
        JP      Z,do_exit

        ; --- Test 1: ESC[7m ... ESC[0m via CONOUT (MCX path) -----------------
        LD      DE,msg_t1
        CALL    bdos_print
        CALL    sgr_7
        LD      DE,msg_rev
        CALL    bdos_print
        CALL    sgr_0
        LD      DE,msg_after
        CALL    bdos_print
        CALL    wait_key
        CP      CTRL_C
        JP      Z,do_exit

        ; --- Test 2: ESC[7m ... ESC[27m -------------------------------------
        LD      DE,msg_t2
        CALL    bdos_print
        CALL    sgr_7
        LD      DE,msg_rev
        CALL    bdos_print
        CALL    sgr_27
        LD      DE,msg_after
        CALL    bdos_print
        CALL    wait_key
        CP      CTRL_C
        JP      Z,do_exit

        ; --- Test 3: ESC[7m ... ESC[m (empty reset) -------------------------
        LD      DE,msg_t3
        CALL    bdos_print
        CALL    sgr_7
        LD      DE,msg_rev
        CALL    bdos_print
        CALL    sgr_empty
        LD      DE,msg_after
        CALL    bdos_print
        CALL    wait_key
        CP      CTRL_C
        JP      Z,do_exit

        ; --- Test 4: leak probe — reverse ON, print REV, NO off, then text --
        LD      DE,msg_t4
        CALL    bdos_print
        CALL    sgr_7
        LD      DE,msg_rev
        CALL    bdos_print
        LD      DE,msg_leak
        CALL    bdos_print
        CALL    wait_key
        CP      CTRL_C
        JP      Z,do_exit
        CALL    sgr_0

        ; --- Test 5: two lines — on/off each (dirty-redraw simulation) ------
        LD      DE,msg_t5
        CALL    bdos_print
        CALL    sgr_0
        LD      DE,msg_line_a
        CALL    bdos_print
        CALL    sgr_7
        LD      DE,msg_line_b
        CALL    bdos_print
        CALL    sgr_0
        LD      DE,msg_line_c
        CALL    bdos_print
        CALL    wait_key

do_exit:
        CALL    sgr_0
        LD      DE,msg_bye
        CALL    bdos_print
        JP      bdos_exit

;------------------------------------------------------------------------------
wait_key:
        CALL    bdos_conin_nb
        OR      A
        JR      Z,wait_key
        RET

; emit bytes
emit:   CALL    bdos_conout
        RET

sgr_7:
        LD      A,ESC
        CALL    emit
        LD      A,'['
        CALL    emit
        LD      A,'7'
        CALL    emit
        LD      A,'m'
        CALL    emit
        RET

sgr_0:
        LD      A,ESC
        CALL    emit
        LD      A,'['
        CALL    emit
        LD      A,'0'
        CALL    emit
        LD      A,'m'
        CALL    emit
        RET

sgr_27:
        LD      A,ESC
        CALL    emit
        LD      A,'['
        CALL    emit
        LD      A,'2'
        CALL    emit
        LD      A,'7'
        CALL    emit
        LD      A,'m'
        CALL    emit
        RET

sgr_empty:
        LD      A,ESC
        CALL    emit
        LD      A,'['
        CALL    emit
        LD      A,'m'
        CALL    emit
        RET

msg_banner:
        DB      "MCX ATTRTEST — any key=next, Ctrl-C=quit",CR,LF
        DB      "Expect: only word REV inverted; text after it normal.",CR,LF
        DB      "$"

msg_t1: DB      CR,LF,"T1 CONOUT [7m / [0m : $"
msg_t2: DB      CR,LF,"T2 CONOUT [7m / [27m: $"
msg_t3: DB      CR,LF,"T3 CONOUT [7m / [m  : $"
msg_t4: DB      CR,LF,"T4 LEAK (no off)   : $"
msg_t5: DB      CR,LF,"T5 three lines (B should be rev only):",CR,LF,"$"

msg_rev:   DB      "REV$"
msg_after: DB      " after$",CR,LF,"$"
msg_leak:  DB      " SHOULD_STAY_REV$",CR,LF,"$"
msg_line_a: DB     "  A normal",CR,LF,"$"
msg_line_b: DB     "  B REVLINE",CR,LF,"$"
msg_line_c: DB     "  C normal",CR,LF,"$"
msg_bye:   DB      CR,LF,"ATTRTEST done",CR,LF,"$"

        INCLUDE "bdos/bdos.asm"

        DS      64
stack_top:
