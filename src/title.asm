; title.asm - the title and game over screens: bouncing letters, raster bars and a scroller (see demo.asm), a flashing prompt,
; and the stars and music keep going

!zone title_screen
title_screen                        ; subroutine: show the title until a key or the joystick is pressed
        lda #0                      ; A = 0
        sta title_mode              ; the title, not the game over screen
        sta clean_count             ; frame counter for the waiting time at the start, keys are ignored until it is over
        sta pal_base                ; blue raster bars
        sta col_base                ; title letter colours
        lda #<title_text            ; the bouncing letters ...
        sta txt_ptr
        lda #>title_text
        sta txt_ptr + 1
        lda #<title_scroll          ; ... and the scroller text
        sta scr_ptr
        lda #>title_scroll
        sta scr_ptr + 1
        bne .start                  ; (always taken, the high byte is not 0) share the rest with game_over
game_over                           ; subroutine: show "game over" until a key or the joystick is pressed
        lda #1                      ; the game over screen
        sta title_mode              ; draw_title picks other text
        lda #32                     ; fire raster bars
        sta pal_base
        lda #8                      ; game over letter colours
        sta col_base
        lda #<over_text
        sta txt_ptr
        lda #>over_text
        sta txt_ptr + 1
        lda #<over_scroll
        sta scr_ptr
        lda #>over_scroll
        sta scr_ptr + 1
        lda #RELEASE_FRAMES - OVER_WAIT ; a short wait only, the player was just playing
        sta clean_count             ; (a key held from the game must still be released first)
.start
        lda #0                      ; A = 0
        sta SPR_ENABLE              ; hide the ship and the enemy while the text shows
        sta key_count               ; no frames with a key down yet
        sta scr_idx                 ; the scroller starts at the first letter
        jsr make_bars               ; the bar colours of this screen
        lda #7
        sta scr_fine                ; ... with the fine scroll at 7
.frame
        jsr raster_show             ; the colour bars and the scroller split: this also waits for the next frame
        inc frame_count             ; one more frame has passed (the stars and the colours use it)
        jsr update_stars            ; the stars keep scrolling behind the title
        jsr update_music            ; and the tune keeps playing
        jsr draw_title              ; draw the text on top of any star that crossed it
        jsr scroll_step             ; move the scroller 2 pixels
        lda clean_count             ; the first RELEASE_FRAMES frames only count time, whatever is pressed: ...
        cmp #RELEASE_FRAMES         ; ... emulators type their own RUN keys and send stray input just after loading
        bcc .arming                 ; still waiting
        jsr any_key                 ; is something pressed?
        bcs .down                   ; yes
        lda #0                      ; no: a single stray frame must not start the game ...
        sta key_count               ; ... so start counting key frames again
        lda #RELEASE_FRAMES + 1     ; and one frame with nothing pressed is the all-clear:
        sta clean_count             ; from now on a key press counts
        jmp .frame                  ; show the next frame
.arming
        inc clean_count             ; one more frame of waiting
        jmp .frame                  ; show the next frame
.down
        lda clean_count             ; was the all-clear given yet? (a key still held from the loading does not count)
        cmp #RELEASE_FRAMES + 1     ; carry set = yes
        bcc .frame                  ; no, keep waiting
.count
        inc key_count               ; one more frame with a key down
        lda key_count               ; how many in a row?
        cmp #KEY_FRAMES             ; long enough to be a real key press?
        bcc .frame                  ; no, show the next frame
        lda #$20                    ; yes: A = space
        ldx #39                     ; the 40 cells of a row, counting down
.erase
        sta SCREEN + BOUNCE_ROW * 40,x     ; clear the rows of the bouncing letters (6 to 9) ...
        sta SCREEN + (BOUNCE_ROW + 1) * 40,x
        sta SCREEN + (BOUNCE_ROW + 2) * 40,x
        sta SCREEN + (BOUNCE_ROW + 3) * 40,x
        sta SUB_POS - SUB_COL,x     ; clear the tagline row
        sta PROMPT_POS - PROMPT_COL,x ; clear the prompt row
        sta SCROLL_POS,x            ; clear the scroller row
        dex                         ; previous cell
        bpl .erase                  ; until X goes below 0
        lda #%00000011              ; bits 0 and 1 set = sprites 0 and 1 on
        sta SPR_ENABLE              ; show the ship and the enemy again
        rts                         ; back to the start of the game

!zone draw_title
draw_title                          ; subroutine: draw the bouncing letters, then the other text lines, once per frame
        jsr draw_bounce             ; the 13 letters on their sine wave
        lda title_mode              ; which screen?
        beq .titlemode              ; 0 = the title
        jmp draw_over               ; game over (draw_over returns to our caller)
