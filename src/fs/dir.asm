;==============================================================================
; fs/dir.asm — load a CP/M directory into a panel name list
;
; Public entry points:
;   dir_load      IX → panel struct; fills drive's file names, resets cursor
;
; Each entry is NAME_LEN (11) bytes: 8-char name + 3-char type, space-padded.
;
; Notes on Search First/Next (BDOS 17/18):
;   Some CP/M 2.2 builds rewrite the matched name into the FCB, which breaks
;   subsequent wildcard Search Next. Before every SNEXT we restore "????????.???"
;   in F1..T3 but keep EX/S1/S2 (search continuation state) intact.
;==============================================================================

        INCLUDE "include/cpm.inc"
        INCLUDE "include/mcx.inc"

;------------------------------------------------------------------------------
; dir_load — IX = panel
;------------------------------------------------------------------------------
dir_load:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IY

        XOR     A
        LD      (IX+P_COUNT),A
        LD      (IX+P_COUNT+1),A
        LD      (IX+P_CURSOR),A
        LD      (IX+P_CURSOR+1),A
        LD      (IX+P_SCROLL),A
        LD      (IX+P_SCROLL+1),A

        CALL    dir_init_fcb

        LD      DE,dir_dma
        LD      C,F_DMAOFF
        CALL    BDOS

        LD      DE,dir_fcb
        LD      C,F_SFIRST
        CALL    BDOS
        CP      0FFh
        JR      Z,.dl_done

.dl_store:
        ; A = 0..3 → raw 32-byte dir entry at dir_dma + A*32
        LD      L,A
        LD      H,0
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL                   ; *32
        LD      DE,dir_dma
        ADD     HL,DE

        ; Keep only primary extent (EX == 0 at entry+12)
        PUSH    HL
        LD      DE,12
        ADD     HL,DE
        LD      A,(HL)
        POP     HL
        OR      A
        JR      NZ,.dl_next

        INC     HL                      ; HL → 11-char name (skip user byte)
        CALL    dir_append_name
        JR      C,.dl_done              ; panel full

.dl_next:
        CALL    dir_restore_wild        ; keep EX/S1/S2, put '?' back in name
        LD      DE,dir_fcb
        LD      C,F_SNEXT
        CALL    BDOS
        CP      0FFh
        JR      NZ,.dl_store

.dl_done:
        POP     IY
        POP     HL
        POP     DE
        POP     BC
        POP     AF
        RET

;------------------------------------------------------------------------------
; dir_init_fcb — drive from IX, ambiguous name, zero EX..end
;------------------------------------------------------------------------------
dir_init_fcb:
        LD      HL,dir_fcb
        LD      B,FCB_SIZE
        XOR     A
.di_z:
        LD      (HL),A
        INC     HL
        DJNZ    .di_z

        LD      A,(IX+P_DRIVE)
        INC     A                       ; 1=A:
        LD      (dir_fcb+FCB_DR),A
        ; fall through to wild name

;------------------------------------------------------------------------------
; dir_restore_wild — F1..T3 := '?'; leaves DR and EX/S1/S2 alone
;------------------------------------------------------------------------------
dir_restore_wild:
        LD      HL,dir_fcb+FCB_F1
        LD      B,11
.drw:
        LD      (HL),'?'
        INC     HL
        DJNZ    .drw
        RET

;------------------------------------------------------------------------------
; dir_append_name — HL → 11-char name; IX = panel; CY if full
;------------------------------------------------------------------------------
dir_append_name:
        PUSH    BC
        PUSH    DE
        PUSH    HL

        LD      L,(IX+P_COUNT)
        LD      H,(IX+P_COUNT+1)
        LD      DE,MAX_FILES
        OR      A
        SBC     HL,DE
        JR      NC,.da_full

        LD      L,(IX+P_COUNT)
        LD      H,(IX+P_COUNT+1)
        ADD     HL,HL
        ADD     HL,HL
        LD      E,L
        LD      D,H
        ADD     HL,HL
        ADD     HL,DE                   ; count*12
        PUSH    IX
        POP     DE
        ADD     HL,DE
        LD      DE,P_NAMES
        ADD     HL,DE
        EX      DE,HL                   ; DE = dest

        POP     HL
        PUSH    HL
        LD      BC,NAME_LEN
        LDIR
        XOR     A
        LD      (DE),A

        LD      L,(IX+P_COUNT)
        LD      H,(IX+P_COUNT+1)
        INC     HL
        LD      (IX+P_COUNT),L
        LD      (IX+P_COUNT+1),H

        POP     HL
        POP     DE
        POP     BC
        OR      A
        RET

.da_full:
        POP     HL
        POP     DE
        POP     BC
        SCF
        RET

; Private DMA — avoid 0080h (command tail / shared default)
dir_dma:        DS      128
dir_fcb:        DS      FCB_SIZE
