;==============================================================================
; keys/keymap.asm — VT100 / VT52 sequence → logical key (from docs/keys.md)
;
; Public entry points:
;   keymap_lookup_vt52  A = byte after ESC → logical key or KEY_NONE
;   keymap_lookup_ss3   A = byte after ESC O → logical key or KEY_NONE
;   keymap_lookup_csi   HL → seq bytes, B = length → logical key or KEY_NONE
;==============================================================================

        INCLUDE "include/keys.inc"

;------------------------------------------------------------------------------
; keymap_lookup_vt52 — ESC A/B/C/D (also covers hardware 1B 44 for Left)
;------------------------------------------------------------------------------
keymap_lookup_vt52:
        CP      'A'
        JR      NZ,.v52_d
        LD      A,KEY_UP
        RET
.v52_d:
        CP      'B'
        JR      NZ,.v52_r
        LD      A,KEY_DOWN
        RET
.v52_r:
        CP      'C'
        JR      NZ,.v52_l
        LD      A,KEY_RIGHT
        RET
.v52_l:
        CP      'D'
        JR      NZ,.v52_none
        LD      A,KEY_LEFT
        RET
.v52_none:
        LD      A,KEY_NONE
        RET

;------------------------------------------------------------------------------
; keymap_lookup_ss3 — ESC O P..S → F1..F4
;------------------------------------------------------------------------------
keymap_lookup_ss3:
        CP      'P'
        JR      NZ,.ss3_q
        LD      A,KEY_F1
        RET
.ss3_q:
        CP      'Q'
        JR      NZ,.ss3_r
        LD      A,KEY_F2
        RET
.ss3_r:
        CP      'R'
        JR      NZ,.ss3_s
        LD      A,KEY_F3
        RET
.ss3_s:
        CP      'S'
        JR      NZ,.ss3_none
        LD      A,KEY_F4
        RET
.ss3_none:
        LD      A,KEY_NONE
        RET

;------------------------------------------------------------------------------
; keymap_lookup_csi — HL → body (no ESC/[), B = len
; Handles: A/B/C/D arrows, 3~ Del, 15~..21~ function keys
;------------------------------------------------------------------------------
keymap_lookup_csi:
        LD      A,B
        OR      A
        JR      Z,.csi_none
        CP      1
        JR      NZ,.csi_num
        ; single final byte
        LD      A,(HL)
        CP      'A'
        JR      NZ,.c1b
        LD      A,KEY_UP
        RET
.c1b:   CP      'B'
        JR      NZ,.c1c
        LD      A,KEY_DOWN
        RET
.c1c:   CP      'C'
        JR      NZ,.c1d
        LD      A,KEY_RIGHT
        RET
.c1d:   CP      'D'
        JR      NZ,.csi_none
        LD      A,KEY_LEFT
        RET

.csi_num:
        ; expect digits then '~'
        ; parse decimal number from HL, length B
        PUSH    BC
        PUSH    HL
        CALL    csi_parse_num           ; → HL = value, A=0 ok / FF fail
        POP     DE                      ; discard saved HL
        POP     BC
        OR      A
        JR      NZ,.csi_none
        ; HL = number
        LD      A,L
        CP      3
        JR      NZ,.cn15
        LD      A,KEY_DEL
        RET
.cn15:  CP      15
        JR      NZ,.cn16
        LD      A,KEY_F5
        RET
.cn16:  CP      16
        JR      NZ,.cn17
        LD      A,KEY_F6
        RET
.cn17:  CP      17                       ; xterm/vt220 F6 — 16~ is skipped
        JR      NZ,.cn18
        LD      A,KEY_F6
        RET
.cn18:  CP      18
        JR      NZ,.cn19
        LD      A,KEY_F8
        RET
.cn19:  CP      19
        JR      NZ,.cn20
        LD      A,KEY_F9
        RET
.cn20:  CP      20                       ; some terminals: F10 = 20~
        JR      NZ,.cn21
        LD      A,KEY_F10
        RET
.cn21:  CP      21                       ; xterm F10
        JR      NZ,.csi_none
        LD      A,KEY_F10
        RET

.csi_none:
        LD      A,KEY_NONE
        RET

;------------------------------------------------------------------------------
; csi_parse_num — HL → bytes, B = len; last should be '~'
; Returns HL = value, A = 0 success / 0FFh fail
;------------------------------------------------------------------------------
csi_parse_num:
        LD      A,B
        CP      2                       ; at least digit + '~'
        JR      C,.cp_fail
        ; check last is '~'
        LD      E,B
        LD      D,0
        PUSH    HL
        ADD     HL,DE
        DEC     HL
        LD      A,(HL)
        POP     HL
        CP      '~'
        JR      NZ,.cp_fail
        DEC     B                       ; exclude '~'
        LD      DE,0                    ; accumulator
.cp_loop:
        LD      A,B
        OR      A
        JR      Z,.cp_ok
        LD      A,(HL)
        INC     HL
        DEC     B
        SUB     '0'
        JR      C,.cp_fail
        CP      10
        JR      NC,.cp_fail
        ; DE = DE*10 + digit
        PUSH    HL
        PUSH    BC
        LD      L,E
        LD      H,D
        ADD     HL,HL                   ; *2
        LD      C,L
        LD      B,H
        ADD     HL,HL                   ; *4
        ADD     HL,HL                   ; *8
        ADD     HL,BC                   ; *10
        LD      C,A
        LD      B,0
        ADD     HL,BC
        LD      E,L
        LD      D,H
        POP     BC
        POP     HL
        JR      .cp_loop
.cp_ok:
        EX      DE,HL
        XOR     A
        RET
.cp_fail:
        LD      A,0FFh
        RET
