;==============================================================================
; keys/input.asm — raw console reader + ESC sequence parser
;
; Public entry points:
;   keys_get      block until a key → A = logical code (keys.inc)
;
; After ESC, uses an extended poll budget so CSI '[' is not dropped (hardware
; sometimes returned 1B 44 instead of 1B 5B 44 on the first Left after idle).
;
; Depends on: bdos_conin_nb, keymap_lookup_csi / keymap_lookup_ss3 /
;             keymap_lookup_vt52
;==============================================================================

        INCLUDE "include/cpm.inc"
        INCLUDE "include/keys.inc"

;------------------------------------------------------------------------------
; keys_get — blocking; returns logical key in A
;------------------------------------------------------------------------------
keys_get:
.kg_wait:
        CALL    bdos_conin_nb
        OR      A
        JR      Z,.kg_wait

        CP      ESC
        JR      Z,.kg_esc
        ; plain ASCII / control — return as-is
        RET

; --- ESC sequence ------------------------------------------------------------
.kg_esc:
        ; Longer wait for the byte after ESC
        CALL    keys_poll_long
        OR      A
        JR      NZ,.kg_esc2
        LD      A,KEY_ESC               ; lone ESC
        RET

.kg_esc2:
        CP      '['
        JR      Z,.kg_csi
        CP      'O'
        JR      Z,.kg_ss3
        ; VT52-style ESC A/B/C/D (and bare ESC D seen on hardware)
        CALL    keymap_lookup_vt52
        CP      KEY_NONE
        RET     NZ
        LD      A,KEY_NONE
        RET

; CSI: ESC [ ... letter-or-tilde
.kg_csi:
        LD      HL,csi_buf
        LD      B,CSI_MAX
.csi_loop:
        PUSH    BC
        PUSH    HL
        CALL    keys_poll_long
        POP     HL
        POP     BC
        OR      A
        JR      Z,.csi_abort
        LD      (HL),A
        INC     HL
        CP      '~'
        JR      Z,.csi_done
        CP      'A'
        JR      C,.csi_cont
        CP      'Z'+1
        JR      C,.csi_done
.csi_cont:
        DJNZ    .csi_loop
.csi_abort:
        LD      A,KEY_NONE
        RET
.csi_done:
        ; HL points past last byte; compute length
        LD      DE,csi_buf
        OR      A
        SBC     HL,DE
        LD      B,L                     ; B = length
        LD      HL,csi_buf
        CALL    keymap_lookup_csi
        RET

; SS3: ESC O X
.kg_ss3:
        CALL    keys_poll_long
        OR      A
        JR      NZ,.ss3_got
        LD      A,KEY_ESC
        RET
.ss3_got:
        CALL    keymap_lookup_ss3
        RET

;------------------------------------------------------------------------------
; keys_poll_long — wait for next raw byte with extended budget → A or 0
;------------------------------------------------------------------------------
keys_poll_long:
        LD      DE,12000
.kpl:
        PUSH    DE
        CALL    bdos_conin_nb
        POP     DE
        OR      A
        RET     NZ
        DEC     DE
        LD      A,D
        OR      E
        JR      NZ,.kpl
        XOR     A
        RET

CSI_MAX         EQU     8
csi_buf:        DS      CSI_MAX
