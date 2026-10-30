; raster-rumble - step 4: move the ship with the joystick (port 2), dodge a falling enemy, keep score
; Assembler: ACME
;
; 6502 refresher:
;   A = accumulator, X/Y = index registers (unused here)
;   lda = load A, sta = store A, cmp = compare A (sets flags, A unchanged)
;   beq/bne = branch if equal/not equal (zero flag), bcs/bcc = branch if carry set/clear
;   lsr = shift right, the bit that falls off the end goes into the carry flag
;   inc/dec = add/subtract 1 directly in memory
;   '#' means a literal number, no '#' means "the contents of that address"
; ACME refresher:
;   '!byte' / '!word' / '!text' place data, '+' and '-' are anonymous labels
;   (a branch to '+' goes to the next '+' below, a branch to '-' to the previous '-' above)

        * = $0801                   ; BASIC programs always start loading here

; BASIC stub: "10 SYS 2064", so typing RUN jumps into our machine code
        !word basic_end, 10         ; pointer to the next BASIC line, then line number 10
        !byte $9e                   ; BASIC token for the SYS command
        !text "2064"                ; the address of 'start' as decimal text (checked below)
        !byte 0                     ; end of this BASIC line
basic_end
        !word 0                     ; end of the BASIC program (a pointer of 0)

; Names for the hardware registers (VIC-II video chip and CIA 1 I/O chip)
SPRITE_PTR = $07f8                  ; sprite 0 data pointer, value * 64 = address of its shape
SPRITE1_PTR = $07f9                 ; sprite 1 data pointer
SPR0_X     = $d000                  ; sprite 0 X position (low 8 bits)
SPR0_Y     = $d001                  ; sprite 0 Y position
SPR1_X     = $d002                  ; sprite 1 (the enemy) X position
SPR1_Y     = $d003                  ; sprite 1 Y position
SPR_ENABLE = $d015                  ; one bit per sprite: 1 = visible
SPR_COLL   = $d01e                  ; sprite-sprite collision, one bit per sprite, cleared when read
SPR0_COLOR = $d027                  ; sprite 0 colour (0-15)
SPR1_COLOR = $d028                  ; sprite 1 colour (0-15)
VIC_RASTER = $d012                  ; the raster line the beam is currently drawing
VIC_BORDER = $d020                  ; border colour
VIC_BG     = $d021                  ; background colour
CIA1_PORTA = $dc00                  ; joystick port 2, bits are 0 when pressed: up, down, left, right, fire
SID_FREQ1L = $d400                  ; SID voice 1 frequency, low byte
SID_FREQ1H = $d401                  ; SID voice 1 frequency, high byte
SID_CTRL1  = $d404                  ; SID voice 1 control (bit 7 = noise, bit 0 = gate: 0 to 1 starts the sound)
SID_AD1    = $d405                  ; SID voice 1 attack (high nibble) and decay (low nibble)
SID_SR1    = $d406                  ; SID voice 1 sustain (high nibble) and release (low nibble)
SID_VOLUME = $d418                  ; SID master volume (low nibble), bit 7 = mute voice 3
SID_FREQ3L = $d40e                  ; SID voice 3 frequency, low byte
SID_FREQ3H = $d40f                  ; SID voice 3 frequency, high byte
SID_CTRL3  = $d412                  ; SID voice 3 control (bit 7 = noise waveform)
SID_OSC3   = $d41b                  ; SID voice 3 oscillator output, with noise this is a random byte

; Limits so the sprite stays in the visible part of the screen
MIN_X = 24                          ; left edge of the screen area
MAX_X = 250                         ; right edge (we only use the low 8 bits of X, so max is 255)
MIN_Y = 50                          ; top edge of the screen area
MAX_Y = 229                         ; bottom edge

