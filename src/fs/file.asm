;==============================================================================
; fs/file.asm — copy and rename the file under the cursor
;
;   file_copy     F5. Same name onto the other panel's drive.
;                 Same drive is refused (that would be a rename — use F6).
;   file_rename   F6. New name on the active panel's drive.
;
; On return (file_msg) is a $-string for the status line. (file_dirty) ≠ 0
; means a panel was reloaded and the caller should redraw the screen.
;==============================================================================

        INCLUDE "include/cpm.inc"
        INCLUDE "include/mcx.inc"
        INCLUDE "include/keys.inc"

;------------------------------------------------------------------------------
; file_copy
;------------------------------------------------------------------------------
file_copy:
        XOR     A
        LD      (file_dirty),A
        CALL    file_take_current
        JP      C,.fc_nofile

        CALL    other_ix
        LD      A,(IX+P_DRIVE)
        LD      (file_dst_drv),A

        LD      A,(file_src_drv)
        LD      HL,file_dst_drv
        CP      (HL)
        JR      Z,.fc_samedrv

.fc_same:
        LD      HL,file_src_name
        LD      DE,file_dst_name
        LD      BC,11
        LDIR

.fc_exists:
        LD      A,(file_dst_drv)
        LD      C,A
        LD      HL,file_dst_name
        CALL    file_exists
        JR      C,.fc_go
        LD      DE,msg_overwrite
        CALL    status_msg
        CALL    keys_get
        CALL    upcase
        CP      'Y'
        JR      Z,.fc_go
        CP      KEY_ENTER
        JR      Z,.fc_go
        JR      .fc_cancel

.fc_go:
        LD      DE,msg_copying
        CALL    status_msg
        CALL    file_do_copy
        PUSH    AF
        LD      A,(file_dirty)
        OR      A
        CALL    NZ,file_reload_dest
        POP     AF
        RET     C
        LD      DE,msg_copied
        LD      (file_msg),DE
        OR      A
        RET

.fc_samedrv:
        LD      DE,msg_samedrv
        JR      .fc_ret
.fc_nofile:
        LD      DE,msg_nofile
        JR      .fc_ret
.fc_cancel:
        LD      DE,msg_cancel
        JR      .fc_ret
.fc_bad:
        LD      DE,msg_badname
        JR      .fc_ret
.fc_itself:
        LD      DE,msg_itself
.fc_ret:
        LD      (file_msg),DE
        RET

;------------------------------------------------------------------------------
; file_rename
;------------------------------------------------------------------------------
file_rename:
        XOR     A
        LD      (file_dirty),A
        CALL    file_take_current
        JP      C,.fr_nofile

        LD      HL,file_src_name
        LD      DE,file_disp
        CALL    panel_fmt_name
        LD      DE,msg_rename
        LD      HL,file_disp
        CALL    status_edit_name
        JR      C,.fr_cancel
        LD      HL,name_edit
        LD      DE,file_dst_name
        CALL    file_parse_name
        JR      C,.fr_bad
        CALL    file_names_eq
        JR      Z,.fr_same

        LD      A,(file_src_drv)
        LD      C,A
        LD      HL,file_dst_name
        CALL    file_exists
        JR      NC,.fr_exists

        LD      A,(file_src_drv)
        LD      C,A
        LD      HL,file_src_name
        LD      DE,fcb_ren
        CALL    file_set_fcb
        LD      HL,file_dst_name
        LD      DE,fcb_ren+17
        LD      BC,11
        LDIR
        LD      DE,fcb_ren
        LD      C,F_RENAME
        CALL    BDOS
        CP      0FFh
        JR      Z,.fr_fail

        LD      A,1
        LD      (file_dirty),A
        CALL    active_ix
        CALL    dir_load
        LD      DE,msg_renamed
        LD      (file_msg),DE
        RET

.fr_nofile:
        LD      DE,msg_nofile
        JR      .fr_ret
.fr_cancel:
        LD      DE,msg_cancel
        JR      .fr_ret
.fr_bad:
        LD      DE,msg_badname
        JR      .fr_ret
.fr_same:
        LD      DE,msg_samename
        JR      .fr_ret
.fr_exists:
        LD      DE,msg_exists
        JR      .fr_ret
.fr_fail:
        LD      DE,msg_renamefail
.fr_ret:
        LD      (file_msg),DE
        RET

