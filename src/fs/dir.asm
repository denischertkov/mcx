;==============================================================================
; fs/dir.asm — load a CP/M directory into a panel name list
;
; Public entry points:
;   dir_load      IX → panel struct; fills drive's file names, resets cursor
;
; Each stored entry is NAME_LEN (11) bytes, FCB-style, attribute bit7 cleared.
;
; Multi-extent files (e.g. ZMC.COM with 161 records) produce several directory
; entries. We keep the first spelling of each name and ignore duplicates, rather
; than filtering on EX alone (EX=0 can be skipped by Search Next on some BDOS
; builds after wildcard restore, leaving only EX≠0 which a naive filter drops).
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

        ; The drive picker calls BIOS SELDSK directly. BDOS then treats the
        ; disk as changed and Search First returns nothing — the second panel
        ; on that same drive comes up empty. Log the drive out and back in.
        CALL    dir_reset_drv
        LD      A,(IX+P_DRIVE)
        CALL    bdos_set_drv

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

        ; Skip empty/deleted (user byte E5h)
        LD      A,(HL)
        CP      0E5h
        JR      Z,.dl_next

        INC     HL                      ; HL → 11-char name (+ attrs in bit7)
        CALL    dir_take_name           ; copy to dir_nb, strip attrs
        CALL    dir_find_name           ; CY set if already listed
        JR      C,.dl_next
        CALL    dir_append_buf          ; append dir_nb
        JR      C,.dl_done              ; panel full

.dl_next:
        CALL    dir_restore_wild        ; '?' back; keep EX/S1/S2
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
; dir_reset_drv — BDOS 37, one bit for (IX+P_DRIVE)
;------------------------------------------------------------------------------
dir_reset_drv:
        LD      A,(IX+P_DRIVE)
        LD      DE,1
        OR      A
        JR      Z,.drd_go
.drd_sh:
        SLA     E
        RL      D
        DEC     A
        JR      NZ,.drd_sh
.drd_go:
        LD      C,DRV_RESET
        CALL    BDOS
        RET

;------------------------------------------------------------------------------
; dir_init_fcb — zero FCB, set drive, ambiguous name
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
        INC     A
        LD      (dir_fcb+FCB_DR),A
        ; fall through

;------------------------------------------------------------------------------
; dir_restore_wild — F1..T3 := '?'; DR and EX/S1/S2 untouched
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
; dir_take_name — HL → 11 raw dir name; copy to dir_nb with bit7 cleared
;------------------------------------------------------------------------------
dir_take_name:
        PUSH    BC
        PUSH    DE
        LD      DE,dir_nb
        LD      B,11
.dtn:
        LD      A,(HL)
        AND     7Fh
        LD      (DE),A
        INC     HL
        INC     DE
        DJNZ    .dtn
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; dir_find_name — search panel for dir_nb; CY = already present
;------------------------------------------------------------------------------
dir_find_name:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      C,(IX+P_COUNT)
        LD      B,(IX+P_COUNT+1)
        LD      A,B
        OR      C
        JR      Z,.df_miss
        PUSH    IX
        POP     HL
        LD      DE,P_NAMES
        ADD     HL,DE                   ; HL → first stored name
.df_loop:
        PUSH    BC
        PUSH    HL
        LD      DE,dir_nb
        LD      B,11
.df_cmp:
        LD      A,(DE)
        CP      (HL)
        JR      NZ,.df_next
        INC     DE
        INC     HL
        DJNZ    .df_cmp
        ; match
        POP     HL
        POP     BC
        POP     HL
        POP     DE
        POP     BC
        SCF
        RET
.df_next:
        POP     HL
        LD      DE,DIR_ENTRY_SIZE
        ADD     HL,DE
        POP     BC
        DEC     BC
        LD      A,B
        OR      C
        JR      NZ,.df_loop
.df_miss:
        POP     HL
        POP     DE
        POP     BC
        OR      A                       ; NC = not found
        RET

;------------------------------------------------------------------------------
; dir_append_buf — append dir_nb to panel; CY if full
;------------------------------------------------------------------------------
dir_append_buf:
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
        ADD     HL,DE                   ; *12
        PUSH    IX
        POP     DE
        ADD     HL,DE
        LD      DE,P_NAMES
        ADD     HL,DE
        EX      DE,HL
        LD      HL,dir_nb
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

dir_nb:         DS      11
dir_dma:        DS      128
dir_fcb:        DS      FCB_SIZE