ENEMY_SPEED = 2                     ; pixels the enemy falls per frame at the start of a game
MAX_SPEED   = 5                     ; the enemy never falls faster than this
DODGES_PER_LEVEL = 10               ; every 10 dodged enemies the enemy gets 1 pixel per frame faster
HIT_FRAMES  = 10                    ; how many frames the border stays red after a hit
COLOR_RED   = 2                     ; C64 colour number for red
COLOR_ORANGE = 8                    ; C64 colour number for orange
COLOR_YELLOW = 7                    ; C64 colour number for yellow
SPR_MULTI  = $d01c                  ; one bit per sprite: 1 = multicolor sprite
SPR_MC0    = $d025                  ; multicolor 0, shared by all sprites (bit pair 01)
SPR_MC1    = $d026                  ; multicolor 1, shared by all sprites (bit pair 11)

SCREEN     = $0400                  ; screen memory, 40x25 characters, one byte per character
COLOR_RAM  = $d800                  ; colour memory, one byte per character, same layout as the screen
SCORE_POS  = SCREEN + 6             ; where the three score digits are printed (after the word "score ")
COLOR_WHITE = 1                     ; C64 colour number for white
HI_POS     = SCREEN + 34            ; where the three high score digits are printed (after "hi " at column 31)

; The high score lives at $c000, a free RAM block outside our program and the zero page.
; Nothing loads over it or clears it, so it survives hits, a restart with RUN and a reload.
; A power-off wipes it, which is why a magic byte says whether the bytes are valid.
hi_score   = $c000                  ; three bytes, $c000 $c001 $c002: hundreds, tens, ones (each 0-9)
hi_magic   = $c003                  ; holds HI_MAGIC once hi_score has been set up
HI_MAGIC   = $a5                    ; any value that random power-on RAM is unlikely to hold

joy       = $02                     ; a spare zero-page byte where we keep a copy of the joystick
hit_timer = $03                     ; frames left to show the red border (0 = not flashing)
score     = $04                     ; three bytes, $04 $05 $06: hundreds, tens, ones (each 0-9)
enemy_speed = $07                   ; pixels the enemy falls per frame right now (ENEMY_SPEED up to MAX_SPEED)
dodge_count = $08                   ; dodged enemies since the last speed-up (0 to DODGES_PER_LEVEL - 1)
frame_count = $09                   ; counts frames, its lowest bit flips every frame (used to slow the homing)

        * = $0810                   ; our code lives here (decimal 2064, matches the SYS above)

start
        !if start != 2064 {         ; safety net: the BASIC stub text must match this address
            !error "start is not at 2064, update the SYS text in the BASIC stub"
        }
        sei                         ; disable interrupts, we poll the hardware ourselves
        lda #$00                    ; A = 0 (colour black)
        sta VIC_BORDER              ; border = black
        sta VIC_BG                  ; background = black

        lda #sprite_data / 64       ; sprite shape address divided by 64 = pointer value (128)
        sta SPRITE_PTR              ; tell the VIC sprite 0 uses that shape
        lda #enemy_data / 64        ; enemy shape address divided by 64 = pointer value (129)
        sta SPRITE1_PTR             ; tell the VIC sprite 1 uses that shape
        lda #%00000011              ; bits 0 and 1 set = sprites 0 and 1 on
        sta SPR_ENABLE              ; show the ship and the enemy
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
        lda #200                    ; start Y: near the bottom
        sta SPR0_Y                  ; set ship Y

        lda #$ff                    ; maximum frequency, so the noise changes quickly
        sta SID_FREQ3L              ; SID voice 3 frequency low byte
        sta SID_FREQ3H              ; SID voice 3 frequency high byte
        lda #%10000000              ; bit 7 = noise waveform (gate stays off, we only read it)
        sta SID_CTRL3               ; start voice 3 as a random number generator

        lda #%10001111              ; volume 15 (max), bit 7 mutes voice 3 so the random noise stays silent
        sta SID_VOLUME              ; switch the sound on
        lda #$09                    ; attack 0 (instant), decay 9 (about 0.75 seconds)
        sta SID_AD1                 ; voice 1 envelope part 1
        lda #$00                    ; sustain 0 (silent once decayed), release 0
        sta SID_SR1                 ; voice 1 envelope part 2
        lda #$08                    ; a fairly high pitch, for a crunchy noise
        sta SID_FREQ1H              ; voice 1 frequency high byte (low byte stays 0)

        lda #0                      ; A = 0
        sta hit_timer               ; border is not flashing yet

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

        jsr init_hiscore            ; keep the old high score if RAM has one, else 000, and draw it
        jsr reset_score             ; score = 000 and draw it
        jsr reset_difficulty        ; enemy starts at its slowest speed
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

        lda CIA1_PORTA              ; read the joystick, a 0 bit means the direction is pressed
        sta joy                     ; keep a copy, because we shift it bit by bit

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
        lda SPR0_X                  ; current X
        cmp #MIN_X                  ; already at the left edge?
        beq +                       ; yes, don't move
        dec SPR0_X                  ; X - 1 moves the sprite left
