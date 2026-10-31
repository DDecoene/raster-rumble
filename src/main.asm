; raster-rumble - a C64 dodge game: fly the ship with the joystick (port 2), dodge the falling enemy
; Assembler: ACME
;
; Where to find things (this file holds the startup code and the main loop, the rest is included below):
;   src/hardware.asm   names for the VIC, SID and CIA registers, colours and fixed memory areas
;   src/config.asm     difficulty settings, screen layout, zero page and RAM variable addresses
;   src/actors.asm     ship and enemy movement (9-bit X), spawning, homing, difficulty
;   src/score.asm      score and high score
;   src/starfield.asm  RAM character set, scrolling stars, random_column
;   src/music.asm      the tune on SID voice 2
;   src/title.asm      the title and game over screens and the any-key check
;   src/demo.asm       the demo effects of those screens: raster bars, bouncing letters, scroller
;   src/data.asm       tables and text
;   src/sprites.asm    the ship and enemy shapes at $2000
;
; 6502 refresher:
;   A = accumulator, X/Y = index registers (unused here)
;   lda = load A, sta = store A, cmp = compare A (sets flags, A unchanged)
;   beq/bne = branch if equal/not equal (zero flag), bcs/bcc = branch if carry set/clear
;   lsr = shift right, the bit that falls off the end goes into the carry flag
;   inc/dec = add/subtract 1 directly in memory
;   '#' means a literal number, no '#' means "the contents of that address"
; ACME refresher:
;   '!byte' / '!word' / '!text' place data, '!source' pastes in another file, '+' and '-' are anonymous labels
;   (a branch to '+' goes to the next '+' below, a branch to '-' to the previous '-' above)

        * = $0801                   ; BASIC programs always start loading here

; BASIC stub: "10 SYS 2064", so typing RUN jumps into our machine code
        !word basic_end, 10         ; pointer to the next BASIC line, then line number 10
        !byte $9e                   ; BASIC token for the SYS command
        !text "2064"                ; the address of 'start' as decimal text (checked below)
        !byte 0                     ; end of this BASIC line
basic_end
        !word 0                     ; end of the BASIC program (a pointer of 0)

; Names: chip registers first, then our own settings and variable addresses
        !source "src/hardware.asm"
        !source "src/config.asm"

        * = $0810                   ; our code lives here (decimal 2064, matches the SYS above)

