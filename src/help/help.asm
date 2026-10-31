;==============================================================================
; help/help.asm — F1 help overlay
;
; Public entry points:
;   help_show     clear, print help text, wait for key, return
;==============================================================================

        INCLUDE "include/cpm.inc"

;------------------------------------------------------------------------------
; help_show
;------------------------------------------------------------------------------
help_show:
        PUSH    DE
        CALL    term_cls
        LD      DE,help_text
        CALL    bdos_print
        CALL    keys_get
        POP     DE
        RET

help_text:
        DB      "MCX - dual-panel file manager for CP/M 2.2",CR,LF
        DB      CR,LF
        DB      "Usage: MCX [d:] [d:]   start drives for L/R panels",CR,LF
        DB      CR,LF
        DB      "Keys:",CR,LF
        DB      "  Arrows     move cursor in active panel",CR,LF
        DB      "  Tab        switch active panel",CR,LF
        DB      "  Enter      run .COM (iter 3)",CR,LF
        DB      "  F1         this help",CR,LF
        DB      "  F3         view file (iter 3)",CR,LF
        DB      "  F4         edit file (iter 3)",CR,LF
        DB      "  F5         copy to the other panel's drive",CR,LF
        DB      "  F6         rename in this panel",CR,LF
        DB      "  F10        quit to CP/M",CR,LF
        DB      "  Ctrl-L     LEFT panel: drive menu",CR,LF
        DB      "  Ctrl-R     RIGHT panel: drive menu",CR,LF
        DB      CR,LF
        DB      "Drive menu: arrows/Enter, or letter A-P, Esc=cancel.",CR,LF
        DB      "Alt-F1/F2 are captured by the Linux host.",CR,LF
        DB      CR,LF
        DB      "Press any key to return...$"
