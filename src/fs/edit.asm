;==============================================================================
; fs/edit.asm — F4 text editor for the file under the cursor
;
; Same buffer as the viewer. Arrows move, characters insert, Backspace and
; Del remove. F2 writes the file back. Esc leaves; if the text changed it
; asks whether to save. A file that did not fit in memory is not edited.
;==============================================================================

        INCLUDE "include/cpm.inc"
        INCLUDE "include/mcx.inc"
        INCLUDE "include/keys.inc"

;------------------------------------------------------------------------------
; edit_show — CY if the screen was not taken (caller shows view_msg)
;------------------------------------------------------------------------------
edit_show:
        XOR     A
        LD      (ed_dirty),A
        LD      (view_trunc),A
        LD      (view_mark),A
        CALL    file_take_current
        JP      C,.es_nofile
        CALL    view_load
        JP      C,.es_fail
        LD      A,(view_trunc)
        OR      A
        JP      NZ,.es_big

        LD      HL,0
        LD      (ed_cur),HL
        LD      (ed_top),HL
        XOR     A
        LD      (ed_pref),A
.es_page:
        CALL    ed_refresh
.es_key:
        CALL    keys_get
        CP      KEY_NONE
        JR      Z,.es_key
        CP      KEY_ESC
        JP      Z,ed_esc
        CP      KEY_F10
        JP      Z,ed_esc
        CP      KEY_F2
        JP      Z,ed_save_stay
        CP      KEY_LEFT
        JR      Z,.es_left
        CP      KEY_RIGHT
        JR      Z,.es_right
        CP      KEY_UP
        JR      Z,.es_up
        CP      KEY_DOWN
        JR      Z,.es_down
        CP      KEY_PGUP
        JR      Z,.es_pgup
        CP      KEY_PGDN
        JR      Z,.es_pgdn
        CP      KEY_BS
        JR      Z,.es_bs
        CP      7Fh
        JR      Z,.es_bs
        CP      KEY_DEL
        JR      Z,.es_del
        CP      KEY_ENTER
        JR      Z,.es_enter
        CP      ' '
        JR      C,.es_key
        CP      7Fh
        JR      NC,.es_key
        CALL    ed_insert
        JR      C,.es_full
        CALL    ed_set_pref
        JR      .es_page
.es_full:
        LD      A,CTRL_G
        CALL    bdos_conout
        JR      .es_page

.es_left:
        CALL    ed_left
        CALL    ed_set_pref
        JR      .es_page
.es_right:
        CALL    ed_right
        CALL    ed_set_pref
        JR      .es_page
.es_up:
        CALL    ed_up
        JR      .es_page
.es_down:
        CALL    ed_down
        JR      .es_page
.es_pgup:
        LD      B,VIEW_ROWS
.es_pul:
        PUSH    BC
        CALL    ed_up
        POP     BC
        DJNZ    .es_pul
        JR      .es_page
.es_pgdn:
        LD      B,VIEW_ROWS
.es_pdl:
        PUSH    BC
        CALL    ed_down
        POP     BC
        DJNZ    .es_pdl
        JP      .es_page
.es_bs:
        CALL    ed_backspace
        CALL    ed_set_pref
        JP      .es_page
.es_del:
        CALL    ed_delete
        CALL    ed_set_pref
        JP      .es_page
.es_enter:
        LD      A,0Dh
        CALL    ed_insert
        JR      C,.es_full
        LD      A,0Ah
        CALL    ed_insert
        JR      C,.es_full
        CALL    ed_set_pref
        JP      .es_page

.es_nofile:
        LD      DE,msg_nofile
        JR      .es_err
.es_fail:
        LD      DE,msg_view_open
        JR      .es_err
.es_big:
        LD      DE,msg_ed_big
.es_err:
        LD      (view_msg),DE
        SCF
        RET

;------------------------------------------------------------------------------
; ed_esc — leave, asking to save when the buffer changed
;------------------------------------------------------------------------------
ed_esc:
        LD      A,(ed_dirty)
        OR      A
        RET     Z
        LD      DE,msg_ed_save
        CALL    status_msg
        CALL    keys_get
        CALL    upcase
        CP      'Y'
        JP      Z,ed_save_exit
        CP      KEY_ENTER
        JP      Z,ed_save_exit
        CP      'N'
        RET     Z
        JP      edit_show.es_page