start
        !if start != 2064 {         ; safety net: the BASIC stub text must match this address
            !error "start is not at 2064, update the SYS text in the BASIC stub"
        }
        sei                         ; disable interrupts, we poll the hardware ourselves
        lda #$ff                    ; all bits 1 = nothing selected, nothing pressed
        sta CIA1_PORTA              ; port A output latch high (joystick port 2 and keyboard columns)
        sta CIA1_PORTB              ; port B output latch high (joystick port 1 and keyboard rows)
        lda #$00                    ; 0 = every pin is an input
        sta CIA1_DDRA               ; port A all inputs, so we only read what the joystick pulls low
        sta CIA1_DDRB               ; port B all inputs, so held keys cannot pull joystick lines low (ghost directions)
        lda #$00                    ; A = 0 (colour black)
        sta VIC_BORDER              ; border = black
        sta VIC_BG                  ; background = black

        lda #sprite_data / 64       ; sprite shape address divided by 64 = pointer value (128)
        sta SPRITE_PTR              ; tell the VIC sprite 0 uses that shape
        lda #enemy_data / 64        ; enemy shape address divided by 64 = pointer value (129)
        sta SPRITE1_PTR             ; tell the VIC sprite 1 uses that shape
        lda #%00000011              ; bits 0 and 1 set = sprites 0 and 1 are multicolor
        sta SPR_MULTI               ; 12 fat pixels per row, 4 colours (including transparent) per sprite
        lda #COLOR_ORANGE           ; multicolor 0 is shared by all sprites
        sta SPR_MC0                 ; orange: wing tips, engine, enemy spikes
        lda #COLOR_YELLOW           ; multicolor 1 is shared too
        sta SPR_MC1                 ; yellow: cockpit, flame core, enemy eyes
        lda #1                      ; colour 1 = white
        sta SPR0_COLOR              ; sprite 0 (ship) hull is white
        lda #COLOR_RED              ; colour 2 = red
        sta SPR1_COLOR              ; sprite 1 (enemy) is red
        lda #160                    ; start X: roughly the middle
        sta SPR0_X                  ; set ship X
        lda #$00                    ; bit 8 of every sprite X = 0
        sta SPR_XHI                 ; (X values start below 256)
        lda #200                    ; start Y: near the bottom
        sta SPR0_Y                  ; set ship Y

        lda #$a7                    ; any value but 0: the random number generator starts here
        sta rnd
        lda #0                      ; voice 3 is the drum voice (see music.asm), no sound yet
        sta drum_slide              ; the kick pitch is not sliding
        sta SID_FREQ3L              ; frequency low byte (the drums only set the high byte)

        lda #%00011111              ; volume 15 (max), bit 4 = low-pass filter, bit 7 = 0: voice 3 is not muted
        sta SID_VOLUME              ; switch the sound on
        lda #$a2                    ; resonance 10, and voice 2 (bit 1) goes through the filter, the bass and the effects do not
        sta SID_RES                 ; filter setup
        lda #$00                    ; no sound effect is playing
        sta sfx_timer
        lda #$09                    ; attack 0 (instant), decay 9 (about 0.75 seconds)
        sta SID_AD1                 ; voice 1 envelope part 1
        lda #$00                    ; sustain 0 (silent once decayed), release 0
        sta SID_SR1                 ; voice 1 envelope part 2
        lda #$08                    ; a fairly high pitch, for a crunchy noise
        sta SID_FREQ1H              ; voice 1 frequency high byte (low byte stays 0)

        lda #$06                    ; voice 2 plays the music: attack 0, decay 6 (a short pluck)
        sta SID_AD2                 ; voice 2 envelope part 1
        lda #$00                    ; sustain 0, release 0
        sta SID_SR2                 ; voice 2 envelope part 2
        lda #$00                    ; pulse width $0800 = a square wave
        sta SID_PW2L                ; pulse width low byte
        lda #$08                    ; high nibble 8
        sta SID_PW2H                ; pulse width high byte
        lda #1                      ; play the first note on the next frame
        sta music_timer             ; counts down to 0
        lda #0                      ; A = 0
        sta music_step              ; start the tune at note 0
        sta hit_timer               ; border is not flashing yet

        jsr setup_charset           ; our own character set with 8 star shapes
        jsr setup_stars             ; put the stars at random columns

        lda #$20                    ; screen code $20 = space
        ldx #0                      ; X counts 0 to 255, then wraps back to 0
-       sta SCREEN,x                ; clear page 1 of screen memory
        sta SCREEN + $100,x         ; clear page 2
        sta SCREEN + $200,x         ; clear page 3
        sta SCREEN + $2e8,x         ; clear the last 256 bytes of the 1000 (stops before the sprite pointers at $07f8)
        inx                         ; next byte
        bne -                       ; until X wrapped around to 0

        ldx #0                      ; X = 0, index into the label text
-       lda score_label,x           ; one character of "score "
        sta SCREEN,x                ; put it on the top row
        inx                         ; next character
        cpx #6                      ; did we print all 6?
        bne -                       ; no, continue

        lda #COLOR_WHITE            ; A = white
        ldx #8                      ; 9 cells: "score " (6) plus 3 digits, counting down from 8
-       sta COLOR_RAM,x             ; make this character white
        dex                         ; previous cell
        bpl -                       ; until X goes below 0 (bit 7 set)

        ldx #2                      ; 3 characters: "hi ", counting down from 2
-       lda hi_label,x              ; one character of "hi "
        sta SCREEN + 31,x           ; put it on the top row, column 31
        dex                         ; previous character
        bpl -                       ; until X goes below 0
        lda #COLOR_WHITE            ; A = white
        ldx #5                      ; 6 cells: "hi " plus 3 digits, counting down from 5
-       sta COLOR_RAM + 31,x        ; make this character white
        dex                         ; previous cell
        bpl -                       ; until X goes below 0

        ldx #5                      ; 6 characters: "lives ", counting down
-       lda lives_label,x           ; one character of "lives "
        sta SCREEN + 18,x           ; put it on the top row, column 18
        dex                         ; previous character
        bpl -                       ; until X goes below 0
        lda #COLOR_WHITE            ; A = white
        ldx #6                      ; 7 cells: "lives " plus the digit, counting down
