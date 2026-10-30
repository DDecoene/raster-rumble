; music.asm - plays the next note of the tune on SID voice 2 every few frames

!zone update_music
update_music                        ; subroutine: every MUSIC_FRAMES frames play the next note on voice 2
        dec music_timer             ; one frame closer to the next note
        bne .done                   ; not yet
        lda #MUSIC_FRAMES           ; reload the timer
        sta music_timer             ; for the next note
        ldx music_step              ; which note?
        lda music_lo,x              ; its frequency, low byte
        sta SID_FREQ2L              ; set it
        lda music_hi,x              ; high byte
        sta SID_FREQ2H              ; set it
        lda #%01000000              ; pulse waveform, gate off (resets the envelope)
        sta SID_CTRL2               ; voice 2 stops
        lda #%01000001              ; pulse waveform, gate on
        sta SID_CTRL2               ; gate 0 to 1 plucks the note
        inx                         ; next note
        cpx #MUSIC_LEN              ; end of the tune?
        bne .store                  ; no
        ldx #0                      ; yes: loop back to the start
.store
        stx music_step              ; remember where we are
.done
        rts                         ; return to the caller
