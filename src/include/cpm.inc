;==============================================================================
; include/cpm.inc — CP/M 2.2 constants shared by MCX modules
;
; Defines BDOS entry, common BDOS function numbers, FCB/DMA layout, and
; console control characters. Included by programs and library modules.
;==============================================================================

        IFNDEF  CPM_INC
        DEFINE  CPM_INC

; --- CP/M zero page ----------------------------------------------------------
BDOS            EQU     0005h           ; BDOS entry point
FCB1            EQU     005Ch           ; default FCB (from CCP command tail)
DMA_DEFAULT     EQU     0080h           ; default DMA / command tail buffer
TPA_START       EQU     0100h           ; .COM load address
WBOOT           EQU     0000h           ; warm boot vector

; --- BDOS function numbers (CP/M 2.2) ----------------------------------------
C_READ          EQU     1               ; console input (waits)
C_WRITE         EQU     2               ; console output
C_RAWIO         EQU     6               ; direct console I/O (E=FFh = input)
C_WRITESTR      EQU     9               ; print $-terminated string
C_READSTR       EQU     10              ; buffered console input
C_STAT          EQU     11              ; console status
C_GETVER        EQU     12              ; get version
DRV_ALLRESET    EQU     13              ; reset disk system
DRV_SET         EQU     14              ; select disk
F_OPEN          EQU     15
F_CLOSE         EQU     16
F_SFIRST        EQU     17              ; search first
F_SNEXT         EQU     18              ; search next
F_DELETE        EQU     19
F_READ          EQU     20              ; sequential read
F_WRITE         EQU     21              ; sequential write
F_MAKE          EQU     22
F_RENAME        EQU     23
DRV_GET         EQU     25              ; get current disk (0=A)
DRV_RESET       EQU     37              ; reset drives in DE bit vector
F_DMAOFF        EQU     26              ; set DMA address
F_USERNUM       EQU     32              ; get/set user number
F_SYSRESET      EQU     0               ; system reset (warm boot)

; --- FCB offsets -------------------------------------------------------------
FCB_DR          EQU     0               ; drive (0=default, 1=A, ...)
FCB_F1          EQU     1               ; filename (8 bytes)
FCB_T1          EQU     9               ; filetype (3 bytes)
FCB_EX          EQU     12              ; extent
FCB_S1          EQU     13
FCB_S2          EQU     14
FCB_RC          EQU     15              ; record count
FCB_AL          EQU     16              ; allocation (16 bytes)
FCB_CR          EQU     32              ; current record
FCB_R0          EQU     33              ; random record
FCB_SIZE        EQU     36

; --- Control characters ------------------------------------------------------
CTRL_C          EQU     03h
CTRL_G          EQU     07h
BS              EQU     08h
LF              EQU     0Ah
CR              EQU     0Dh
ESC             EQU     1Bh
DEL             EQU     7Fh

        ENDIF
