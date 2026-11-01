; music.asm - the tune: the arpeggio on SID voice 2 (with a moving pulse width and a sweeping filter, for a synth sound)
; a sawtooth bass on voice 1 that follows the chords, and drums on voice 3. Voice 3 also plays the short sound effects (sfx_blip).
; The tune runs at 100 Hz ("double speed", like the demo scene players): music_tick is called twice per frame.
; update_music is called once per frame and does the things that need no more than 50 Hz.

!zone update_music
update_music                        ; subroutine: once per frame: the synth sweeps and the sound effect timer
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
        lda sfx_timer               ; is a sound effect playing on voice 3?
        beq +                       ; no
        dec sfx_timer               ; one frame less to go
+       rts                         ; return to the caller

!zone bass_start
bass_start                          ; subroutine: start the bass note of chord Y (0 to 3) on voice 1
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
        rts                         ; return to the caller

!zone music_tick
music_tick                          ; subroutine: one tick (10 ms): a new step of the tune every MUSIC_TICKS ticks, and the drum tables
        dec music_timer             ; one tick closer to the next step
        beq .step                   ; time for the next step
        lda music_timer
        cmp #1                      ; the last tick before the next step?
        beq .restart                ; yes
        jmp .engine                 ; no
.restart
        ; Hard restart. The SID has a quirk: a note that starts while the envelope of the old one has not died away
        ; can come out too soft or late. So one tick before a note we switch the voice off with all its envelope
        ; times at 0, the envelope drops to nothing at once, and the new note starts from a clean zero.
        ldx music_step              ; the step that comes next
        txa
        and #%00000001              ; odd steps have no arpeggio note ...
        bne .hrdrum                 ; ... only drums
        lda #0
        sta SID_AD2                 ; voice 2: instant attack and decay
        sta SID_SR2                 ; sustain 0, release 0
        lda #%01000000              ; pulse wave, gate off
        sta SID_CTRL2
        txa
        and #%00000111              ; the bass starts on steps 0 and 8 of each chord ...
        bne .hrdrum
        lda #0
        sta SID_AD1                 ; voice 1 (the bass) the same way
        sta SID_SR1
        lda #%00100000              ; sawtooth, gate off
        sta SID_CTRL1
.hrdrum
        lda sfx_timer               ; a sound effect owns voice 3 (the drum voice): no drum comes, so leave it alone
        beq +
        jmp .engine
+       txa
        and #%00001111              ; position in the bar of 16 steps
        tay
        lda drum_pat,y              ; a drum coming?
        bne +                       ; yes
        jmp .engine                 ; no
+       lda #0
        sta drum_idx                ; the old drum stops (otherwise its table would switch the gate on again)
        sta SID_AD3
        sta SID_SR3
        lda #%10000000              ; noise, gate off
        sta SID_CTRL3
        jmp .engine                 ; the old drum's table must not run on
.step
        lda #MUSIC_TICKS            ; reload the timer
        sta music_timer
        ldx music_step              ; which step?
        txa
        and #%00000001              ; even steps carry an arpeggio note
        bne .drums
        txa
        lsr                         ; note number = step / 2
        tay                         ; Y = note
        lda music_lo,y              ; its frequency, low byte
        sta SID_FREQ2L
        lda music_hi,y              ; high byte
        sta SID_FREQ2H
        lda #$06                    ; attack 0, decay 6: a short pluck (the hard restart set it to 0)
        sta SID_AD2
        lda #$00                    ; sustain 0, release 0
        sta SID_SR2
        lda #%01000000              ; pulse waveform, gate off
        sta SID_CTRL2
        lda #%01000001              ; pulse waveform, gate on
        sta SID_CTRL2               ; gate 0 to 1 plucks the note
        tya                         ; the bass plays on every 4th note: ...
        and #%00000011              ; ... steps 0 and 8 of each chord
        beq +
        jmp .drums
+       tya                         ; note number ...
        lsr                         ; ... divided by 8 = the chord number 0 to 3 ...
        lsr
        lsr
        tay                         ; Y = chord
        jsr bass_start              ; the bass note starts
.drums
        ldx music_step
        lda sfx_timer               ; a sound effect is playing on voice 3: no drum now
        bne .nodrum
        txa                         ; the drums: step number in the bar of 16 ...
        and #%00001111
        tay                         ; Y = position in the bar
        lda drum_pat,y              ; 0 none, 1 kick, 2 snare, 3 hat
        beq .nodrum                 ; none
        tay                         ; Y = drum type
        cpy #1                      ; the kick pushes the raster bars forward: they pump with the beat
        bne +
        lda bar_phase
        clc
        adc #6
        sta bar_phase
+       lda drum_ad - 1,y           ; its attack and decay
        sta SID_AD3
        lda #0                      ; sustain 0, release 0
        sta SID_SR3
        lda drum_start - 1,y        ; where this drum begins in the tables
        sta drum_base
        lda #1                      ; the first tick of the table is played right below (.engine)
        sta drum_idx
.nodrum
        inx                         ; next step
        cpx #MUSIC_LEN              ; end of the tune?
        bne .store                  ; no
        ldx #0                      ; yes: loop back to the start
.store
        stx music_step              ; remember where we are
.engine
        ldx drum_idx                ; the drum tables: one entry per tick, a pitch (16 bit) and sometimes a new waveform
        beq .done                   ; no drum playing
        txa
        clc
        adc drum_base               ; table position + 1
        tay
        lda drum_fhi - 1,y          ; the pitch of this tick ...
        sta SID_FREQ3H
        lda drum_flo - 1,y
        sta SID_FREQ3L
        lda drum_ctrl - 1,y         ; a new waveform (with the gate on)? 0 = keep the current one
        beq +
        sta SID_CTRL3
+       inx                         ; next tick
        cpx #DRUM_LEN + 1           ; past the end of the table?
        bcc +
        ldx #0                      ; yes: the drum is done (the voice keeps its last pitch and fades with its decay)
+       stx drum_idx
.done
        rts                         ; return to the caller

!zone sfx_blip
sfx_blip                            ; subroutine: the short blip for a scored point, on voice 3 (the drum voice)
        lda #$03                    ; attack 0, decay 3: a short blip
        sta SID_AD3                 ; voice 3 envelope
        lda #$00                    ; sustain 0 , release 0
        sta SID_SR3                 ; voice 3 envelope part 2
        lda #$00                    ; a drum may have left a low byte behind
        sta SID_FREQ3L              ; voice 3 frequency, low byte
        lda #$50                    ; a high pitch
        sta SID_FREQ3H              ; voice 3 frequency
        lda #%00010000              ; triangle waveform, gate off (resets the envelope)
        sta SID_CTRL3               ; voice 3 stops
        lda #%00010001              ; triangle waveform, gate on
        sta SID_CTRL3               ; gate 0 to 1 starts the blip
        lda #0
        sta drum_idx                ; the drum that was playing stops (its table must not touch the voice)
        lda #SFX_BLIP               ; the drums keep quiet for a moment
        sta sfx_timer
        rts                         ; return to the caller