+       lsr joy                     ; shift bit 3 (right) into the carry flag
        bcs +                       ; carry set = not pressed, skip
        lda SPR0_X                  ; current X
        cmp #MAX_X                  ; already at the right edge?
        beq +                       ; yes, don't move
        inc SPR0_X                  ; X + 1 moves the sprite right
+
        lda frame_count             ; homing: only on every other frame, so the enemy is slower than the ship
        and #%00000001              ; keep only the lowest bit, it is 1 on every other frame
        beq +                       ; 0 = skip homing this frame
        lda SPR1_X                  ; enemy X
        cmp SPR0_X                  ; compare with the ship X (carry set if enemy X >= ship X)
        beq +                       ; same X, nothing to do
        bcs .home_left              ; the enemy is right of the ship, so move it left
        inc SPR1_X                  ; the enemy is left of the ship, so move it right
        jmp +                       ; done with homing
.home_left
        dec SPR1_X                  ; X - 1 moves the enemy left
+
        lda SPR1_Y                  ; current enemy Y
        clc                         ; clear carry before adding
        adc enemy_speed             ; fall as fast as the current level allows
        sta SPR1_Y                  ; store the new enemy Y
        cmp #MAX_Y                  ; has it reached the bottom?
        bcc +                       ; no (A < MAX_Y), carry on
        jsr add_score               ; the enemy got past us: +1 point
        jsr update_hiscore          ; if that beat the high score, it becomes the new one
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
        lda #%10000000              ; noise waveform, gate off (this resets the envelope)
        sta SID_CTRL1               ; voice 1 stops
        lda #%10000001              ; noise waveform, gate on
        sta SID_CTRL1               ; gate 0 to 1 starts the explosion sound
        jsr reset_score             ; a hit costs you the score
        jsr reset_difficulty        ; ... and the enemy is slow again
        jsr spawn_enemy             ; send the enemy back to the top
+
        lda hit_timer               ; is the border flashing?
        beq +                       ; no, nothing to do
        dec hit_timer               ; one frame less to go
        bne +                       ; still counting down
        lda #$00                    ; timer just ran out, black
        sta VIC_BORDER              ; border back to normal
+
        jmp frame                   ; back to the top for the next frame

spawn_enemy                         ; subroutine: enemy to the top, random X in the visible range
        lda #MIN_Y - 10             ; just above the visible area, so it slides in
        sta SPR1_Y                  ; set enemy Y
-       lda SID_OSC3                ; random byte from the SID noise
        cmp #MIN_X                  ; too far left?
        bcc -                       ; yes, pick another
        cmp #MAX_X                  ; too far right?
        bcs -                       ; yes, pick another
        sta SPR1_X                  ; set enemy X
        rts                         ; return to the caller

!zone count_dodge                   ; ACME: '.labels' are local to a zone, so each subroutine gets its own
count_dodge                         ; subroutine: after every 10th dodge the enemy gets faster
        inc dodge_count             ; one more dodge
        lda dodge_count             ; load it to compare
        cmp #DODGES_PER_LEVEL       ; reached 10?
        bcc .done                   ; no, finished
        lda #0                      ; yes: start counting again ...
        sta dodge_count             ; ... from 0
        lda enemy_speed             ; current speed
        cmp #MAX_SPEED              ; already at the maximum?
        bcs .done                   ; yes, leave it
        inc enemy_speed             ; no, one pixel per frame faster
.done
        rts                         ; return to the caller

