; sound.asm - the game's side of the sound. Everything that sounds is made by the WebSidTracker player in src/sound/:
; main.asm starts the tune once with music_init, update_music runs the player once per frame, and the three moments of
; the game start their sound effect with sfx_play (score.asm, chapter.asm, main.asm). The game itself writes nothing
; to the SID.

!zone update_music
update_music                        ; subroutine: once per frame: the music and the effects, and the bars pump on the kick
        jsr music_play              ; the player: every SID write of this frame
        lda st_age + 2              ; voice 3 plays the drums: frames its note has been sounding (the player's state block)
        cmp #1                      ; 1 = the note started in this very frame
        bne +                       ; no new note: nothing to do
        lda st_instr + 2            ; which instrument does it play?
        cmp #SND_KICK               ; the kick?
        bne +                       ; no
        lda bar_phase               ; a kick: push the raster bars forward, so they pump with the beat
        clc                         ; clear carry before adding
        adc #6                      ; six sine steps
        sta bar_phase
+       rts                         ; return to the caller
