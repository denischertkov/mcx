;==============================================================================
; include/keys.inc — logical key codes returned by keys_get
;
; ASCII 00..7F returned as-is (Tab, CR, BS, Ctrl-L/R, printable, ...).
; Special keys use 80h+.
;==============================================================================

        IFNDEF  KEYS_INC
        DEFINE  KEYS_INC

KEY_NONE        EQU     00h

; --- arrows ------------------------------------------------------------------
KEY_UP          EQU     80h
KEY_DOWN        EQU     81h
KEY_RIGHT       EQU     82h
KEY_LEFT        EQU     83h

; --- editing -----------------------------------------------------------------
KEY_DEL         EQU     84h
KEY_PGUP        EQU     85h
KEY_PGDN        EQU     86h

; --- function keys -----------------------------------------------------------
KEY_F1          EQU     90h
KEY_F2          EQU     91h
KEY_F3          EQU     92h
KEY_F4          EQU     93h
KEY_F5          EQU     94h
KEY_F6          EQU     95h
KEY_F7          EQU     96h
KEY_F8          EQU     97h
KEY_F9          EQU     98h
KEY_F10         EQU     99h

; --- common ASCII (for readability at call sites) ----------------------------
KEY_TAB         EQU     09h
KEY_ENTER       EQU     0Dh
KEY_BS          EQU     08h
KEY_CTRL_L      EQU     0Ch
KEY_CTRL_R      EQU     12h
KEY_CTRL_C      EQU     03h
KEY_ESC         EQU     1Bh

        ENDIF