reset_difficulty                    ; subroutine: back to the slow start speed
        lda #ENEMY_SPEED            ; the starting speed
        sta enemy_speed             ; set it
        lda #0                      ; A = 0
        sta dodge_count             ; no dodges counted yet
        rts                         ; return to the caller

!zone add_score                     ; a new zone, so this '.done' is a different label than the one above
add_score                           ; subroutine: score + 1, three decimal digits, stops at 999
        inc score + 2               ; ones + 1
        lda score + 2               ; load it to compare
        cmp #10                     ; still 0-9?
        bcc .done                   ; yes, finished
        lda #0                      ; ones overflowed: back to 0 ...
        sta score + 2               ; ... store it
        inc score + 1               ; ... and tens + 1
        lda score + 1               ; load it to compare
        cmp #10                     ; still 0-9?
        bcc .done                   ; yes, finished
        lda #0                      ; tens overflowed: back to 0 ...
        sta score + 1               ; ... store it
        inc score                   ; ... and hundreds + 1
        lda score                   ; load it to compare
        cmp #10                     ; still 0-9?
        bcc .done                   ; yes, finished
        lda #9                      ; we reached 1000: stay at 999
        sta score                   ; hundreds = 9
        sta score + 1               ; tens = 9
        sta score + 2               ; ones = 9
.done
        jmp draw_score              ; show the new score (draw_score returns to our caller)

reset_score                         ; subroutine: score = 000
        lda #0                      ; A = 0
        sta score                   ; hundreds = 0
        sta score + 1               ; tens = 0
        sta score + 2               ; ones = 0
        jmp draw_score              ; show it (draw_score returns to our caller)

draw_score                          ; subroutine: print the three digits on the screen
        lda score                   ; hundreds digit, a number 0-9
        ora #$30                    ; screen code for '0' is $30, so $30 + digit is the character
        sta SCORE_POS               ; print it
        lda score + 1               ; tens digit
        ora #$30                    ; turn the number into a character
        sta SCORE_POS + 1           ; print it
        lda score + 2               ; ones digit
        ora #$30                    ; turn the number into a character
        sta SCORE_POS + 2           ; print it
        rts                         ; return to the caller

!zone init_hiscore
init_hiscore                        ; subroutine: validate the high score in RAM, then draw it
        lda hi_magic                ; is our signature there?
        cmp #HI_MAGIC               ; compare with the expected value
        beq .draw                   ; yes, the old high score is valid, keep it
        lda #0                      ; no (fresh power-on): A = 0
        sta hi_score                ; hundreds = 0
        sta hi_score + 1            ; tens = 0
        sta hi_score + 2            ; ones = 0
        lda #HI_MAGIC               ; now sign it ...
        sta hi_magic                ; ... so the next start keeps it
.draw
        jmp draw_hiscore            ; show it (draw_hiscore returns to our caller)

!zone update_hiscore
update_hiscore                      ; subroutine: if score > hi_score, copy score into hi_score
        lda score                   ; compare hundreds first, the most significant digit
        cmp hi_score                ; carry clear if score < hi_score
        bcc .done                   ; lower, so no new record
        bne .copy                   ; higher, so a new record
        lda score + 1               ; hundreds equal: compare tens
        cmp hi_score + 1            ; same test
        bcc .done                   ; lower
        bne .copy                   ; higher
        lda score + 2               ; tens equal too: compare ones
        cmp hi_score + 2            ; same test
        bcc .done                   ; lower
        beq .done                   ; all equal: not a new record
.copy
        lda score                   ; copy the three digits
        sta hi_score                ; hundreds
        lda score + 1               ; tens
        sta hi_score + 1            ; store it
        lda score + 2               ; ones
        sta hi_score + 2            ; store it
        jmp draw_hiscore            ; show it (draw_hiscore returns to our caller)
.done
        rts                         ; return to the caller

draw_hiscore                        ; subroutine: print the three high score digits
        lda hi_score                ; hundreds digit, a number 0-9
        ora #$30                    ; turn the number into a character
        sta HI_POS                  ; print it
        lda hi_score + 1            ; tens digit
        ora #$30                    ; turn the number into a character
        sta HI_POS + 1              ; print it
        lda hi_score + 2            ; ones digit
        ora #$30                    ; turn the number into a character
        sta HI_POS + 2              ; print it
        rts                         ; return to the caller