;------------------------------------------------------------------------------
; file_take_current — active panel → file_src_name / file_src_drv
; CY if the panel is empty
;------------------------------------------------------------------------------
file_take_current:
        CALL    active_ix
        LD      A,(IX+P_COUNT)
        OR      (IX+P_COUNT+1)
        SCF
        RET     Z
        LD      A,(IX+P_DRIVE)
        LD      (file_src_drv),A
        CALL    file_cursor_name
        LD      DE,file_src_name
        LD      BC,11
        LDIR
        OR      A
        RET

;------------------------------------------------------------------------------
; file_cursor_name — IX = panel, HL → 11-byte name at the cursor
;------------------------------------------------------------------------------
file_cursor_name:
        LD      L,(IX+P_CURSOR)
        LD      H,(IX+P_CURSOR+1)
        ADD     HL,HL
        ADD     HL,HL
        LD      E,L
        LD      D,H
        ADD     HL,HL
        ADD     HL,DE
        PUSH    IX
        POP     DE
        ADD     HL,DE
        LD      DE,P_NAMES
        ADD     HL,DE
        RET

;------------------------------------------------------------------------------
; file_do_copy — copy file_src_* to file_dst_*. CY on failure, (file_msg) set.
; Sets file_dirty once the destination may have changed.
;------------------------------------------------------------------------------
file_do_copy:
        LD      A,(file_src_drv)
        LD      C,A
        LD      HL,file_src_name
        LD      DE,fcb_src
        CALL    file_set_fcb
        LD      A,(file_dst_drv)
        LD      C,A
        LD      HL,file_dst_name
        LD      DE,fcb_dst
        CALL    file_set_fcb

        LD      DE,file_dma
        LD      C,F_DMAOFF
        CALL    BDOS
        LD      DE,fcb_src
        LD      C,F_OPEN
        CALL    BDOS
        CP      0FFh
        JR      Z,.fd_fail
        XOR     A
        LD      (fcb_src+FCB_CR),A

        LD      A,1
        LD      (file_dirty),A
        LD      DE,fcb_dst
        LD      C,F_DELETE
        CALL    BDOS
        LD      DE,fcb_dst
        LD      C,F_MAKE
        CALL    BDOS
        CP      0FFh
        JR      Z,.fd_fail
        XOR     A
        LD      (fcb_dst+FCB_CR),A

.fd_loop:
        LD      DE,file_dma
        LD      C,F_DMAOFF
        CALL    BDOS
        LD      DE,fcb_src
        LD      C,F_READ
        CALL    BDOS
        OR      A
        JR      Z,.fd_write
        CP      1
        JR      Z,.fd_eof
        JR      .fd_readerr
.fd_write:
        LD      DE,fcb_dst
        LD      C,F_WRITE
        CALL    BDOS
        OR      A
        JR      Z,.fd_loop
        JR      .fd_full

.fd_eof:
        LD      DE,fcb_dst
        LD      C,F_CLOSE
        CALL    BDOS
        LD      DE,fcb_src
        LD      C,F_CLOSE
        CALL    BDOS
        OR      A
        RET

.fd_full:
        CALL    file_abort_dest
        LD      DE,msg_diskfull
        LD      (file_msg),DE
        SCF
        RET
.fd_readerr:
        CALL    file_abort_dest
.fd_fail:
        LD      DE,msg_copyfail
        LD      (file_msg),DE
        SCF
        RET

; close and delete a partial destination
file_abort_dest:
        LD      DE,fcb_dst
        LD      C,F_CLOSE
        CALL    BDOS
        LD      DE,fcb_dst
        LD      C,F_DELETE
        CALL    BDOS
        LD      DE,fcb_src
        LD      C,F_CLOSE
        CALL    BDOS
        RET

;------------------------------------------------------------------------------
; file_reload_dest — destination panel, plus the source panel if same drive
;------------------------------------------------------------------------------
file_reload_dest:
        CALL    other_ix
        CALL    dir_load
        LD      A,(file_src_drv)
        LD      HL,file_dst_drv
        CP      (HL)
        RET     NZ
        CALL    active_ix
        CALL    dir_load
        RET

;------------------------------------------------------------------------------
; file_set_fcb — C = drive 0..15, HL → 11-byte name, DE → FCB
;------------------------------------------------------------------------------
file_set_fcb:
        PUSH    HL
        PUSH    DE
        LD      H,D
        LD      L,E
        LD      B,FCB_SIZE
        XOR     A
.fs_z:
        LD      (HL),A
        INC     HL
        DJNZ    .fs_z
        POP     DE
        POP     HL
        LD      A,C
        INC     A
        LD      (DE),A
        INC     DE
        LD      BC,11
        LDIR
        RET

