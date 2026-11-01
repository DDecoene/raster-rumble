; chapter.asm - the screen between two chapters of the story: the time of the new chapter and one sentence that types itself
; See docs/story.md. The music, the stars and the raster bars keep going, like on the title screen.

!zone chapter_screen
chapter_screen                      ; subroutine: show the time and the sentence of the chapter in the variable 'chapter', then back to the game
        jsr reset_scroll            ; no shake, no scroll, extended colour mode off (the plasma needs it, this screen does not)
        lda #0                      ; A = 0
        sta SPR_ENABLE              ; hide the ship, the enemy and any explosion sprites
        sta chap_timer              ; the screen has been showing for 0 frames
        sta pal_base                ; blue raster bars
        sta scr_fine                ; raster_show also controls the scroller row: no fine scroll, that row is empty here
        jsr reset_star_under        ; the stars forget what was under them (the plasma): this screen is blank
        lda #$20                    ; clear the playfield (rows 1 to 24): a space everywhere, so the plasma is gone
        ldx #0                      ; X counts 0 to 239
.clear
        sta SCREEN + 40,x           ; four runs of 240 characters
        sta SCREEN + 280,x
        sta SCREEN + 520,x
        sta SCREEN + 760,x
        inx                         ; next character
        cpx #240                    ; did we do 240?
        bne .clear                  ; no, continue
        jsr make_bars               ; the bar colours (the game itself does not use them, so nothing is lost)

        lda chapter                 ; the time: 5 letters per chapter, so the offset is chapter * 5
        asl                         ; times 2
        asl                         ; times 4
        clc                         ; clear carry before adding
        adc chapter                 ; plus 1 = times 5
        tax                         ; X = where this chapter's time starts in chapter_time
        ldy #0                      ; Y = letter on the screen, counting up
.time
        lda chapter_time,x          ; one letter of the time
        sta CHAP_TIME_POS,y         ; put it on the screen
        lda #COLOR_WHITE            ; white
        sta COLOR_RAM + CHAP_TIME_POS - SCREEN,y ; colour it
        inx                         ; next letter in the table
        iny                         ; next place on the screen
        cpy #5                      ; did we print all 5?
        bne .time                   ; no, continue

.frame
        jsr raster_show             ; the colour bars (this also waits for the next frame)
        inc frame_count             ; one more frame has passed
        jsr update_stars            ; the stars keep scrolling behind the text
        jsr update_music            ; and the synth keeps sweeping (the tune itself ticks inside raster_show)

        lda chap_timer              ; the sentence types itself: one more letter every 2 frames ...
        lsr                         ; ... so the number of letters to show is the timer divided by 2
        cmp #CHAPTER_LEN            ; more than the sentence has?
        bcc .limited                ; no, use it
        lda #CHAPTER_LEN            ; yes, show all of it
.limited
        sta fx_tmp                  ; fx_tmp = how many letters to show now
        lda chapter                 ; the offset of this sentence: chapter * 32 (CHAPTER_LEN) is 5 shifts left
        asl                         ; times 2
        asl                         ; times 4
        asl                         ; times 8
        asl                         ; times 16
        asl                         ; times 32
        tax                         ; X = where this chapter's sentence starts in chapter_text
        ldy #0                      ; Y = letter on the screen, counting up
.text
        cpy fx_tmp                  ; shown as many as we should?
        beq .typed                  ; yes, finished for this frame
        lda chapter_text,x          ; one letter of the sentence
        sta CHAP_TEXT_POS,y         ; put it on the screen
        lda #COLOR_LGREY            ; light grey
        sta COLOR_RAM + CHAP_TEXT_POS - SCREEN,y ; colour it
        inx                         ; next letter in the table
        iny                         ; next place on the screen
        bne .text                   ; (always taken here: Y never gets to 256, the cpy above stops at 32)
.typed
        inc chap_timer              ; one more frame shown
        lda chap_timer              ; long enough?
        cmp #CHAP_FRAMES            ; 3 seconds
        bcc .frame                  ; no, show the next frame

        jsr plasma_init             ; the playfield becomes a plasma again (this also removes the text)
        lda #%00000011              ; bits 0 and 1 set = sprites 0 and 1 on
        sta SPR_ENABLE              ; show the ship and the enemy again
        lda SPR_COLL                ; read the collision register once to clear leftovers
        rts                         ; back to the game