score_label
        !scr "score "               ; 6 characters, !scr converts them to C64 screen codes
hi_label
        !scr "hi "                  ; 3 characters, printed at column 31

        * = $2000                   ; sprite shapes start here (= 128 * 64)
; Multicolor sprite pixel pairs: 00 transparent, 01 multicolor 0 (orange), 10 the sprite's own colour,
; 11 multicolor 1 (yellow). In the art: . = 00, a = 01, b = 10, c = 11.

sprite_data                         ; ship frame A at $2000 = 128 * 64, multicolor: 12 pixels wide, 2 bits each
        !byte %00000000, %00101000, %00000000   ;  1 .....bb.....
        !byte %00000000, %00101000, %00000000   ;  2 .....bb.....
        !byte %00000000, %10101010, %00000000   ;  3 ....bbbb....
        !byte %00000000, %10101010, %00000000   ;  4 ....bbbb....
        !byte %00000000, %10111110, %00000000   ;  5 ....bccb....
        !byte %00000010, %10111110, %10000000   ;  6 ...bbccbb...
        !byte %00000010, %10101010, %10000000   ;  7 ...bbbbbb...
        !byte %00001010, %10101010, %10100000   ;  8 ..bbbbbbbb..
        !byte %00101010, %10101010, %10101000   ;  9 .bbbbbbbbbb.
        !byte %00101010, %10101010, %10101000   ; 10 .bbbbbbbbbb.
        !byte %10101010, %10101010, %10101010   ; 11 bbbbbbbbbbbb
        !byte %10101001, %10101010, %01101010   ; 12 bbbabbbbabbb
        !byte %10100010, %10101010, %10001010   ; 13 bb.bbbbbb.bb
        !byte %10000010, %10101010, %10000010   ; 14 b..bbbbbb..b
        !byte %10000010, %10101010, %10000010   ; 15 b..bbbbbb..b
        !byte %00000010, %10000010, %10000000   ; 16 ...bb..bb...
        !byte %00000010, %01000001, %10000000   ; 17 ...ba..ab...
        !byte %00000000, %01010101, %00000000   ; 18 ....aaaa....
        !byte %00000000, %01111101, %00000000   ; 19 ....acca....
        !byte %00000000, %00111100, %00000000   ; 20 .....cc.....
        !byte %00000000, %00000000, %00000000   ; 21 ............
        !byte 0                     ; padding, sprite blocks are 64 bytes (63 used)

enemy_data                          ; enemy frame A at $2040 = 129 * 64
        !byte %01000000, %00000000, %00000001   ;  1 a..........a
        !byte %01010000, %00000000, %00000101   ;  2 aa........aa
        !byte %00010100, %10101010, %00010100   ;  3 .aa.bbbb.aa.
        !byte %00000110, %10101010, %10010000   ;  4 ..abbbbbba..
        !byte %00001010, %10101010, %10100000   ;  5 ..bbbbbbbb..
        !byte %00101010, %10101010, %10101000   ;  6 .bbbbbbbbbb.
        !byte %00101011, %11101011, %11101000   ;  7 .bbccbbccbb.
        !byte %10101011, %11101011, %11101010   ;  8 bbbccbbccbbb
        !byte %10101011, %11101011, %11101010   ;  9 bbbccbbccbbb
        !byte %10101010, %10101010, %10101010   ; 10 bbbbbbbbbbbb
        !byte %00101010, %10101010, %10101000   ; 11 .bbbbbbbbbb.
        !byte %00101001, %10101010, %01101000   ; 12 .bbabbbbabb.
        !byte %00001010, %01010101, %10100000   ; 13 ..bbaaaabb..
        !byte %00001010, %10101010, %10100000   ; 14 ..bbbbbbbb..
        !byte %00000010, %00101000, %10000000   ; 15 ...b.bb.b...
        !byte %00000010, %00101000, %10000000   ; 16 ...b.bb.b...
        !byte %00000100, %00101000, %00010000   ; 17 ..a..bb..a..
        !byte %00000100, %00000000, %00010000   ; 18 ..a......a..
        !byte %00000000, %00000000, %00000000   ; 19 ............
        !byte %00000000, %00000000, %00000000   ; 20 ............
        !byte %00000000, %00000000, %00000000   ; 21 ............
        !byte 0                     ; padding, sprite blocks are 64 bytes (63 used)

