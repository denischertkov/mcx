;==============================================================================
; keys/input.asm — raw console reader + ESC sequence parser
;
; Public entry points:
;   keys_get      block until a key → A = logical code (keys.inc)
;
; After ESC, wait only long enough for the rest of a serial sequence.
; A human second keypress must not arrive in that window: otherwise Esc
; exits only as Esc+key, which is what the viewer and editor were doing.
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
        ; Short wait: CSI/SS3 bytes are already on the wire. A lone Esc
        ; must return before the user can press another key.
        CALL    keys_poll_esc
        OR      A
        JR      NZ,.kg_esc2
        LD      A,KEY_ESC               ; lone ESC
        RET

.kg_esc2:
        CP      '['
        JR      Z,.kg_csi
        CP      'O'
        JR      Z,.kg_ss3
        ; VT52 arrows, or Esc followed by a byte that is not a CSI/SS3
        ; sequence. A bare Esc still times out above. PgUp/PgDn are CSI and
        ; are not handled here.
        CALL    keymap_lookup_vt52
        CP      KEY_NONE
        RET     NZ
        LD      A,KEY_ESC
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
; keys_poll_esc  — brief wait for the byte that distinguishes Esc from CSI
; keys_poll_long — rest of a sequence already in progress
; Both return A = byte, or 0 on timeout.
;------------------------------------------------------------------------------
keys_poll_esc:
        LD      DE,800
        JR      keys_poll
keys_poll_long:
        LD      DE,12000
keys_poll:
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
