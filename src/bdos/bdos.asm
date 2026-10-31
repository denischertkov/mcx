;==============================================================================
; bdos/bdos.asm — thin wrappers around CP/M 2.2 BDOS (CALL 5)
;
; Public entry points:
;   bdos_call     C=fn, DE=param → returns as BDOS (A / HL)
;   bdos_conout   A = character to print
;   bdos_print    DE → $-terminated string (func 9)
;   bdos_const    console status → A=0 if empty, A≠0 if ready
;   bdos_conin    wait for character → A
;   bdos_conin_nb non-blocking raw input (func 6) → A=0 if none
;   bdos_exit     warm boot back to CCP
;   bdos_get_drv  current drive → A (0=A)
;   bdos_set_drv  A = drive (0=A)
;   bdos_set_dma  DE = DMA address
;   bdos_sfirst   DE = FCB → A = 0..3 code or 0FFh
;   bdos_snext    DE → same FCB as sfirst → A = 0..3 or 0FFh
;==============================================================================

        INCLUDE "include/cpm.inc"

;------------------------------------------------------------------------------
; bdos_call — invoke BDOS with C=function, DE=parameter
;------------------------------------------------------------------------------
bdos_call:
        JP      BDOS

;------------------------------------------------------------------------------
; bdos_conout — write character in A to console
;------------------------------------------------------------------------------
bdos_conout:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      E,A
        LD      C,C_WRITE
        CALL    BDOS
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; bdos_print — print $-terminated string at DE
;------------------------------------------------------------------------------
bdos_print:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      C,C_WRITESTR
        CALL    BDOS
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; bdos_const — console status (func 11); A≠0 if a character is waiting
;------------------------------------------------------------------------------
bdos_const:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      C,C_STAT
        CALL    BDOS
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; bdos_conin — blocking console input (func 1) → A = character
;------------------------------------------------------------------------------
bdos_conin:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      C,C_READ
        CALL    BDOS
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; bdos_conin_nb — non-blocking raw console input (func 6, E=FFh)
; Returns A=0 if no character available, else the character.
; Does not echo.
;------------------------------------------------------------------------------
bdos_conin_nb:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      E,0FFh
        LD      C,C_RAWIO
        CALL    BDOS
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; bdos_exit — return to CCP via warm boot
;------------------------------------------------------------------------------
bdos_exit:
        LD      C,F_SYSRESET
        JP      BDOS

;------------------------------------------------------------------------------
; bdos_get_drv — get current default drive → A (0=A:)
;------------------------------------------------------------------------------
bdos_get_drv:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      C,DRV_GET
        CALL    BDOS
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; bdos_set_drv — set current default drive; A = 0=A:
;------------------------------------------------------------------------------
bdos_set_drv:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      E,A
        LD      C,DRV_SET
        CALL    BDOS
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; bdos_set_dma — set DMA address from DE
;------------------------------------------------------------------------------
bdos_set_dma:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      C,F_DMAOFF
        CALL    BDOS
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; bdos_sfirst — search first; DE → FCB; A=0..3 directory code or 0FFh=none
;------------------------------------------------------------------------------
bdos_sfirst:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      C,F_SFIRST
        CALL    BDOS
        POP     HL
        POP     DE
        POP     BC
        RET

;------------------------------------------------------------------------------
; bdos_snext — search next; DE → FCB (same as sfirst); A=0..3 or 0FFh=none
;------------------------------------------------------------------------------
bdos_snext:
        PUSH    BC
        PUSH    DE
        PUSH    HL
        LD      C,F_SNEXT
        CALL    BDOS
        POP     HL
        POP     DE
        POP     BC
        RET