-       sta COLOR_RAM + 18,x        ; make this character white
        dex                         ; previous cell
        bpl -                       ; until X goes below 0

        jsr init_hiscore            ; keep the old high score if RAM has one, else 000, and draw it
        jsr reset_score             ; score = 000 and draw it
        jsr reset_lives             ; full lives and draw them
        jsr reset_difficulty        ; enemy starts at its slowest speed
        jsr title_screen            ; wait on the title until a key is pressed (it also switches the sprites on)
        jsr spawn_enemy             ; put the enemy at the top at a random X
        lda SPR_COLL               ; read the collision register once to clear leftovers

frame                               ; the game loop, runs once per screen refresh (50 Hz on PAL)
        lda #$fb                    ; the raster line we wait for (near the bottom of the screen)
-       cmp VIC_RASTER              ; is the beam on that line yet?
        bne -                       ; no, keep checking
-       cmp VIC_RASTER              ; yes, now wait until the beam has left that line
        beq -                       ; still on it, keep waiting (so we only run once per frame)

        inc frame_count             ; one more frame has passed

        lda frame_count             ; animation: switch frame every 8 frames
        lsr                         ; shift right 3 times so bit 3 of the counter ...
        lsr                         ; ... ends up in bit 0
        lsr                         ; (lsr alone on A shifts the accumulator)
        and #%00000001              ; 0 = frame A, 1 = frame B
        asl                         ; times 2, because frame B shapes sit 2 blocks further on
        ora #sprite_data / 64       ; 128 for frame A, 130 for frame B: the ship pointer
        sta SPRITE_PTR              ; ship shape for this frame
        ora #1                      ; +1 gives 129 or 131: the enemy pointer
        sta SPRITE1_PTR             ; enemy shape for this frame

        jsr update_stars            ; scroll the starfield down
        jsr update_music            ; play the next note when it is time

        jsr cia_inputs              ; the ports must be inputs every time (an emulator was seen to change port B)
        lda CIA1_PORTA              ; read the joystick, a 0 bit means the direction is pressed
        sta joy                     ; keep a copy, because we shift it bit by bit
!if SHOW_JOY = 1 {
        lda joy                     ; temporary test readout: the raw bits, 1 = not pressed, 0 = pressed
!for k, 0, 4 {
        pha                         ; keep the shifted value
        and #%00000001              ; the lowest bit only
        ora #$30                    ; make it the character '0' or '1'
        sta SCREEN + 12 + k         ; print it on the top row: up, down, left, right, fire
        pla                         ; get the value back
        lsr                         ; the next bit becomes the lowest
}
}

        lsr joy                     ; shift bit 0 (up) into the carry flag
        bcs +                       ; carry set = not pressed, skip the 'up' code
        lda SPR0_Y                  ; current Y
        cmp #MIN_Y                  ; already at the top?
        beq +                       ; yes, don't move
        dec SPR0_Y                  ; Y - 1 moves the sprite up
+       lsr joy                     ; shift bit 1 (down) into the carry flag
        bcs +                       ; carry set = not pressed, skip
        lda SPR0_Y                  ; current Y
        cmp #MAX_Y                  ; already at the bottom?
        beq +                       ; yes, don't move
        inc SPR0_Y                  ; Y + 1 moves the sprite down
+       lsr joy                     ; shift bit 2 (left) into the carry flag
        bcs +                       ; carry set = not pressed, skip
        jsr ship_left               ; X - 1 (9 bits), stops at the left edge
+       lsr joy                     ; shift bit 3 (right) into the carry flag
        bcs +                       ; carry set = not pressed, skip
        jsr ship_right              ; X + 1 (9 bits), stops at the right edge
+
        lda frame_count             ; homing: only on every other frame, so the enemy is slower than the ship
        and #%00000001              ; keep only the lowest bit, it is 1 on every other frame
        beq +                       ; 0 = skip homing this frame
        jsr home_enemy              ; one pixel towards the ship