;------------------------------------------------------------------------------
; ed_save_stay / ed_save_exit
;------------------------------------------------------------------------------
ed_save_stay:
        CALL    ed_save
        JP      C,edit_show.es_key
        JP      edit_show.es_page

ed_save_exit:
        CALL    ed_save
        RET     NC
        JP      edit_show.es_key

;------------------------------------------------------------------------------
; ed_refresh — keep the cursor on screen and paint the page
;------------------------------------------------------------------------------
ed_refresh:
        CALL    ed_clamp
        CALL    ed_normalize
        LD      B,24
.er_fit:
        PUSH    BC
        CALL    ed_arm
        XOR     A
        LD      (view_draw),A
        CALL    view_walk
        LD      A,(view_hit)
        OR      A
        POP     BC
        JR      NZ,.er_draw
        CALL    ed_nudge
        DJNZ    .er_fit
.er_draw:
        CALL    ed_arm
        LD      A,1
        LD      (view_draw),A
        CALL    term_rev_off
        CALL    term_cls
        CALL    view_walk
        CALL    ed_footer
        RET

; point the viewer at ed_top / ed_cur for one measure or one paint
ed_arm:
        LD      HL,(ed_top)
        LD      (view_pos),HL
        LD      HL,(ed_cur)
        LD      (view_at),HL
        LD      A,VIEW_ROWS
        LD      (view_rows),A
        LD      A,1
        LD      (view_mark),A
        XOR     A
        LD      (view_hit),A
        RET

ed_nudge:
        LD      HL,(ed_cur)
        LD      DE,(ed_top)
        OR      A
        SBC     HL,DE
        JR      C,.en_above
        LD      HL,(ed_top)
        LD      (view_pos),HL
        LD      A,1
        LD      (view_rows),A
        XOR     A
        LD      (view_draw),A
        LD      (view_mark),A
        CALL    view_walk
        LD      HL,(view_next)
        LD      DE,(ed_top)
        OR      A
        SBC     HL,DE
        RET     Z
        LD      HL,(view_next)
        LD      (ed_top),HL
        RET
.en_above:
        CALL    ed_line_start
        LD      (ed_top),HL
        RET

;------------------------------------------------------------------------------
; movement
;------------------------------------------------------------------------------
ed_left:
        LD      HL,(ed_cur)
        LD      A,H
        OR      L
        RET     Z
        DEC     HL
        LD      (ed_cur),HL
        CALL    ed_normalize
        RET

ed_right:
        LD      HL,(ed_cur)
        LD      DE,(view_len)
        OR      A
        SBC     HL,DE
        RET     NC
        LD      HL,(ed_cur)
        CALL    ed_get
        LD      HL,(ed_cur)
        INC     HL
        LD      (ed_cur),HL
        CP      0Dh
        RET     NZ
        CALL    ed_get
        RET     C
        CP      0Ah
        RET     NZ
        LD      HL,(ed_cur)
        INC     HL
        LD      (ed_cur),HL
        RET

ed_up:
        CALL    ed_line_start
        LD      A,H
        OR      L
        RET     Z
        DEC     HL
        LD      A,H
        OR      L
        JR      Z,.eu0
        CALL    ed_get
        CP      0Ah
        JR      NZ,.eu_on
        DEC     HL
        LD      A,H
        OR      L
        JR      Z,.eu0
        CALL    ed_get
        CP      0Dh
        JR      Z,.eu_on
        INC     HL
.eu_on:
        LD      (ed_cur),HL
        CALL    ed_line_start
        CALL    ed_seek_pref
        RET
.eu0:
        LD      HL,0
        CALL    ed_seek_pref
        RET

ed_down:
        CALL    ed_next_line
        RET     C
        CALL    ed_seek_pref
        RET

;------------------------------------------------------------------------------
; ed_insert — insert A at the cursor. CY if the buffer is full.
;------------------------------------------------------------------------------
ed_insert:
        PUSH    AF
        CALL    ed_free_one
        JR      C,.ei_full
        CALL    ed_shift_up
        LD      HL,(view_buf)
        LD      DE,(ed_cur)
        ADD     HL,DE
        POP     AF
        LD      (HL),A
        LD      HL,(view_len)
        INC     HL
        LD      (view_len),HL
        LD      HL,(ed_cur)
        INC     HL
        LD      (ed_cur),HL
        LD      A,1
        LD      (ed_dirty),A
        OR      A
        RET
