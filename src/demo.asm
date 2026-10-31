; demo.asm - the demo effects of the title and game over screens: raster bars, bouncing letters and a scroller

!zone wait_line
wait_line                           ; subroutine: return when the beam is on raster line Y (or already past it)
.wait
        cpy VIC_RASTER              ; carry set when Y >= the current line
        bcc .done                   ; Y < line: we are past it already, go on
        bne .wait                   ; Y > line: not there yet
.done
        rts                         ; return to the caller

!zone make_bars
make_bars                           ; subroutine: fill barcol with the colour of each of the 256 steps of the sine wave
        ldx #0                      ; step number
.step
        lda sine,x                  ; 0 to 63
        lsr                         ; 0 to 31: one of the 32 colours of a bar
        clc                         ; clear carry before adding
        adc pal_base                ; blue or fire colours
        tay                         ; Y = palette index
        lda bar_pal,y               ; the colour for this step
        sta barcol,x                ; keep it
        inx                         ; next step
        bne .step                   ; until X wrapped around to 0
        rts                         ; return to the caller

!zone raster_show
raster_show                         ; subroutine: once per frame, the colour bars and the fine scroll split (takes about 140 lines)
        ldy #54                     ; the tune runs twice per frame: one tick here, before the bars ...
        jsr wait_line               ; (no later than line 54, or at once if the frame work ended after it)
        jsr music_tick
        inc bar_phase               ; the bars slide: one sine step per frame
        inc bar_phase               ; (two, so they move at a good speed)
        lda bar_phase               ; the sine step of the first line is ...
        clc                         ; clear carry before adding
        adc #<(BAR_TOP * BAR_FREQ)  ; ... the phase plus the line number times 4 (wraps at 256)
        tax                         ; X = sine step, it goes up by 4 for every line
        ldy #BAR_TOP                ; first line of the bars
.line
        cpy VIC_RASTER              ; carry set when Y >= the current line
        bcc .go                     ; Y < line: we are past it already, go on
        bne .line                   ; Y > line: not there yet
.go
        lda barcol,x                ; the colour for this line, written right at the start of the line so the edge stays straight
        sta VIC_BG                  ; background ...
        sta VIC_BORDER              ; ... and border get it: the bars run across the whole width
        inx                         ; next line is 4 sine steps further
        inx
        inx
        inx
        iny                         ; next line
        cpy #BAR_END                ; done with the bars?
        bne .line                   ; no
        lda #0                      ; yes: black again for the rest of the frame
        sta VIC_BG                  ; background
        sta VIC_BORDER              ; border
        jsr music_tick              ; ... and one after them, about half a frame later
        ldy #SCROLL_LINE            ; just above the scroller row
        jsr wait_line               ; wait for it
        lda scr_fine                ; the fine scroll, 0 to 7 pixels
        ora #%11001000              ; keep 40 columns (bit 3) and the unused bits as they are
        sta VIC_CTRL2               ; from here the scroller row is shifted a few pixels to the right
        ldy #SCROLL_STOP            ; below the scroller row
        jsr wait_line               ; wait for it
        lda #%11001000              ; no fine scroll
        sta VIC_CTRL2               ; the rest of the screen stands still
        rts                         ; return to the caller

!zone scroll_step
scroll_step                         ; subroutine: move the scroller 2 pixels left and draw its row
        lda scr_fine                ; current fine scroll
        sec                         ; set carry before subtracting
        sbc #2                      ; 2 pixels per frame
        bcs .store                  ; still 0 or more: just keep it
        adc #8                      ; went below 0: wrap round ...
        inc scr_idx                 ; ... and the whole row moves one letter
        ldy scr_idx                 ; the letter that is now at the left edge
        pha                         ; keep the fine scroll value
        lda (scr_ptr),y             ; is it the end marker?
        cmp #$ff
        bne .keep                   ; no
        lda #0                      ; yes: the left edge is back at the start of the text
        sta scr_idx
.keep
        pla                         ; the fine scroll value again
.store
        sta scr_fine                ; keep it
        ldy scr_idx                 ; index of the letter at the left edge
        ldx #0                      ; screen column
.letter
        lda (scr_ptr),y             ; the letter
        cmp #$ff                    ; the end marker?
        bne .put                    ; no
        ldy #0                      ; yes: the row carries on from the start of the text
        lda (scr_ptr),y             ; the first letter