ship_data_b                         ; ship frame B at $2080 = 130 * 64 (shorter flame)
        !byte %00000000, %00101000, %00000000   ;  1 .....bb.....
        !byte %00000000, %00101000, %00000000   ;  2 .....bb.....
        !byte %00000000, %10101010, %00000000   ;  3 ....bbbb....
        !byte %00000000, %10101010, %00000000   ;  4 ....bbbb....
        !byte %00000000, %10111110, %00000000   ;  5 ....bccb....
        !byte %00000010, %10111110, %10000000   ;  6 ...bbccbb...
        !byte %00000010, %10101010, %10000000   ;  7 ...bbbbbb...
        !byte %00001010, %10101010, %10100000   ;  8 ..bbbbbbbb..
        !byte %00101010, %10101010, %10101000   ;  9 .bbbbbbbbbb.
        !byte %00101010, %10101010, %10101000   ; 10 .bbbbbbbbbb.
        !byte %10101010, %10101010, %10101010   ; 11 bbbbbbbbbbbb
        !byte %10101001, %10101010, %01101010   ; 12 bbbabbbbabbb
        !byte %10100010, %10101010, %10001010   ; 13 bb.bbbbbb.bb
        !byte %10000010, %10101010, %10000010   ; 14 b..bbbbbb..b
        !byte %10000010, %10101010, %10000010   ; 15 b..bbbbbb..b
        !byte %00000010, %10000010, %10000000   ; 16 ...bb..bb...
        !byte %00000010, %01000001, %10000000   ; 17 ...ba..ab...
        !byte %00000000, %00010100, %00000000   ; 18 .....aa.....
        !byte %00000000, %00111100, %00000000   ; 19 .....cc.....
        !byte %00000000, %00000000, %00000000   ; 20 ............
        !byte %00000000, %00000000, %00000000   ; 21 ............
        !byte 0                     ; padding, sprite blocks are 64 bytes (63 used)

enemy_data_b                        ; enemy frame B at $20c0 = 131 * 64 (spikes flapped)
        !byte %00000000, %00000000, %00000000   ;  1 ............
        !byte %01000000, %00000000, %00000001   ;  2 a..........a
        !byte %01010000, %10101010, %00000101   ;  3 aa..bbbb..aa
        !byte %00010110, %10101010, %10010100   ;  4 .aabbbbbbaa.
        !byte %00001010, %10101010, %10100000   ;  5 ..bbbbbbbb..
        !byte %00101010, %10101010, %10101000   ;  6 .bbbbbbbbbb.
        !byte %00101011, %11101011, %11101000   ;  7 .bbccbbccbb.
        !byte %10101011, %11101011, %11101010   ;  8 bbbccbbccbbb
        !byte %10101011, %11101011, %11101010   ;  9 bbbccbbccbbb
        !byte %10101010, %10101010, %10101010   ; 10 bbbbbbbbbbbb
        !byte %00101010, %10101010, %10101000   ; 11 .bbbbbbbbbb.
        !byte %00101001, %10101010, %01101000   ; 12 .bbabbbbabb.
        !byte %00001010, %01010101, %10100000   ; 13 ..bbaaaabb..
        !byte %00001010, %10101010, %10100000   ; 14 ..bbbbbbbb..
        !byte %00001000, %00101000, %00100000   ; 15 ..b..bb..b..
        !byte %00010000, %00101000, %00000100   ; 16 .a...bb...a.
        !byte %00010000, %00000000, %00000100   ; 17 .a........a.
        !byte %00000000, %00000000, %00000000   ; 18 ............
        !byte %00000000, %00000000, %00000000   ; 19 ............
        !byte %00000000, %00000000, %00000000   ; 20 ............
        !byte %00000000, %00000000, %00000000   ; 21 ............
        !byte 0                     ; padding, sprite blocks are 64 bytes (63 used)