.ei_full:
        POP     AF
        SCF
        RET

ed_backspace:
        LD      HL,(ed_cur)
        LD      A,H
        OR      L
        RET     Z
        DEC     HL
        CALL    ed_get
        CP      0Ah
        JR      NZ,.eb_one
        LD      A,H
        OR      L
        JR      Z,.eb_one
        DEC     HL
        CALL    ed_get
        CP      0Dh
        JR      NZ,.eb_lf
        LD      (ed_cur),HL
        CALL    ed_delete
        CALL    ed_delete
        RET
.eb_lf:
        LD      HL,(ed_cur)
        DEC     HL
        LD      (ed_cur),HL
        CALL    ed_delete
        RET
.eb_one:
        LD      HL,(ed_cur)
        DEC     HL
        LD      (ed_cur),HL
        CALL    ed_delete
        RET

; delete the byte at the cursor
ed_delete:
        LD      HL,(ed_cur)
        LD      DE,(view_len)
        OR      A
        SBC     HL,DE
        RET     NC
        LD      HL,(view_len)
        LD      DE,(ed_cur)
        OR      A
        SBC     HL,DE
        DEC     HL
        LD      A,H
        OR      L
        JR      Z,.ed_last
        LD      B,H
        LD      C,L
        LD      HL,(view_buf)
        LD      DE,(ed_cur)
        ADD     HL,DE
        LD      D,H
        LD      E,L
        INC     HL
        LDIR
.ed_last:
        LD      HL,(view_len)
        DEC     HL
        LD      (view_len),HL
        LD      A,1
        LD      (ed_dirty),A
        RET

;------------------------------------------------------------------------------
ed_shift_up:
        LD      HL,(view_len)
        LD      DE,(ed_cur)
        OR      A
        SBC     HL,DE
        LD      A,H
        OR      L
        RET     Z
        LD      B,H
        LD      C,L
        LD      HL,(view_buf)
        LD      DE,(view_len)
        ADD     HL,DE
        DEC     HL
        LD      D,H
        LD      E,L
        INC     DE
        LDDR
        RET

; CY if fewer than 1 byte free
ed_free_one:
        LD      HL,(view_end)
        LD      DE,(view_buf)
        OR      A
        SBC     HL,DE
        LD      DE,(view_len)
        OR      A
        SBC     HL,DE
        RET     C
        LD      A,H
        OR      L
        RET     NZ
        SCF
        RET

;------------------------------------------------------------------------------
; line helpers — HL in/out is a buffer offset
;------------------------------------------------------------------------------
ed_get:
        PUSH    HL
        LD      DE,(view_len)
        OR      A
        SBC     HL,DE
        POP     HL
        JR      C,.eg_ok
        SCF
        RET
.eg_ok:
        PUSH    HL
        LD      DE,(view_buf)
        ADD     HL,DE
        LD      A,(HL)
        POP     HL
        OR      A
        RET

ed_line_start:
        LD      HL,(ed_cur)
.els:
        LD      A,H
        OR      L
        RET     Z
        DEC     HL
        CALL    ed_get
        CP      0Ah
        JR      Z,.els_nl
        CP      0Dh
        JR      Z,.els_nl
        JR      .els
.els_nl:
        INC     HL
        RET

; HL = start of the next line. CY if this is the last line.
ed_next_line:
        LD      HL,(ed_cur)
.enl:
        CALL    ed_get
        JR      C,.enl_no
        CP      0Dh
        JR      Z,.enl_cr
        CP      0Ah
        JR      Z,.enl_lf
        INC     HL
        JR      .enl
.enl_cr:
        INC     HL
        CALL    ed_get
        JR      C,.enl_ok
        CP      0Ah
        JR      NZ,.enl_ok
        INC     HL
        JR      .enl_ok
.enl_lf:
        INC     HL
.enl_ok:
        OR      A
        RET
.enl_no:
        SCF
        RET

ed_seek_pref:
        LD      A,(ed_pref)
        LD      B,A