.put
        sta SCROLL_POS,x            ; put it on the screen
        iny                         ; next letter
        inx                         ; next column
        cpx #40                     ; the whole row?
        bne .letter                 ; no
        lda frame_count             ; the colours slide along: every 4 frames one step
        lsr                         ; shift right twice
        lsr                         ; (lsr alone on A shifts the accumulator)
        sta xlo                     ; colour offset
        ldx #39                     ; column, counting down
.colour
        txa                         ; column ...
        clc                         ; clear carry before adding
        adc xlo                     ; ... plus the offset ...
        and #%00000111              ; ... wrapped to 0-7 ...
        ora col_base                ; ... in the colours of this screen
        tay                         ; Y = index
        lda letter_cols,y           ; the colour
        sta COLOR_RAM + SCROLL_ROW * 40,x ; colour the cell
        dex                         ; previous column
        bpl .colour                 ; until X goes below 0
        rts                         ; return to the caller

!zone draw_bounce
draw_bounce                         ; subroutine: the 13 letters of txt_ptr, each on its own place of a sine wave of 4 rows
        lda #$20                    ; A = space
        ldx #12                     ; the 13 columns, counting down
.clear
        sta SCREEN + BOUNCE_ROW * 40 + TITLE_COL,x       ; clear the 4 rows the letters can be on
        sta SCREEN + (BOUNCE_ROW + 1) * 40 + TITLE_COL,x
        sta SCREEN + (BOUNCE_ROW + 2) * 40 + TITLE_COL,x
        sta SCREEN + (BOUNCE_ROW + 3) * 40 + TITLE_COL,x
        dex                         ; previous column
        bpl .clear                  ; until X goes below 0
        lda frame_count             ; the colours slide along: every 4 frames one step
        lsr                         ; shift right twice
        lsr
        sta xlo                     ; colour offset
        ldy #12                     ; letter number, counting down
.letter
        tya                         ; letter number ...
        asl                         ; ... times 16, so the letters sit 16 steps apart in the wave
        asl
        asl
        asl
        sta xhi                     ; keep it (xhi is scratch)
        lda frame_count             ; the wave travels: 3 steps per frame
        asl                         ; times 2 ...
        clc                         ; clear carry before adding
        adc frame_count             ; ... plus 1 = times 3
        clc
        adc xhi                     ; plus the letter's place
        tax                         ; X = sine index
        lda sine,x                  ; 0 to 63
        lsr                         ; divide by 16: 0 to 3 = the row
        lsr
        lsr
        lsr
        tax                         ; X = row offset
        lda bounce_lo,x             ; screen address of that row, at the first letter's column
        sta row_ptr                 ; low byte
        sta crow_ptr                ; colour RAM has the same low byte
        lda bounce_hi,x             ; high byte
        sta row_ptr + 1
        clc                         ; clear carry before adding
        adc #>(COLOR_RAM - SCREEN)  ; colour RAM sits $d400 higher
        sta crow_ptr + 1
        lda (txt_ptr),y             ; the letter
        sta (row_ptr),y             ; put it on the screen: Y is the column inside the row
        tya                         ; letter number ...
        clc                         ; clear carry before adding
        adc xlo                     ; ... plus the colour offset ...
        and #%00000111              ; ... wrapped to 0-7 ...
        ora col_base                ; ... in the colours of this screen
        tax                         ; X = index
        lda letter_cols,x           ; the colour
        sta (crow_ptr),y            ; colour the cell
        dey                         ; previous letter
        bpl .letter                 ; until Y goes below 0
        rts                         ; return to the caller


!zone game_bars
game_bars                           ; subroutine: once per frame, in the game: a tick of the music, the three scroll bands, and in between
        lda #54                     ; rows of the plasma (4 a frame, the whole plasma every 6 frames) (while the beam is drawing the screen; the colours change under it)
-       cmp VIC_RASTER              ; wait for line 54 ...
        bne -                       ; (equal, not "at least": the work before this ends below line 54 or after the wrap)
        jsr music_tick
        ldy #BAND1_LINE             ; row 1 (below the score) starts: the first scroll band
        jsr wait_line
        lda band1
        sta VIC_CTRL2
        jsr plasma_step             ; 1 row of the plasma (about 28 raster lines)
        ldy #BAND2_LINE
        jsr wait_line
        lda band2
        sta VIC_CTRL2
        jsr plasma_step             ; 2 rows
        jsr plasma_step
        ldy #BAND3_LINE
        jsr wait_line
        lda band3
        sta VIC_CTRL2
        jsr plasma_step             ; 1 row
        ldy #210                    ; half a frame after the first tick
        jsr wait_line
        jmp music_tick              ; the second tick of the frame (it returns to our caller)
