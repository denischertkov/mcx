;==============================================================================
; fs/dir.asm — load a CP/M directory into a panel name list
;
; Public entry points:
;   dir_load      IX → panel struct; fills drive's file names, resets cursor
;
; Each entry is NAME_LEN (11) bytes: 8-char name + 3-char type, space-padded,
; matching FCB layout (no dot). Directory USER files only (non-deleted).
;==============================================================================

        INCLUDE "include/cpm.inc"
        INCLUDE "include/mcx.inc"

;------------------------------------------------------------------------------
; dir_load — IX = panel; uses dir_fcb + DMA_DEFAULT
;------------------------------------------------------------------------------
dir_load:
        PUSH    AF
        PUSH    BC
        PUSH    DE
        PUSH    HL
        PUSH    IY

        ; reset count / cursor / scroll
        XOR     A
        LD      (IX+P_COUNT),A
        LD      (IX+P_COUNT+1),A
        LD      (IX+P_CURSOR),A
        LD      (IX+P_CURSOR+1),A
        LD      (IX+P_SCROLL),A
        LD      (IX+P_SCROLL+1),A

        ; build FCB: drive+1, ????????.???
        LD      A,(IX+P_DRIVE)
        INC     A                       ; FCB drive: 1=A
        LD      (dir_fcb+FCB_DR),A
        LD      HL,dir_fcb+FCB_F1
        LD      B,11
.dl_wild:
        LD      (HL),'?'
        INC     HL
        DJNZ    .dl_wild
        ; Clear EX..CR so search state starts clean
        LD      HL,dir_fcb+FCB_EX
        LD      B,FCB_SIZE-FCB_EX
        XOR     A
.dl_zfcb:
        LD      (HL),A
        INC     HL
        DJNZ    .dl_zfcb

        LD      DE,DMA_DEFAULT
        CALL    bdos_set_dma

        LD      DE,dir_fcb
        CALL    bdos_sfirst
        CP      0FFh
        JR      Z,.dl_done

.dl_store:
        ; A = 0..3 → entry at DMA + A*32
        PUSH    AF
        LD      L,A
        LD      H,0
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL
        ADD     HL,HL                   ; *32
        LD      DE,DMA_DEFAULT
        ADD     HL,DE
        ; HL → dir entry; name at +1, EX at +12. Keep only primary extents.
        INC     HL                      ; HL → 11-char name
        PUSH    HL
        LD      DE,11
        ADD     HL,DE                   ; HL → EX
        LD      A,(HL)
        POP     HL
        OR      A
        JR      NZ,.dl_skip
        CALL    dir_append_name
        POP     AF
        JR      C,.dl_done
        JR      .dl_next
.dl_skip:
        POP     AF
.dl_next:
        ; BDOS func 18 requires DE → same FCB as search first
        LD      DE,dir_fcb
        CALL    bdos_snext
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
; dir_append_name — HL → 11-char FCB name; IX = panel
; CY set if panel is full
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
        JR      NC,.da_full             ; count >= MAX

        ; dest = IX+P_NAMES + count*DIR_ENTRY_SIZE
        LD      L,(IX+P_COUNT)
        LD      H,(IX+P_COUNT+1)
        ; *12 = *8 + *4
        ADD     HL,HL
        ADD     HL,HL
        LD      E,L
        LD      D,H
        ADD     HL,HL                   ; *8
        ADD     HL,DE                   ; *12
        PUSH    IX
        POP     DE
        ADD     HL,DE
        LD      DE,P_NAMES
        ADD     HL,DE
        EX      DE,HL                   ; DE = dest

        POP     HL                      ; source name
        PUSH    HL
        LD      BC,NAME_LEN
        LDIR
        XOR     A
        LD      (DE),A                  ; pad byte

        ; count++
        LD      L,(IX+P_COUNT)
        LD      H,(IX+P_COUNT+1)
        INC     HL
        LD      (IX+P_COUNT),L
        LD      (IX+P_COUNT+1),H

        POP     HL
        POP     DE
        POP     BC
        OR      A                       ; NC = ok
        RET

.da_full:
        POP     HL
        POP     DE
        POP     BC
        SCF
        RET

; Search FCB (36 bytes)
dir_fcb:        DS      FCB_SIZE