.esp:
        LD      A,B
        OR      A
        JR      Z,.esp_at
        CALL    ed_get
        JR      C,.esp_at
        CP      0Dh
        JR      Z,.esp_at
        CP      0Ah
        JR      Z,.esp_at
        INC     HL
        DEC     B
        JR      .esp
.esp_at:
        LD      (ed_cur),HL
        RET

ed_set_pref:
        CALL    ed_line_start
        LD      B,0
.ep:
        PUSH    HL
        LD      DE,(ed_cur)
        OR      A
        SBC     HL,DE
        POP     HL
        JR      Z,.ep_st
        CALL    ed_get
        CP      0Dh
        JR      Z,.ep_st
        CP      0Ah
        JR      Z,.ep_st
        INC     HL
        INC     B
        JR      NZ,.ep
.ep_st:
        LD      A,B
        LD      (ed_pref),A
        RET

; keep ed_cur and ed_top inside the buffer
ed_clamp:
        LD      HL,(view_len)
        LD      (ed_lim),HL
        LD      HL,(ed_cur)
        CALL    ed_clamp_hl
        LD      (ed_cur),HL
        LD      HL,(ed_top)
        CALL    ed_clamp_hl
        LD      (ed_top),HL
        RET

ed_clamp_hl:
        LD      DE,(ed_lim)
        PUSH    HL
        OR      A
        SBC     HL,DE
        POP     HL
        RET     C
        LD      HL,(ed_lim)
        RET

ed_normalize:
        LD      HL,(ed_cur)
        LD      A,H
        OR      L
        RET     Z
        CALL    ed_get
        CP      0Ah
        RET     NZ
        DEC     HL
        CALL    ed_get
        CP      0Dh
        RET     NZ
        LD      (ed_cur),HL
        RET

;------------------------------------------------------------------------------
; ed_save — write the buffer, then replace the original.
;
; The text goes to MCXEDTMP.$$$ first. The original is removed only after
; that write closes. A full disk leaves the original in place.
; CY on failure. Clears ed_dirty on success.
;------------------------------------------------------------------------------
ed_save:
        CALL    active_ix
        CALL    dir_bios_sel
        LD      A,(file_src_drv)
        CALL    bdos_set_drv
        CALL    ed_same_tmp
        JR      Z,.esv_inplace
        CALL    ed_fcb_tmp
        LD      DE,view_fcb
        LD      C,F_DELETE
        CALL    BDOS
        CALL    ed_fcb_tmp
        JR      .esv_make
.esv_inplace:
        CALL    ed_fcb_src
        LD      DE,view_fcb
        LD      C,F_DELETE
        CALL    BDOS
        CALL    ed_fcb_src
.esv_make:
        LD      DE,view_fcb
        LD      C,F_MAKE
        CALL    BDOS
        CP      0FFh
        JP      Z,.esv_fail
        XOR     A
        LD      (view_fcb+FCB_CR),A
        LD      HL,(view_buf)
        LD      (ed_ptr),HL
        LD      HL,(view_len)
        LD      (ed_remain),HL
.esv_rec:
        LD      HL,ed_rec
        LD      B,128
        LD      A,1Ah
.esv_pad:
        LD      (HL),A
        INC     HL
        DJNZ    .esv_pad
        LD      HL,(ed_remain)
        LD      A,H
        OR      L
        JR      Z,.esv_flush
        LD      A,H
        OR      A
        LD      B,128
        JR      NZ,.esv_n
        LD      A,L
        CP      128
        JR      NC,.esv_n
        LD      B,A
.esv_n:
        LD      A,B
        LD      (ed_n),A
        LD      C,B
        LD      B,0
        LD      HL,(ed_ptr)
        LD      DE,ed_rec
        LDIR
        LD      (ed_ptr),HL
        LD      HL,(ed_remain)
        LD      A,(ed_n)
        LD      E,A
        LD      D,0
        OR      A
        SBC     HL,DE
        LD      (ed_remain),HL
