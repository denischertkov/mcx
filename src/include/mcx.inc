;==============================================================================
; include/mcx.inc — MCX global layout constants (screen, panels, limits)
;==============================================================================

        IFNDEF  MCX_INC
        DEFINE  MCX_INC

SCR_COLS        EQU     80
SCR_ROWS        EQU     24

PANEL_ROWS      EQU     20              ; file list rows (screen rows 2..21)
PANEL_WIDTH     EQU     38              ; left list, columns 2..39
PANEL_WIDTH_R   EQU     39              ; right list, columns 41..79
PANEL_LEFT_COL  EQU     2
PANEL_RIGHT_COL EQU     41
PANEL_GAP_COL   EQU     40              ; vertical bar between panels
FRAME_BOTTOM    EQU     22              ; bottom edge; status stays on 23

MAX_FILES       EQU     128             ; per panel
NAME_LEN        EQU     11              ; 8 + 3, FCB-style, no dot
DIR_ENTRY_SIZE  EQU     12              ; NAME_LEN + 1 pad/flags

; Panel struct offsets
P_DRIVE         EQU     0               ; byte, 0=A
P_COUNT         EQU     1               ; word
P_CURSOR        EQU     3               ; word
P_SCROLL        EQU     5               ; word
P_NAMES         EQU     7               ; DIR_ENTRY_SIZE * MAX_FILES
PANEL_BYTES     EQU     P_NAMES + (DIR_ENTRY_SIZE * MAX_FILES)

        ENDIF
