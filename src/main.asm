; raster-rumble - step 3: move the ship with the joystick (port 2), dodge a falling enemy
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

ENEMY_SPEED = 2                     ; pixels the enemy falls per frame
HIT_FRAMES  = 10                    ; how many frames the border stays red after a hit
COLOR_RED   = 2                     ; C64 colour number for red

joy       = $02                     ; a spare zero-page byte where we keep a copy of the joystick
hit_timer = $03                     ; frames left to show the red border (0 = not flashing)

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
        lda #1                      ; colour 1 = white
        sta SPR0_COLOR              ; sprite 0 (ship) is white
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
        jsr spawn_enemy             ; put the enemy at the top at a random X
        lda SPR_COLL                ; read the collision register once to clear leftovers

frame                               ; the game loop, runs once per screen refresh (50 Hz on PAL)
        lda #$fb                    ; the raster line we wait for (near the bottom of the screen)
-       cmp VIC_RASTER              ; is the beam on that line yet?
        bne -                       ; no, keep checking
-       cmp VIC_RASTER              ; yes, now wait until the beam has left that line
        beq -                       ; still on it, keep waiting (so we only run once per frame)

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
        lda SPR1_Y                  ; current enemy Y
        clc                         ; clear carry before adding
        adc #ENEMY_SPEED            ; fall a few pixels
        sta SPR1_Y                  ; store the new enemy Y
        cmp #MAX_Y                  ; has it reached the bottom?
        bcc +                       ; no (A < MAX_Y), carry on
        jsr spawn_enemy             ; yes, respawn it at the top
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

        * = $2000                   ; the sprite shape goes at $2000 (= 128 * 64)

sprite_data                         ; 24 pixels wide x 21 rows, 3 bytes per row, 1 bit = 1 pixel
        !byte %00000000, %00011000, %00000000   ; row 1:  nose of the ship
        !byte %00000000, %00011000, %00000000   ; row 2
        !byte %00000000, %00111100, %00000000   ; row 3
        !byte %00000000, %00111100, %00000000   ; row 4
        !byte %00000000, %01111110, %00000000   ; row 5
        !byte %00000000, %01111110, %00000000   ; row 6
        !byte %00000000, %11111111, %00000000   ; row 7
        !byte %00000001, %11111111, %10000000   ; row 8:  wings start
        !byte %00000001, %11111111, %10000000   ; row 9
        !byte %00000011, %11111111, %11000000   ; row 10
        !byte %00000011, %11111111, %11000000   ; row 11
        !byte %00000111, %11100111, %11100000   ; row 12: gap opens at the tail
        !byte %00000111, %11000011, %11100000   ; row 13
        !byte %00001111, %11000011, %11110000   ; row 14
        !byte %00001111, %10000001, %11110000   ; row 15
        !byte %00011111, %10000001, %11111000   ; row 16
        !byte %00011111, %00000000, %11111000   ; row 17
        !byte %00011110, %00000000, %01111000   ; row 18
        !byte %00011100, %00000000, %00111000   ; row 19
        !byte %00011000, %00000000, %00011000   ; row 20
        !byte %00010000, %00000000, %00001000   ; row 21: wing tips
        !byte 0                     ; one padding byte, sprite blocks are 64 bytes (63 used)

enemy_data                          ; the enemy shape, directly after the ship: $2040 = 129 * 64
        !byte %00000000, %00011000, %00000000   ; row 1:  top of the diamond
        !byte %00000000, %00111100, %00000000   ; row 2
        !byte %00000000, %01111110, %00000000   ; row 3
        !byte %00000000, %11111111, %00000000   ; row 4
        !byte %00000001, %11111111, %10000000   ; row 5
        !byte %00000011, %11111111, %11000000   ; row 6
        !byte %00000111, %11111111, %11100000   ; row 7
        !byte %00001111, %11111111, %11110000   ; row 8
        !byte %00011111, %11111111, %11111000   ; row 9
        !byte %00111111, %11111111, %11111100   ; row 10: widest row
        !byte %00011111, %11111111, %11111000   ; row 11
        !byte %00001111, %11111111, %11110000   ; row 12
        !byte %00000111, %11111111, %11100000   ; row 13
        !byte %00000011, %11111111, %11000000   ; row 14
        !byte %00000001, %11111111, %10000000   ; row 15
        !byte %00000000, %11111111, %00000000   ; row 16
        !byte %00000000, %01111110, %00000000   ; row 17
        !byte %00000000, %00111100, %00000000   ; row 18
        !byte %00000000, %00011000, %00000000   ; row 19: bottom of the diamond
        !byte %00000000, %00000000, %00000000   ; row 20: empty
        !byte %00000000, %00000000, %00000000   ; row 21: empty
        !byte 0                     ; one padding byte, sprite blocks are 64 bytes (63 used)