;------------------------------------------------------------------------------
; file_exists — C = drive, HL → 11-byte name. CY if absent.
;------------------------------------------------------------------------------
file_exists:
        LD      DE,fcb_probe
        CALL    file_set_fcb
        LD      DE,file_dma
        LD      C,F_DMAOFF
        CALL    BDOS
        LD      DE,fcb_probe
        LD      C,F_SFIRST
        CALL    BDOS
        CP      0FFh
        SCF
        RET     Z
        OR      A
        RET

;------------------------------------------------------------------------------
; file_names_eq — Z if file_src_name equals file_dst_name
;------------------------------------------------------------------------------
file_names_eq:
        LD      HL,file_src_name
        LD      DE,file_dst_name
        LD      B,11
.fnq:
        LD      A,(DE)
        CP      (HL)
        RET     NZ
        INC     HL
        INC     DE
        DJNZ    .fnq
        XOR     A
        RET

;------------------------------------------------------------------------------
; file_parse_name — HL zstring "NAME.EXT" → DE 11-byte FCB name. CY if bad.
;------------------------------------------------------------------------------
file_parse_name:
        LD      (fp_src),HL
        LD      (fp_dst),DE
        LD      H,D
        LD      L,E
        LD      B,11
        LD      A,' '
.fp_sp:
        LD      (HL),A
        INC     HL
        DJNZ    .fp_sp
        LD      HL,(fp_src)
        LD      DE,(fp_dst)
        LD      B,0
.fp_nm:
        LD      A,(HL)
        OR      A
        JR      Z,.fp_done
        CP      '.'
        JR      Z,.fp_dot
        CALL    file_ok_char
        RET     C
        LD      A,B
        CP      8
        JR      NC,.fp_bad
        LD      A,(HL)
        CALL    upcase
        LD      (DE),A
        INC     HL
        INC     DE
        INC     B
        JR      .fp_nm
.fp_dot:
        LD      A,B
        OR      A
        JR      Z,.fp_bad
        INC     HL
        LD      DE,(fp_dst)
        LD      A,E
        ADD     A,8
        LD      E,A
        JR      NC,.fp_ext
        INC     D
.fp_ext:
        LD      B,0
.fp_ex:
        LD      A,(HL)
        OR      A
        JR      Z,.fp_done
        CP      '.'
        JR      Z,.fp_bad
        CALL    file_ok_char
        RET     C
        LD      A,B
        CP      3
        JR      NC,.fp_bad
        LD      A,(HL)
        CALL    upcase
        LD      (DE),A
        INC     HL
        INC     DE
        INC     B
        JR      .fp_ex
.fp_done:
        LD      HL,(fp_dst)
        LD      A,(HL)
        CP      ' '
        JR      Z,.fp_bad
        OR      A
        RET
.fp_bad:
        SCF
        RET

; A = character. CY if not a letter or digit. Letters are uppercased in A.
file_ok_char:
        CALL    upcase
        CP      '0'
        JR      C,.fo_bad
        CP      '9'+1
        JR      C,.fo_ok
        CP      'A'
        JR      C,.fo_bad
        CP      'Z'+1
        JR      NC,.fo_bad
.fo_ok:
        OR      A
        RET
.fo_bad:
        SCF
        RET

file_src_drv:   DB      0
file_dst_drv:   DB      0
file_dirty:     DB      0
file_msg:       DW      msg_cancel
file_src_name:  DS      11
file_dst_name:  DS      11
file_disp:      DS      14
fp_src:         DW      0
fp_dst:         DW      0
fcb_src:        DS      FCB_SIZE
fcb_dst:        DS      FCB_SIZE
fcb_ren:        DS      FCB_SIZE
fcb_probe:      DS      FCB_SIZE
file_dma:       DS      128

msg_samedrv:    DB      "Same drive — pick another on the other panel, or F6$"
msg_rename:     DB      "Rename to: $"
msg_overwrite:  DB      "Overwrite? Y/N $"
msg_copying:    DB      "Copying...$"
msg_copied:     DB      "Copied$"
msg_cancel:     DB      "Cancelled$"
msg_nofile:     DB      "No file$"
msg_itself:     DB      "Cannot copy onto itself$"
msg_badname:    DB      "Bad name$"
msg_copyfail:   DB      "Copy failed$"
msg_diskfull:   DB      "Disk full$"
msg_renamed:    DB      "Renamed$"
msg_renamefail: DB      "Rename failed$"
msg_exists:     DB      "File exists$"
msg_samename:   DB      "Same name$"