.esv_flush:
        LD      DE,ed_rec
        LD      C,F_DMAOFF
        CALL    BDOS
        LD      DE,view_fcb
        LD      C,F_WRITE
        CALL    BDOS
        OR      A
        JR      NZ,.esv_full
        LD      HL,(ed_remain)
        LD      A,H
        OR      L
        JR      NZ,.esv_rec
        LD      DE,view_fcb
        LD      C,F_CLOSE
        CALL    BDOS
        CP      0FFh
        JR      Z,.esv_drop
        CALL    ed_same_tmp
        JR      Z,.esv_ok
        CALL    ed_fcb_src
        LD      DE,view_fcb
        LD      C,F_DELETE
        CALL    BDOS
        CP      0FFh
        JR      Z,.esv_keep
        CALL    ed_fcb_tmp
        LD      HL,file_src_name
        LD      DE,view_fcb+17
        LD      BC,11
        LDIR
        XOR     A
        LD      (view_fcb+16),A
        LD      DE,view_fcb
        LD      C,F_RENAME
        CALL    BDOS
        CP      0FFh
        JR      Z,.esv_as_tmp
.esv_ok:
        XOR     A
        LD      (ed_dirty),A
        RET
.esv_full:
        LD      DE,view_fcb
        LD      C,F_CLOSE
        CALL    BDOS
.esv_drop:
        CALL    ed_same_tmp
        JR      Z,.esv_fail
        CALL    ed_fcb_tmp
        LD      DE,view_fcb
        LD      C,F_DELETE
        CALL    BDOS
        JR      .esv_fail
.esv_keep:
        CALL    ed_fcb_tmp
        LD      DE,view_fcb
        LD      C,F_DELETE
        CALL    BDOS
        JR      .esv_fail
.esv_as_tmp:
        LD      HL,ed_tmp_name
        LD      DE,file_src_name
        LD      BC,11
        LDIR
        CALL    active_ix
        CALL    dir_load
        XOR     A
        LD      (ed_dirty),A
        LD      DE,msg_ed_tmp
        JR      .esv_tell
.esv_fail:
        LD      DE,msg_ed_fail
.esv_tell:
        CALL    status_msg
        CALL    keys_get
        SCF
        RET

; Z if the file being edited is the temp name
ed_same_tmp:
        LD      HL,file_src_name
        LD      DE,ed_tmp_name
        LD      B,11
.est:
        LD      A,(DE)
        CP      (HL)
        RET     NZ
        INC     HL
        INC     DE
        DJNZ    .est
        RET

ed_fcb_src:
        LD      A,(file_src_drv)
        LD      C,A
        LD      HL,file_src_name
        LD      DE,view_fcb
        JP      file_set_fcb

ed_fcb_tmp:
        LD      A,(file_src_drv)
        LD      C,A
        LD      HL,ed_tmp_name
        LD      DE,view_fcb
        JP      file_set_fcb

ed_footer:
        LD      HL,file_src_name
        LD      DE,view_name
        CALL    panel_fmt_name
        LD      B,23
        LD      C,1
        CALL    term_cup
        LD      DE,msg_edit
        CALL    bdos_print
        LD      HL,view_name
        CALL    term_puts
        LD      A,(ed_dirty)
        OR      A
        JR      Z,.ef_bar
        LD      DE,msg_ed_mod
        CALL    bdos_print
.ef_bar:
        LD      B,24
        LD      C,1
        CALL    term_cup
        CALL    term_rev_on
        LD      DE,msg_ed_keys
        CALL    bdos_print
        LD      B,40
.ef_pad:
        LD      A,' '
        CALL    bdos_conout
        DJNZ    .ef_pad
        CALL    term_rev_off
        RET

ed_cur:         DW      0
ed_top:         DW      0
ed_pref:        DB      0
ed_dirty:       DB      0
ed_ptr:         DW      0
ed_remain:      DW      0
ed_n:           DB      0
ed_lim:         DW      0
ed_rec:         DS      128
ed_tmp_name:    DB      "MCXEDTMP$$$"

msg_edit:       DB      "Edit $"
msg_ed_mod:     DB      " *$"
msg_ed_keys:    DB      " F2 save   Esc exit   Arrows   PgUp/PgDn$"
msg_ed_save:    DB      "Save changes? Y/N $"
msg_ed_fail:    DB      "Save failed — key$"
msg_ed_tmp:     DB      "Saved as MCXEDTMP.$$$ — key$"
msg_ed_big:     DB      "File too big to edit$"
