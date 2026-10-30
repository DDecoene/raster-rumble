; raster-rumble - step 2: a sprite you can move with the joystick (port 2)
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
SPR0_X     = $d000                  ; sprite 0 X position (low 8 bits)
SPR0_Y     = $d001                  ; sprite 0 Y position
SPR_ENABLE = $d015                  ; one bit per sprite: 1 = visible
SPR0_COLOR = $d027                  ; sprite 0 colour (0-15)
VIC_RASTER = $d012                  ; the raster line the beam is currently drawing
VIC_BORDER = $d020                  ; border colour
VIC_BG     = $d021                  ; background colour
CIA1_PORTA = $dc00                  ; joystick port 2, bits are 0 when pressed: up, down, left, right, fire

; Limits so the sprite stays in the visible part of the screen
MIN_X = 24                          ; left edge of the screen area
MAX_X = 250                         ; right edge (we only use the low 8 bits of X, so max is 255)
MIN_Y = 50                          ; top edge of the screen area
MAX_Y = 229                         ; bottom edge

joy = $02                           ; a spare zero-page byte where we keep a copy of the joystick

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
        lda #%00000001              ; bit 0 set = sprite 0 on
        sta SPR_ENABLE              ; show sprite 0
        lda #1                      ; colour 1 = white
        sta SPR0_COLOR              ; sprite 0 is white
        lda #160                    ; start X: roughly the middle
        sta SPR0_X                  ; set sprite X
        lda #140                    ; start Y: roughly the middle
        sta SPR0_Y                  ; set sprite Y

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
        jmp frame                   ; back to the top for the next frame

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
