; music.asm - the tune: the arpeggio on SID voice 2 (with a moving pulse width and a sweeping filter, for a synth sound)
; a sawtooth bass on voice 1 that follows the chords, and drums on voice 3

!zone update_music
update_music                        ; subroutine: every frame the synth sweeps, every MUSIC_FRAMES frames the next note
        lda frame_count             ; the pulse width: a slow sine, so the sound keeps changing
        asl                         ; times 2 ...
        clc                         ; clear carry before adding
        adc frame_count             ; ... plus 1 = times 3 steps per frame
        tax                         ; X = sine index
        lda sine,x                  ; 0 to 63
        lsr                         ; divide by 8: 0 to 7 ...
        lsr
        lsr
        clc                         ; clear carry before adding
        adc #4                      ; ... plus 4: 4 to 11, never so thin or wide that the voice goes silent
        sta SID_PW2H                ; pulse width high nibble
        ldx frame_count             ; the filter: one sine turn takes 256 frames (5 seconds)
        lda sine,x                  ; 0 to 63
        clc                         ; clear carry before adding
        adc #24                     ; 24 to 87: from dark and muffled to open
        sta SID_FC_HI               ; cutoff high byte
        lda drum_slide              ; is the kick drum playing? (1 to KICK_LEN: the frame of the kick)
        beq .noslide                ; no
        tax                         ; X = frame number
        lda kick_freq_hi - 1,x      ; the pitch for this frame: it falls fast, then stays low
        sta SID_FREQ3H
        lda kick_freq_lo - 1,x      ; (16 bit: the low byte too)
        sta SID_FREQ3L
        cpx #1                      ; the first frame after the hit?
        bne .notfirst
        lda #%00010001              ; the noise click is over: from now on a triangle wave, a soft low thump, gate stays on
        sta SID_CTRL3
.notfirst
        inx                         ; next frame
        cpx #KICK_LEN + 1           ; past the last one?
        bcc .keepslide              ; no
        ldx #0                      ; yes: the kick is done
.keepslide
        stx drum_slide              ; remember where we are
.noslide
        lda sfx_timer               ; is a sound effect playing on voice 1?
        beq +                       ; no
        dec sfx_timer               ; one frame less to go
+
        dec music_timer             ; one frame closer to the next note
        beq .note                   ; time for the next note
        rts                         ; not yet (the code below is too long for a branch to .done)
.note
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
        txa                         ; the bass plays on every 4th note: ...
        and #%00000011              ; ... steps 0 and 4 of each chord
        bne .nobass                 ; not this one
        lda sfx_timer               ; a sound effect is using voice 1
        bne .nobass                 ; then the bass waits
        txa                         ; step number ...
        lsr                         ; ... divided by 8 = the chord number 0 to 3 ...
        lsr
        lsr
        tay                         ; Y = chord
        lda bass_lo,y               ; the root of the chord, low byte
        sta SID_FREQ1L
        lda bass_hi,y               ; high byte
        sta SID_FREQ1H
        lda #$08                    ; attack 0, decay 8: the note fades to its sustain level
        sta SID_AD1                 ; (a sound effect may have changed these, so set them every time)
        lda #$60                    ; sustain 6, release 0
        sta SID_SR1
        lda #%00100000              ; sawtooth waveform, gate off (resets the envelope)
        sta SID_CTRL1
        lda #%00100001              ; sawtooth waveform, gate on
        sta SID_CTRL1               ; the bass note starts
.nobass
        txa                         ; the drums: step number in the bar of 8 ...
        and #%00000111
        tay                         ; Y = position in the bar
        lda drum_pat,y              ; 0 none, 1 kick, 2 snare, 3 hat
        beq .nodrum                 ; none
        tay                         ; Y = drum type
        lda drum_ad - 1,y           ; its attack and decay
        sta SID_AD3
        lda #0                      ; sustain 0, release 0
        sta SID_SR3
        lda drum_fhi - 1,y          ; its start pitch
        sta SID_FREQ3H
        lda #0                      ; (low byte 0: the kick changes it)
        sta SID_FREQ3L
        lda #0                      ; the snare and the hat do not change after the hit ...
        cpy #1                      ; ... the kick starts its pitch fall on the next frame
        bne .notkick
        lda #1
.notkick
        sta drum_slide              ; (this also stops a fall that was still going)
        lda drum_wave - 1,y         ; the waveform of the first frame
        sta SID_CTRL3               ; gate off (resets the envelope)
        ora #%00000001              ; gate on
        sta SID_CTRL3               ; the drum hits
.nodrum
        inx                         ; next note
        cpx #MUSIC_LEN              ; end of the tune?
        bne .store                  ; no
        ldx #0                      ; yes: loop back to the start
.store
        stx music_step              ; remember where we are
        rts                         ; return to the caller