+
        lda SPR1_Y                  ; current enemy Y
        clc                         ; clear carry before adding
        adc enemy_speed             ; fall as fast as the current level allows
        sta SPR1_Y                  ; store the new enemy Y
        cmp #MAX_Y                  ; has it reached the bottom?
        bcc +                       ; no (A < MAX_Y), carry on
        jsr add_score               ; the enemy got past us: +1 point
        jsr update_hiscore          ; if that beat the high score, it becomes the new one
        lda #$03                    ; attack 0, decay 3: a short blip
        sta SID_AD1                 ; voice 1 envelope
        lda #$00                    ; sustain 0 (the bass leaves it at 6, which would hold the blip), release 0
        sta SID_SR1                 ; voice 1 envelope part 2
        lda #$00                    ; the bass may have left a low byte behind
        sta SID_FREQ1L              ; voice 1 frequency, low byte
        lda #$50                    ; a high pitch
        sta SID_FREQ1H              ; voice 1 frequency
        lda #%00010000              ; triangle waveform, gate off (resets the envelope)
        sta SID_CTRL1               ; voice 1 stops
        lda #%00010001              ; triangle waveform, gate on
        sta SID_CTRL1               ; gate 0 to 1 starts the blip
        lda #SFX_FRAMES             ; the bass keeps quiet for a moment
        sta sfx_timer
        jsr count_dodge             ; every 10 dodges the enemy speeds up
        jsr spawn_enemy             ; respawn it at the top
+
        lda SPR_COLL                ; which sprites touched? (reading also clears the register)
        and #%00000011              ; keep only the bits of the ship and the enemy
        cmp #%00000011              ; are both set, so do they overlap?
        bne +                       ; no, no hit
        lda #COLOR_RED              ; hit! red
        sta VIC_BORDER              ; flash the border
        lda #HIT_FRAMES             ; how long to flash
        sta hit_timer               ; start the flash timer
        lda #$09                    ; decay 9: the long rumble (the dodge blip uses a shorter one)
        sta SID_AD1                 ; voice 1 envelope
        lda #$00                    ; sustain 0 (the bass leaves it at 6), release 0
        sta SID_SR1                 ; voice 1 envelope part 2
        lda #$00                    ; the bass may have left a low byte behind
        sta SID_FREQ1L              ; voice 1 frequency, low byte
        lda #$08                    ; low pitch for a crunchy noise
        sta SID_FREQ1H              ; voice 1 frequency
        lda #%10000000              ; noise waveform, gate off (this resets the envelope)
        sta SID_CTRL1               ; voice 1 stops
        lda #%10000001              ; noise waveform, gate on
        sta SID_CTRL1               ; gate 0 to 1 starts the explosion sound
        lda #SFX_FRAMES             ; the bass keeps quiet for a moment
        sta sfx_timer
        dec lives                   ; a hit costs a life (the score and the speed stay)
        jsr draw_lives              ; show it
        lda lives                   ; any left?
        bne life_left               ; yes, carry on
        lda #$00                    ; no, game over: black
        sta VIC_BORDER              ; stop the flash
        sta hit_timer               ; ... for good
        jsr game_over               ; show it until a key is pressed (the high score stays)
        jsr reset_score             ; new game: score = 000
        jsr reset_lives             ; ... full lives
        jsr reset_difficulty        ; ... and the enemy is slow again
        jsr reset_ship              ; ... and the ship in its start position
life_left
        jsr spawn_enemy             ; send the enemy back to the top
        lda SPR_COLL                ; clear the collision register
+
        lda hit_timer               ; is the border flashing?
        beq +                       ; no, nothing to do
        dec hit_timer               ; one frame less to go
        bne +                       ; still counting down
        lda #$00                    ; timer just ran out, black
        sta VIC_BORDER              ; border back to normal
+
        jmp frame                   ; back to the top for the next frame

; The rest of the program. The order here is the order in memory: code first, then data, then sprites.
        !source "src/actors.asm"    ; ship and enemy movement, spawning, difficulty
        !source "src/score.asm"     ; score and high score
        !source "src/starfield.asm" ; character set, stars and the random column helper
        !source "src/music.asm"     ; the tune
        !source "src/title.asm"     ; the title screen and the any-key check
        !source "src/demo.asm"      ; raster bars, bouncing letters, scroller
        !source "src/data.asm"      ; tables and text
        !source "src/sprites.asm"   ; the ship and enemy shapes, they sit at $2000