.titlemode
        ldx #SUB_LEN - 1            ; tagline letter, counting down
.sub
        lda sub_text,x              ; one letter of the tagline
        sta SUB_POS,x               ; put it on the screen
        lda #COLOR_LGREY            ; light grey
        sta COLOR_RAM + SUB_POS - SCREEN,x ; colour it
        dex                         ; previous letter
        bpl .sub                    ; until X goes below 0
        lda frame_count             ; the prompt flashes: bit 4 of the counter flips every 16 frames
        and #%00010000              ; keep only that bit
        beq .on                     ; 0 = white phase
        lda #COLOR_DGREY            ; 1 = dim phase
        bne .setcol                 ; (always taken, A is not zero) skip the white
.on
        lda #COLOR_WHITE            ; bright phase
.setcol
        sta xlo                     ; remember the colour while X is busy
        ldx #PROMPT_LEN - 1         ; prompt letter, counting down
.prompt
        lda prompt_text,x           ; one letter of the prompt
        sta PROMPT_POS,x            ; put it on the screen
        lda xlo                     ; the flash colour
        sta COLOR_RAM + PROMPT_POS - SCREEN,x ; colour it
        dex                         ; previous letter
        bpl .prompt                 ; until X goes below 0
        rts                         ; return to the caller

!zone draw_over
draw_over                           ; subroutine: the flashing restart prompt of the game over screen
        lda frame_count             ; the prompt flashes like on the title
        and #%00010000              ; bit 4 flips every 16 frames
        beq .on                     ; 0 = white phase
        lda #COLOR_DGREY            ; 1 = dim phase
        bne .setcol                 ; (always taken)
.on
        lda #COLOR_WHITE            ; bright phase
.setcol
        sta xlo                     ; remember the colour while X is busy
        ldx #RESTART_LEN - 1        ; letter number, counting down
.restart
        lda restart_text,x          ; one letter
        sta RESTART_POS,x           ; put it on the screen
        lda xlo                     ; the flash colour
        sta COLOR_RAM + RESTART_POS - SCREEN,x ; colour it
        dex                         ; previous letter
        bpl .restart                ; until X goes below 0
        rts                         ; return to the caller

!zone any_key
any_key                             ; subroutine: carry set = a key or a joystick-2 direction/fire is pressed
        jsr cia_inputs              ; make sure both ports are inputs, see below
        lda CIA1_PORTA              ; joystick port 2: all 1 = nothing pressed
        cmp #$ff                    ; anything pulled low?
        bne .yes                    ; yes: a direction or fire
        lda #$00                    ; now the keyboard: pull all 8 key columns low at once (port A as output) ...
        sta CIA1_PORTA              ; the output latch is 0
        lda #$ff                    ; all 8 pins become outputs ...
        sta CIA1_DDRA               ; ... and drive the columns low
        ldx #10                     ; the lines need a moment to settle
.settle
        dex                         ; count down
        bne .settle                 ; about 50 cycles of waiting
        lda CIA1_PORTB              ; key rows: all 1 = no key down in any column
        pha                         ; keep the answer, the next lines use A
        lda #$00                    ; put port A back to inputs, like the game wants ...
        sta CIA1_DDRA               ; ... all pins are inputs again
        lda #$ff                    ; ... with the latch high
        sta CIA1_PORTA              ; (nothing is driven now, the joystick can pull lines low freely)
        pla                         ; the key rows again
        cmp #$ff                    ; any row low?
        bne .yes                    ; yes: a key is down
        clc                         ; no key, no joystick: carry clear
        rts                         ; return to the caller
.yes
        sec                         ; carry set = pressed
        rts                         ; return to the caller

!zone cia_inputs
cia_inputs                          ; subroutine: both CIA 1 ports as inputs with their latches high, timers off the port pins
        lda #$ff                    ; all bits 1
        sta CIA1_PORTA              ; port A latch high (nothing selected)
        sta CIA1_PORTB              ; port B latch high
        lda #$00                    ; 0 = every pin is an input
        sta CIA1_DDRA               ; port A all inputs, so only the joystick can pull a line low
        sta CIA1_DDRB               ; port B all inputs, so a held key cannot pull a joystick line low
        lda CIA1_CRA                ; timer A control
        and #%11111101              ; bit 1 = 0: the timer does not take over port B pin 6 (it would look like a key down)
        sta CIA1_CRA                ; store it back, the timer keeps running
        lda CIA1_CRB                ; timer B control
        and #%11111101              ; bit 1 = 0: the timer does not take over port B pin 7 (row 7: Space, Q, Run/Stop ...)
        sta CIA1_CRB                ; store it back
        rts                         ; return to the caller
