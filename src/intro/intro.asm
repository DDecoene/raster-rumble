; intro.asm - the intro of the film, shot by shot (see docs/story.md). A program of its own, the game is not in it.
; The title, then the shots, then the title again; fire starts the game (for now: 23:00 on the clock, then the title).
; The picture is made by tools/intro-room.py. All seven colour screens are in memory at the same time, so the light
; changes by pointing the VIC at another screen: one write to VIC_MEMCTL.

        * = $0801
        !word basic_end, 10         ; BASIC: 10 SYS 2064
        !byte $9e
        !text "2064"
        !byte 0
basic_end
        !word 0

        !source "src/hardware.asm"

CIA2_PORTA = $dd00                  ; bits 0-1: which 16 KB the VIC sees (%10 = $4000-$7fff)
ROOM      = $4000                   ; room.bin: seven colour screens, the sprites, the bitmap
HEAD_X    = 180                     ; where the head is (sprite coordinates)
HEAD_Y    = 146
TEXT_LEN  = 27                      ; the letters of the sentence
BAR       = 21 * 40                 ; the first character row of the bar below the picture
TEXT1     = 40 + 6                  ; shot 1: where the sentence starts, counted from BAR: row 22, column 6
TEXT2A    = 11                      ; shot 2: "It does not work.", row 21, column 11
TEXT2B    = 80 + 9                  ; shot 2: "He does not know why.", row 23, column 9
LEN2A     = 17                      ; their letters
LEN2B     = 21
DREAM     = $c000                   ; dream.bin: the screen, the sprites, the characters, the stars (see tools/intro-dream.py)
DREAM_PTR = DREAM + $3f8            ; its sprite pointers; sprite 0 of dream.bin is number 16
STARS     = 48
MIDDLE    = 137                     ; the raster line where the eyelids meet
DOOR      = $8000                   ; door.bin: three colour screens, the sprites; its bitmap is at $a000
BED       = $3800                   ; bed.bin: the cells that change when he is in bed
TEXT3     = 40 + 14                 ; shot 3: "Bed. Now." with its quotes, row 22, column 14
TEXTS     = $1800                   ; text.bin: $600 bytes per shot
BAR_BITS  = $6000 + 21 * 320        ; the bar in the bitmap
CLOCK_BITS = $6000 + 13 * 320 + 33 * 8 ; the figures of the clock in the bitmap
HUM       = 7                       ; the volume when everything is on (0-15), keys and hum together

frame     = $02                     ; frames since the shot began, 2 bytes
typed     = $04                     ; letters on the screen
wait      = $05                     ; frames until the next letter
light     = $06                     ; the colour screen that shows (0-6)
nod       = $07                     ; frames the head stays one line lower
rnd       = $08                     ; random number
look      = $09                     ; how far the head is turned to the magazine, in pixels
random_light = $0a                  ; frames left of a flicker
shot      = $0b                     ; 0 = shot 1, 1 = shot 2, 2 = the door, 3 = the bed (both shot 3), 4 = the clock and the eyelids, 5 = the dream (both shot 4), 6 = the title, 7 = the game starts, 8 = he starts to dream (between 4 and 5)
sink      = $0c                     ; how far the head hangs down, in lines
beat      = $0d                     ; frame / 4 (not in shot 1)
lid       = $11                     ; how far the eye is open: raster lines above and below MIDDLE
slit      = $12                     ; the background colour between the eyelids
star      = $13                     ; the first star of this frame: half of them move in a frame
fire      = $14                     ; 1 = fire was down in the last frame
beam_y    = $15                     ; the raster line of the beam
beam_row  = $16                     ; the title: which of its rows the beam lights
drawn     = $17                     ; 1 = the beam has drawn the title
DREAM_WORDS = $5d00                 ; "Then he dreams.", 640 bytes of bitmap, and 23:00 for the clock
TITLE     = $9000                   ; title.bin, packed; unpacked to $d000
seen      = $18                     ; 1 = the story has begun once: from now on fire on the title starts the game
in_bed    = $0e                     ; 1 = the cells of bed.bin are in the picture
cell      = $0f                     ; number of a cell, 2 bytes
from      = $fb                     ; pointers, 2 bytes each
to        = $fd

        * = $0810
start
        !if start != 2064 { !error "start is not at 2064" }
        sei                         ; no interrupts, we wait for the raster line ourselves
        lda #$7f
        sta $dc0d                   ; no timer interrupts
        lda #$a5
        sta rnd                     ; the random numbers may not start at 0
        lda CIA2_PORTA
        and #$fc
        ora #$02                    ; the VIC sees $4000-$7fff
        sta CIA2_PORTA
        lda #0
        sta VIC_BORDER
        sta VIC_BG
        sta SPR_MULTI
        sta $d017                   ; no sprite is stretched
        sta $d01d
        sta $d01b                   ; sprites in front of the picture
        sta SPR_XHI
        sta SPR_ENABLE
        lda #$3b
        sta VIC_CTRL1               ; bitmap mode, screen on
        lda #$08
        sta VIC_CTRL2               ; 40 columns, one colour per pixel

        lda #0
        sta in_bed
        sta seen
        sta star
        sta CIA1_DDRA               ; port A inputs: the joystick
        sta CIA1_DDRB
        lda #1
        sta fire                    ; a button that is still down does not count
        !ifndef FROM { FROM = 6 }   ; the title first; make intro FROM=4 starts at another shot, to look at it
        lda #FROM
        sta shot
        lda #0
        sta SPR2_COLOR              ; sprites 2 and 3: the head, black
        sta SPR2_COLOR + 1

new_shot                            ; everything to the start of the shot in the variable 'shot'
        lda shot
        bne +
        inc seen                    ; the story begins
        bne +
        inc seen                    ; (never 0 again)
+
        lda #0
        ldy shot
        cpy #2                      ; the door opens in the same room: no cut, the hum goes on
        beq .go_on
        lda #$08                    ; colour screen 0: black. A cut
        sta VIC_MEMCTL
        lda CIA2_PORTA
        and #$fc
        ora #$02
        sta CIA2_PORTA
        ldx #24                     ; the SID silent
        lda #0
-       sta $d400,x
        dex
        bpl -
        sta light
        sta sink
        cpy #4                      ; the large clock shows a little shorter: start further on
        bne .go_on
        lda #64
.go_on  sta frame
        lda #0
        sta frame + 1
        sta typed
        sta nod
        sta look
        sta random_light
        sta beat
        sta SPR_ENABLE
        lda #1
        sta wait
        ldx #160                    ; hide the sentences: black on black, in the three screens they show on
        lda #0
-       sta ROOM + 4 * $400 + BAR - 1,x
        sta ROOM + 5 * $400 + BAR - 1,x
        sta ROOM + 6 * $400 + BAR - 1,x
        sta DOOR + BAR - 1,x
        sta DOOR + $400 + BAR - 1,x
        sta DOOR + $800 + BAR - 1,x
        dex
        bne -
        lda #$3b                    ; the dream changes these: back to the bitmap
        sta VIC_CTRL1
        lda #$08
        sta VIC_CTRL2
        lda #0
        sta VIC_BG
        sta $d017
        sta $d01d
        sta slit
        sta SPR_XHI
        sta SPR2_COLOR              ; the head is black (the dream uses these sprites too)
        sta SPR2_COLOR + 1
        lda #81
        sta lid
        lda shot
        cmp #5
        bcc ++
        bne +
        jmp start_dream             ; no room, no hum
+       cmp #6
        bne +
        jsr start_title
        jmp hum
+       cmp #8
        bne +
        jsr start_spark
        jmp hum
+       jsr empty_dream             ; the game starts
        jmp loop
++      jsr load_text
        lda #0                      ; must he be in bed in this shot?
        ldx shot
        cpx #3
        bcc +
        lda #1
+       cmp in_bed
        beq +
        sta in_bed
        jsr swap_bed
+

hum     ; the hum: two low voices through the low-pass filter. 852 = 50 Hz, 1710 = just above 100 Hz
        lda #<852
        sta SID_FREQ1L
        lda #>852
        sta SID_FREQ1H
        lda #<1710
        sta SID_FREQ2L
        lda #>1710
        sta SID_FREQ2H
        lda #$08
        sta SID_PW2H                ; a square wave
        lda #$50                    ; the first digit is how loud the hum is against the keys (0-f), all the time
        sta SID_SR1
        lda #$20
        sta SID_SR2
        lda #$18
        sta SID_FC_HI               ; the filter lets only the lowest part through
        lda #$03
        sta SID_RES                 ; voices 1 and 2 go through the filter, the keys (voice 3) do not
        lda #$21
        sta SID_CTRL1               ; sawtooth on
        lda #$41
        sta SID_CTRL2               ; pulse on

loop
-       lda VIC_RASTER              ; wait for line 251, below the picture
        cmp #251
        bne -
        lda CIA1_PORTA              ; fire? 0 = down
        and #$10
        bne .up
        lda fire
        bne .held
        inc fire
        lda shot
        cmp #7                      ; the game starts already
        beq .held
        cmp #6
        bne .intro
        lda seen                    ; the title: the first time fire starts the story, after that the game
        bne .game
        sta shot
        jmp new_shot
.intro  cmp #0                      ; in the story fire starts the game, but not in the first 2 seconds: a second
        bne .game                   ; press by accident may not skip it
        lda frame + 1
        bne .game
        lda frame
        cmp #100
        bcc .held
.game   lda #7
        sta shot
        jmp new_shot
.up     lda #0
        sta fire
.held   lda shot
        cmp #4
        bcc +
        jsr play_late               ; the last two shots show their own pictures
        jmp .next
+       lda CIA2_PORTA              ; 0 to 6: the room, at $4000. 7 to 9: the door is open, at $8000
        and #$fc
        ldx light
        cpx #7
        bcc +
        ora #$01
        bne ++
+       ora #$02
++      sta CIA2_PORTA
        txa                         ; show the colour screen: its number * 16, plus 8 for the bitmap
        cmp #7
        bcc +
        sbc #7
+       asl
        asl
        asl
        asl
        ora #$08
        sta VIC_MEMCTL
        jsr place_head
        jsr key_off
        lda shot
        bne +
        jsr fade
        jsr type
        jmp .next
+       jsr count_beats
        lda shot
        cmp #1
        bne +
        jsr play2
        jmp .next
+       cmp #2
        bne +
        jsr play3
        jmp .next
+       jsr play_bed
.next
        inc frame
        bne +
        inc frame + 1
+       ldx shot                    ; the last frame of this shot?
        lda frame
        cmp shot_end_lo,x
        bne +
        lda frame + 1
        cmp shot_end_hi,x
        bne +
        lda shot                    ; the next shot, and the first one after the last
        tax
        lda shot_next,x
        sta shot
        jmp new_shot
+       lda VIC_RASTER              ; the work can be done within one line: do not run twice on line 251
-       cmp VIC_RASTER
        beq -
        jmp loop

shot_end_lo !byte <568, <688, <560, <300, <560, <944, <1000, <220, <432   ; frames, 50 in a second
shot_end_hi !byte >568, >688, >560, >300, >560, >944, >1000, >220, >432
shot_next   !byte 1, 2, 3, 4, 8, 6, 0, 6, 5

!zone load_text
load_text                           ; subroutine: put the sentences and the time of this shot in the bitmap
        lda shot
        asl                         ; times 2
        sta from + 1
        asl                         ; times 4
        adc from + 1                ; times 6: the pages of $600 (the carry is 0: 'shot' is small)
        adc #>TEXTS
        sta from + 1
        lda #0
        sta from
        lda #<BAR_BITS
        sta to
        lda #>BAR_BITS
        sta to + 1
        ldx #5                      ; 5 pages = 1280 bytes
        ldy #0
.copy   lda (from),y
        sta (to),y                  ; in the room
        pha
        lda to + 1
        eor #$c0                    ; $7a40 becomes $ba40: the same place in the picture with the door
        sta to + 1
        pla
        sta (to),y
        lda to + 1
        eor #$c0
        sta to + 1
        iny
        bne .copy
        inc from + 1
        inc to + 1
        dex
        bne .copy
        ldy #23                     ; 'from' is at the clock now: 24 bytes
-       lda (from),y
        sta CLOCK_BITS,y
        dey
        bpl -
        rts

!zone show_letter
show_letter                         ; subroutine: make the letter at place X (counted from BAR) white
        lda #$10
        sta ROOM + 4 * $400 + BAR,x
        sta ROOM + 4 * $400 + BAR + 40,x
        sta ROOM + 5 * $400 + BAR,x
        sta ROOM + 5 * $400 + BAR + 40,x
        sta ROOM + 6 * $400 + BAR,x
        sta ROOM + 6 * $400 + BAR + 40,x
        rts

!zone count_beats
count_beats                         ; subroutine: beat = frame / 4
        lda frame + 1
        sta beat
        lda frame
        lsr beat
        ror
        lsr beat
        ror
        sta beat
        rts

!zone swap_bed
swap_bed                            ; subroutine: swap the cells of bed.bin with the picture: he is in bed, or at the desk again
        lda #<BED
        sta from
        lda #>BED
        sta from + 1
.cell   ldy #1
        lda (from),y
        cmp #$ff                    ; the end of the list
        beq .done
        sta cell + 1
        sta to + 1
        dey
        lda (from),y
        sta cell
        asl                         ; the bitmap: cell * 8 + $6000
        rol to + 1
        asl
        rol to + 1
        asl
        rol to + 1
        sta to
        lda to + 1
        adc #$60                    ; (the carry is 0: the number is less than 1000)
        sta to + 1
        lda from                    ; 'from' moves on past the number, so Y counts for both
        clc
        adc #2
        sta from
        bcc +
        inc from + 1
+       ldy #7
-       jsr swap
        dey
        bpl -
        lda from                    ; past the bitmap
        clc
        adc #8
        sta from
        bcc +
        inc from + 1
+       lda cell                    ; the seven screens, 4 pages apart
        sta to
        lda cell + 1
        clc
        adc #>ROOM
        sta to + 1
        ldx #7
-       ldy #0
        jsr swap
        inc from
        bne +
        inc from + 1
+       lda to + 1
        clc
        adc #4
        sta to + 1
        dex
        bne -
        jmp .cell
.done   rts
swap    lda (from),y
        pha
        lda (to),y
        sta (from),y
        pla
        sta (to),y
        rts

!zone play3
; The door, in beats: 4, 9, 14 footsteps; 20 the door opens; 32 it is open; 46 and 62 the words; 110 it closes; 118 shut
play3                               ; subroutine: one frame of the door
        lda #$10 + HUM
        sta SID_VOLUME
        lda #3
        sta sink
        lda beat                    ; the light
        ldx #4
        cmp #20
        bcc .light
        inx                         ; 5 is not used here: the door starts at 7
        inx
        inx
        cmp #26
        bcc .light
        cmp #114
        bcs .shut
        inx
        cmp #32
        bcc .light
        cmp #110
        bcs .light
        inx
        bne .light
.shut   cmp #118
        bcc .light
        ldx #4
.light  stx light

        ldx #0                      ; he looks round, to the left
        cmp #36
        bcc +
        cmp #84
        bcs +
        ldx #4
        ldy #0
        sty sink
+       stx look

        ldx #STEPS - 1              ; steps and the door: noise, one frame in four begins one
        ldy frame
        tya
        and #3
        bne .creak
        lda beat
-       cmp steps,x
        beq .step
        dex
        bpl -
        lda #$80                    ; let the sound go
        sta SID_CTRL3
        bne .creak
.step   lda step_pitch,x
        sta SID_FREQ3H
        lda #$06
        sta SID_AD3
        sta SID_SR3
        lda #$81
        sta SID_CTRL3
.creak  lda beat                    ; the hinge: a saw that scrapes
        cmp #21
        bcc .words
        cmp #32
        bcs .words
        asl
        adc frame                   ; up and down a little
        and #$07
        adc #$05
        sta SID_FREQ3H
        lda #$20
        sta SID_SR3
        lda #$21
        sta SID_CTRL3
.words  lda frame
        and #3
        bne .done
        lda beat
        ldx #TEXT3
        ldy #5                      ; "Bed.
        cmp #46
        beq .say
        ldx #TEXT3 + 6
        cmp #62                     ; Now."
        bne .done
.say    lda #$10                    ; a whole word at once, only in the screens with the door
-       sta DOOR + BAR,x
        sta DOOR + BAR + 40,x
        sta DOOR + $400 + BAR,x
        sta DOOR + $400 + BAR + 40,x
        sta DOOR + $800 + BAR,x
        sta DOOR + $800 + BAR + 40,x
        inx
        dey
        bne -
.done   rts

STEPS = 5
steps      !byte 4, 9, 14, 20, 118
step_pitch !byte 4, 4, 5, $30, 3

!zone play_bed
play_bed                            ; subroutine: one frame of the bed: dark, the light of the monitor, then a little less of it
        ldx #0
        lda beat
        cmp #8
        bcc .set
        ldx #3
        cmp #11
        bcc .set
        inx
        cmp #14
        bcc .set
        cmp #56 
        bcs .set
        jsr steady
        jmp .hum
.set    stx light
.hum    lda beat
        lsr
        lsr
        cmp #HUM
        bcc +
        lda #HUM
+       ora #$10
        sta SID_VOLUME
        rts

!zone play_late
play_late                           ; subroutine: one frame of the clock, the eyelids or the dream
        jsr count_beats
        lda shot
        cmp #5
        beq +
        bcs ++
        jmp play4
+       jmp play5
++      cmp #6
        bne +
        jmp play_title
+       cmp #8
        bne +
        jmp play_spark
+       jmp play_go

show_dream                          ; subroutine: the VIC sees the dream, as characters
        lda CIA2_PORTA
        and #$fc                    ; $c000
        sta CIA2_PORTA
        lda #$02                    ; screen at $c000, characters at $c800
        sta VIC_MEMCTL
        lda #$18                    ; multicolour on: colours 0 to 7 still look the same, and with extended colour
        sta VIC_CTRL2               ; the VIC draws black: that makes the eyelids
        rts

!zone lids
; The eyelids: an impossible mode of the VIC (extended colour with bitmap or multicolour) draws only black. It is on
; everywhere except from 'lid' lines above MIDDLE to 'lid' lines below.
lids                                ; subroutine: draw the eyelids. A = the good mode (VIC_CTRL1)
        sta to                      ; keep it
        ora #$40
        sta VIC_CTRL1               ; black, from the bottom of the picture on
        ldx slit                    ; the colour can wait there already, nobody sees it
        stx VIC_BG
        ldx to
        lda #MIDDLE
        sec
        sbc lid
-       cmp VIC_RASTER
        bne -
        stx VIC_CTRL1               ; one write, before the line becomes visible
        txa
        ora #$40
        tax
        lda #MIDDLE
        clc
        adc lid
-       cmp VIC_RASTER
        bne -
        stx VIC_CTRL1
        rts

!zone big_clock
big_clock                           ; subroutine: five large sprites show the time; X = 0: 22:59, X = 5: 23:00
        ldy #0
-       lda clock_digit,x
        sta DREAM_PTR,y
        lda #COLOR_RED
        sta SPR0_COLOR,y
        inx
        iny
        cpy #5
        bne -
        ldx #9
-       lda clock_place,x
        sta SPR0_X,x
        dex
        bpl -
        lda #$1f
        sta $d017                   ; twice as wide and twice as high
        sta $d01d
        lda #0
        sta SPR_XHI
        lda #$1f
        sta $d017                   ; twice as wide and twice as high
        sta $d01d
        lda #0
        sta SPR_XHI
        lda shot                    ; in the dream the clock is below the line of light
        cmp #5
        bcc +
        lda #158
        sta SPR0_Y
        sta SPR1_Y
        sta SPR2_Y
        sta SPR2_Y + 2
        sta SPR2_Y + 4
+
        lda frame                   ; the colon goes on and off
        and #$20
        beq +
        lda #$04
+       eor #$1f
        sta SPR_ENABLE
        rts

clock_digit !byte 17, 17, 21, 19, 20, 17, 18, 21, 16, 16
clock_place !byte 74, 116, 118, 116, 161, 116, 203, 116, 247, 116

!zone title
start_title                         ; subroutine: unpack the poster to $d000 and make the beam
        lda #<TITLE
        sta from
        lda #>TITLE
        sta from + 1
        lda #$00
        sta to
        lda #$d0
        sta to + 1
        lda #$34                    ; all RAM: no ROM and no chips (the sprites and the sound just go on)
        sta CPU_PORT
.next   ldy #0
        lda (from),y
        beq .end
        tax                         ; how many
        inc from
        bne +
        inc from + 1
+       txa
        bmi .copy
-       lda (from),y                ; bytes as they are
        sta (to),y
        iny
        dex
        bne -
        tya                         ; both pointers move on, Y = how far
        clc
        adc from
        sta from
        bcc +
        inc from + 1
+       tya
        jsr .on
        jmp .next
.copy   sec                         ; bytes that were there before
        sbc #125
        tax
        sec                         ; cell = to - distance
        lda to
        sbc (from),y
        sta cell
        iny
        lda to + 1
        sbc (from),y
        sta cell + 1
        lda from
        clc
        adc #2
        sta from
        bcc +
        inc from + 1
+       ldy #0
-       lda (cell),y
        sta (to),y
        iny
        dex
        bne -
        tya
        jsr .on
        jmp .next
.on     clc
        adc to
        sta to
        bcc +
        inc to + 1
+       rts
.end    lda #$37                    ; everything back
        sta CPU_PORT
        ldx #7                      ; the beam: eight white sprites in a row, twice as wide
-       lda #1
        sta SPR0_COLOR,x
        dex
        bpl -
        ldx #14
        ldy #7
-       lda beam_x,y
        sta SPR0_X,x
        dex
        dex
        dey
        bpl -
        lda #$e0                    ; the last three are past 255
        sta SPR_XHI
        lda #$ff
        sta $d01d
        lda #0
        sta drawn
        sta random_light
        lda #56                     ; (lines below 56 also exist at the bottom of the frame, to the VIC_RASTER byte)
        sta beam_y
        lda #$ff
        sta beam_row
        rts
beam_x  !byte 24, 72, 120, 168, 216, <264, <312, <312

; The beam draws the poster from top to bottom; every now and then it comes by again.
play_title                          ; subroutine: one frame of the title
        lda CIA2_PORTA
        and #$fc
        sta CIA2_PORTA
        lda #$08
        sta VIC_CTRL2
        lda #$3b
        sta VIC_CTRL1
        lda #$10 + HUM - 2
        sta SID_VOLUME
        ldx #$48                    ; colours at $d000, bitmap at $e000
        lda random_light            ; the light in the window flickers
        beq +
        dec random_light
        ldx #$58                    ; colours at $d400
        bne ++
+       jsr random
        cmp #8
        bcs ++
        and #3
        sta random_light
++      stx VIC_MEMCTL
        lda beam_y
        beq .rest
        clc
        adc #2
        cmp #246
        bcs .there
        sta beam_y
        lda #$ff                    ; it sings while it moves: lower and lower
        sec
        sbc beam_y
        lsr
        lsr
        lsr
        adc #7
        sta SID_FREQ3H
        lda #$40
        sta SID_SR3
        lda #$a5
        sta SID_AD3
        lda #$11
        sta SID_CTRL3
        bne .light
.there  lda #1
        sta drawn
        lda #0                      ; 0 = no beam
        sta beam_y
        lda #$10                    ; quiet
        sta SID_CTRL3
        bne .light
.rest   lda frame                   ; about every 5 seconds it starts again at the top
        bne .light
        lda #50
        sta beam_y
.light  ldx #0
        lda beam_y
        beq +
        ldx #$ff
        ldy #14
-       sta SPR0_Y,y
        dey
        dey
        bpl -
+       stx SPR_ENABLE
        lda #$34                    ; the colours are under the chips
        sta CPU_PORT
        jsr light_row
        lda drawn                   ; "Fire to begin" glows up and down
        beq ++
        lda frame
        lsr
        lsr
        lsr
        and #15
        tax
        lda glow,x
        ldx #12
-       sta $d000 + 19 * 40 + 13,x
        sta $d000 + 20 * 40 + 13,x
        sta $d400 + 19 * 40 + 13,x
        sta $d400 + 20 * 40 + 13,x
        dex
        bpl -
++      lda #$37
        sta CPU_PORT
        lda drawn
        bne +
        lda beam_y                  ; below the beam it is still black, the first time
        clc
        adc #2
        ldx #$7b
-       cmp VIC_RASTER
        bne -
        stx VIC_CTRL1
+       rts

light_row                           ; subroutine: the row of the title where the beam is, is white
        lda beam_y
        sec
        sbc #50
        lsr
        lsr
        lsr                         ; the row of characters
        cmp beam_row
        beq .same
        pha
        ldx beam_row                ; the old row gets its own colour back
        jsr .in_title
        bcs +
        jsr .paint
+       pla
        sta beam_row
        tax
        jsr .in_title
        bcs .same
        lda #$10
        jmp .paint
.in_title                           ; X = row, A = its own colour. Carry set: not a row of the title
        cpx #9
        bcs .no
        lda title_color,x
        beq .no
        clc
        rts
.no     sec
.same   rts
.paint  ldy row_lo,x                ; A = colour, X = row
        sty to
        pha
        lda row_hi,x
        clc
        adc #$d0 - >DREAM
        sta to + 1
        pla
        jsr +                       ; in both colour screens
        tax
        lda to + 1
        clc
        adc #4
        sta to + 1
        txa
+       ldy #35                     ; columns 4 to 35: the letters
-       sta (to),y
        dey
        cpy #3
        bne -
        rts
title_color !byte 0, 0, $10, $30, $e0, 0, $10, $30, $e0
glow        !byte $b0, $b0, $c0, $c0, $f0, $f0, $10, $10, $10, $10, $f0, $f0, $c0, $c0, $b0, $b0

!zone go
; Fire: everything is black, the beam falls from top to bottom, and the clock says 23:00. The game will start here.
play_go                             ; subroutine: one frame of the start of the game
        jsr show_dream
        lda #$5b
        sta VIC_CTRL1
        lda frame
        cmp #60
        bcs .clock
        cmp #1                      ; a stroke
        bne +
        lda #$1f
        sta SID_VOLUME
        lda #$04
        sta SID_FREQ1H
        lda #$0a
        sta SID_AD1
        lda #$11
        sta SID_CTRL1
+       lda frame                   ; the beam: three lines lower every frame
        asl
        adc frame
        adc #52
        sta to
        ldx #1
        stx VIC_BG
        ldx #$1b
        ldy #$5b
        lda to
-       cmp VIC_RASTER
        bne -
        stx VIC_CTRL1
        clc
        adc #2
-       cmp VIC_RASTER
        bne -
        sty VIC_CTRL1
        rts
.clock  cmp #90
        bcc +
        ldx #5
        jmp big_clock
+       rts

!zone play4
; In beats: 0 the large clock; 44 the room; 56 the eyes close, 80 open a little, 94 close; 140 the end
play4                               ; subroutine: one frame of the clock and the eyelids
        lda frame
        and #$1f
        bne .no_tick
        lda frame + 1               ; the tick of the clock, as long as we look at it
        bne .no_tick
        lda frame
        cmp #176
        bcs .no_tick
        lda #$60
        sta SID_FREQ3H
        lda #$00
        sta SID_SR3
        lda #$01
        sta SID_AD3
        lda #$11
        sta SID_CTRL3
        bne .sound
.no_tick
        lda #$10
        sta SID_CTRL3
.sound  lda beat
        cmp #44
        bcs .room
        lda #$10 + HUM - 4          ; the hum is far away
        sta SID_VOLUME
        jsr show_dream
        lda #$5b                    ; black: extended colour with multicolour
        sta VIC_CTRL1
        ldx #0
        jmp big_clock
.room
        lda #0
        sta SPR_ENABLE
        lda CIA2_PORTA
        and #$fc
        ora #$02
        sta CIA2_PORTA
        lda #$08
        sta VIC_CTRL2
        ldx #5
        lda beat
        cmp #110                    ; almost asleep: less light
        bcc +
        ldx #4
+       txa
        asl
        asl
        asl
        asl
        ora #$08
        sta VIC_MEMCTL
        lda lid                     ; the sound goes with the eyes
        lsr
        lsr
        lsr
        lsr                         ; 0 to 5
        clc
        adc #$11
        sta SID_VOLUME

        ldx #81                     ; where do the eyelids want to be?
        lda beat
        cmp #56
        bcc .move
        ldx #26
        cmp #80
        bcc .move
        ldx #50
        cmp #94
        bcc .move
        ldx #1
        lda frame                   ; the last time they go slowly
        lsr
        bcs .draw
.move   cpx lid
        beq .draw
        bcs .up
        dec lid
        bne .draw
.up     inc lid
.draw   lda #$3b
        jmp lids

!zone spark
start_spark                         ; subroutine: the sentence and 23:00 in the bitmap of the room (he is in bed there)
        ldx #0
-       lda DREAM_WORDS,x
        sta BAR_BITS + 320,x
        lda DREAM_WORDS + $100,x
        sta BAR_BITS + 320 + $100,x
        lda DREAM_WORDS + $180,x    ; (640 bytes: the last piece overlaps)
        sta BAR_BITS + 320 + $180,x
        inx
        bne -
        ldx #23
-       lda DREAM_WORDS + 640,x
        sta CLOCK_BITS,x
        dex
        bpl -
        lda #1
        sta lid
        rts

; In beats: 0 the large clock says 23:00; 26 the eyes open, in the dream; 46 a spark in his head; 54 it flies (136 frames)
; to the screen; 60 the sentence; 88 it is in the screen; 96 the picture closes; 108 the end
play_spark                          ; subroutine: one frame of the start of the dream
        lda beat
        cmp #26
        bcs .room
        lda #$1f
        sta SID_VOLUME
        lda frame
        cmp #8
        bne +
        lda #$03                    ; one low stroke
        sta SID_FREQ3H
        lda #$0a
        sta SID_AD3
        lda #$11
        sta SID_CTRL3
+       jsr show_dream
        lda #$5b
        sta VIC_CTRL1
        ldx #5
        lda frame
        cmp #8
        bcs +
        ldx #0                      ; still 22:59 for a moment
+       jmp big_clock

.room   lda CIA2_PORTA
        and #$fc
        ora #$02
        sta CIA2_PORTA
        lda #$08
        sta VIC_CTRL2
        ldx #$48                    ; the room with less light
        lda beat
        cmp #88                     ; the screen lights up when the spark goes in
        bcc +
        cmp #94
        bcs +
        ldx #$58
+       stx VIC_MEMCTL
        lda #$10 + HUM - 3
        sta SID_VOLUME
        lda beat                    ; the eyelids
        cmp #96
        bcs .close
        lda lid
        cmp #81
        bcs .spark
        inc lid
        bne .spark
.close  lda lid
        cmp #3
        bcc .spark
        dec lid
        dec lid

.spark  lda #0
        sta $d017
        sta $d01d
        sta SPR_XHI
        ldy #0                      ; no spark yet
        lda beat
        cmp #46
        bcc .off
        cmp #88
        bcs .off
        lda frame                   ; it glitters: orange and yellow
        and #4
        beq +
        lda #1
+       ora #0
        tax
        lda spark_color,x
        sta SPR2_COLOR + 2
        ldx #0                      ; how far it is: 0 to 136
        lda frame
        sec
        sbc #216
        sta to
        lda frame + 1
        sbc #0
        bcc +                       ; not yet
        ldx to
+       cpx #136
        bcc +
        ldx #136
+       lda spark_y,x
        sta SPR2_Y + 4
        stx to
        lda #<316                   ; x = 316 - how far
        sec
        sbc to
        sta SPR2_X + 4
        lda #>316
        sbc #0
        beq +
        lda #$10                    ; the ninth bit of sprite 4
+       sta SPR_XHI
        lda #$f0                    ; it sings softly: higher as it rises
        sec
        sbc SPR2_Y + 4
        lsr
        lsr
        adc #20
        sta SID_FREQ3H
        lda #$40
        sta SID_SR3
        lda #$88
        sta SID_AD3
        lda #$11
        sta SID_CTRL3
        ldy #$10
        bne +
.off    lda #$10
        sta SID_CTRL3
+       sty SPR_ENABLE

        lda frame                   ; the sentence, a letter in a beat
        and #3
        bne +
        lda beat
        sec
        sbc #60
        bcc +
        cmp #15
        bcs +
        adc #40 + 12
        tax
        jsr show_letter
+       lda #$3b
        ldx beat                    ; the bar with the sentence is outside the eyelids: only when they move
        cpx #47
        bcc +
        cpx #96
        bcs +
        sta VIC_CTRL1
        rts
+       jmp lids

spark_color !byte 8, 7
spark_y !for i, 0, 136 { !byte 160 - 34 * i / 136 - 150 * i * (136 - i) / (136 * 136) }

!zone dream
start_dream                         ; everything to the start of the dream
        jsr empty_dream
        jmp .chord

empty_dream                         ; subroutine: the screen of the dream empty
        ldx #0                      ; an empty screen, white letters
-       lda #0
        sta DREAM,x
        sta DREAM + $100,x
        sta DREAM + $200,x
        sta DREAM + $2e8,x
        lda #1
        sta COLOR_RAM,x
        sta COLOR_RAM + $100,x
        sta COLOR_RAM + $200,x
        sta COLOR_RAM + $2e8,x
        inx
        bne -
        ldx #STARS - 1              ; nothing to wipe out yet: cell 0
-       lda #0
        sta old_lo,x
        lda #>DREAM
        sta old_hi,x
        dex
        bpl -
        rts

.chord  lda #$07                    ; the chord of the dream: three soft triangles that swell slowly, G, D and B
        sta SID_RES
        lda #$40
        sta SID_FC_HI
        ldx #2
        ldy #14
-       lda chord_lo,x
        sta SID_FREQ1L,y
        lda chord_hi,x
        sta SID_FREQ1H,y
        lda #$c9
        sta SID_AD1,y
        lda #$aa
        sta SID_SR1,y
        tya
        sec
        sbc #7
        tay
        dex
        bpl -
        lda #1
        sta lid
        sta slit
        lda #120                    ; it begins at beat 30
        sta frame
        lda #30
        sta beat
        jmp loop

chord_lo !byte <1669, <2500, <4205
chord_hi !byte >1669, >2500, >4205
!zone play5
; In beats: 30 (the first) a line of light that opens; 70 the eyelids are gone; 74 Pixel glows;
; 90 the eye opens; 104 and 120 the first sentences; 172 they go; 180 the last one; 250 the end
play5                               ; subroutine: one frame of the dream
        jsr show_dream
        jsr pixel
        lda beat
        cmp #30
        bne +
        lda frame
        and #3
        bne +
        lda #$1c                    ; the chord begins
        sta SID_VOLUME
        lda #$10                    ; voice 3 has played the stroke: gate off, its own note and shape again
        sta SID_CTRL3
        lda chord_lo + 2
        sta SID_FREQ3L
        lda chord_hi + 2
        sta SID_FREQ3H
        lda #$c9
        sta SID_AD3
        lda #$aa
        sta SID_SR3
        lda #$11
        sta SID_CTRL1
        sta SID_CTRL2
        sta SID_CTRL3
+       jsr move_stars
        jsr words
        lda beat
        cmp #70
        bcs .all
        lda frame
        lsr
        bcs +
        inc lid
+       ldx #0                      ; the light in the crack: white, cyan, light blue, blue, black
        lda lid
-       cmp slit_at,x
        bcc +
        inx
        bne -
+       lda slit_color,x
        sta slit
        lda #$1b
        jmp lids
.all    lda #0                      ; no more eyelids
        sta VIC_BG
        lda #$1b
        sta VIC_CTRL1
        rts

slit_at    !byte 3, 6, 12, 22, 255
slit_color !byte 1, 3, 14, 6, 0

!zone pixel
pixel                               ; subroutine: Pixel: the eye, the block, two layers of glow (sprites 0 to 3)
        lda #22
        ldx beat
        cpx #90
        bcc .eye
        lda #23
        cpx #92
        bcc .eye
        lda #24                     ; open
        cpx #112                    ; and a blink
        beq .blink
        cpx #164
        beq .blink
        cpx #225
        bne .eye
.blink  lda #22
.eye    sta DREAM_PTR
        ldy #25
        sty DREAM_PTR + 1
        iny
        sty DREAM_PTR + 2
        iny
        sty DREAM_PTR + 3
        lda #0                      ; the eye is black
        sta SPR0_COLOR
        lda frame                   ; float: up and down in a slow wave
        lsr
        lsr
        lsr
        and #$0f
        tax
        lda wave,x
        clc
        adc #MIDDLE - 10
        sta SPR0_Y
        sta SPR1_Y
        sta SPR2_Y
        sec
        sbc #10
        sta SPR2_Y + 2              ; the outer glow is twice as large
        lda #172
        sta SPR0_X
        sta SPR1_X
        sta SPR2_X
        lda #160
        sta SPR2_X + 2
        lda #$08
        sta $d017
        sta $d01d
        lda #0
        sta SPR_XHI
        lda beat                    ; it comes up from dark to warm
        sec
        sbc #74
        bcs +
        lda #0
        sta SPR_ENABLE
        rts
+       lsr
        lsr
        cmp #3
        bcc +
        lda #3
+       tax
        lda block_color,x
        sta SPR1_COLOR
        lda glow_color,x
        sta SPR2_COLOR
        lda #9
        sta SPR2_COLOR + 1
        lda pixel_on,x
        sta SPR_ENABLE
        lda beat                    ; a high note when the eye opens
        cmp #92
        bne +
        lda frame
        and #3
        bne +
        lda #$10
        sta SID_CTRL3
        lda #<9997
        sta SID_FREQ3L
        lda #>9997
        sta SID_FREQ3H
        lda #$0a
        sta SID_AD3
        sta SID_SR3
        lda #$11
        sta SID_CTRL3
+       rts

wave        !byte 0, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 0, 0
block_color !byte 9, 8, 7, 7
glow_color  !byte 9, 9, 8, 8
pixel_on    !byte $08, $0c, $0e, $0f

!zone words
words                               ; subroutine: the sentences of the dream, a letter in a beat
        lda frame
        and #3
        beq +
        rts
+       lda beat
        cmp #172
        bcc .first
        bne .last
        ldx #159                    ; the first two go
        lda #0
-       sta DREAM + BAR,x
        dex
        cpx #$ff
        bne -
        rts
.first  sec
        sbc #104
        bcc .done
        cmp #TEXT_A_LEN
        bcs +
        tax
        lda text_a,x
        beq .done
        sta DREAM + TEXT_A_POS,x
        adc #1                      ; (the carry is 0)
        sta DREAM + TEXT_A_POS + 40,x
.done   rts
+       lda beat
        sbc #120
        bcc .done
        cmp #TEXT_B_LEN
        bcs .done
        tax
        lda text_b,x
        beq .done
        sta DREAM + TEXT_B_POS,x
        adc #1
        sta DREAM + TEXT_B_POS + 40,x
        rts
.last   sec
        sbc #180
        bcc .done
        cmp #TEXT_C_LEN
        bcs .done
        tax
        lda text_c,x
        beq .done
        sta DREAM + TEXT_C_POS,x
        adc #1
        sta DREAM + TEXT_C_POS + 40,x
        rts

        !source "src/intro/dream_text.asm"

!zone move_stars
age     = DREAM + $7c0
sx_lo   = DREAM + $c00
sx_hi   = DREAM + $c40
sy_lo   = DREAM + $c80
sy_hi   = DREAM + $cc0
vx_lo   = DREAM + $d00
vx_hi   = DREAM + $d40
vy_lo   = DREAM + $d80
vy_hi   = DREAM + $dc0
first   = DREAM + $e00              ; the same, to begin again: speed x, y, place x, y
old_lo  = DREAM + $740              ; the cell where the star is now
old_hi  = DREAM + $780

move_stars                          ; subroutine: half of the stars fly on, away from the middle, faster and faster
        ldx star
.star   lda old_lo,x                ; wipe it out
        sta to
        lda old_hi,x
        sta to + 1
        ldy #0
        tya
        sta (to),y
        clc                         ; place + speed
        lda sx_lo,x
        adc vx_lo,x
        sta sx_lo,x
        lda sx_hi,x
        adc vx_hi,x
        sta sx_hi,x
        cmp #160
        bcs .again                  ; past the left or right edge
        lda sy_lo,x
        adc vy_lo,x
        sta sy_lo,x
        lda sy_hi,x
        adc vy_hi,x
        sta sy_hi,x
        cmp #24
        bcc .again
        cmp #168
        bcc .inside
.again  lda first,x                 ; a new star near the middle
        sta vx_lo,x
        lda first + $40,x
        sta vx_hi,x
        lda first + $80,x
        sta vy_lo,x
        lda first + $c0,x
        sta vy_hi,x
        lda first + $100,x
        sta sx_lo,x
        lda first + $140,x
        sta sx_hi,x
        lda first + $180,x
        sta sy_lo,x
        lda first + $1c0,x
        sta sy_hi,x
        lda #0
        sta age,x
.inside txa                         ; every 16 frames: an eighth faster, not all the stars in the same frame
        asl
        eor frame
        and #$0e
        bne .plot
        lda age,x
        cmp #31
        bcs +
        inc age,x
+       lda vx_hi,x
        sta from
        lda vx_lo,x
        ldy #3
-       pha                         ; divide by 8, with the sign
        lda from
        cmp #$80
        ror from
        pla
        ror
        dey
        bne -
        clc
        adc vx_lo,x
        sta vx_lo,x
        lda from
        adc vx_hi,x
        sta vx_hi,x
        lda vy_hi,x
        sta from
        lda vy_lo,x
        ldy #3
-       pha
        lda from
        cmp #$80
        ror from
        pla
        ror
        dey
        bne -
        clc
        adc vy_lo,x
        sta vy_lo,x
        lda from
        adc vy_hi,x
        sta vy_hi,x
.plot   lda sy_hi,x                 ; the row
        lsr
        lsr
        lsr
        tay
        lda sx_hi,x                 ; the column: two pixels per step, so 4 steps in a cell
        lsr
        lsr
        clc
        adc row_lo,y
        sta to
        sta old_lo,x
        lda row_hi,y
        adc #0
        sta to + 1
        sta old_hi,x
        lda sx_lo,x                 ; the pixel in the cell: x 0-7
        asl                         ; its highest bit is the odd pixel
        lda sx_hi,x
        rol
        and #7
        sta from
        lda sy_hi,x
        and #7
        asl
        asl
        asl
        ora from
        clc
        adc #1                      ; characters 1 to 64
        ldy #0
        sta (to),y
        lda to + 1                  ; the colour
        clc
        adc #(>COLOR_RAM) - >DREAM
        sta to + 1
        lda age,x
        lsr
        tay
        lda star_color,y
        ldy #0
        sta (to),y
        inx
        inx
        cpx #STARS
        bcs +
        jmp .star
+       lda star                    ; the other half next time
        eor #1
        sta star
        rts

star_color !byte 6, 6, 6, 6, 4, 4, 4, 3, 3, 3, 1, 1, 1, 1, 1, 1
row_lo  !for i, 0, 24 { !byte <(DREAM + i * 40) }
row_hi  !for i, 0, 24 { !byte >(DREAM + i * 40) }

!zone play2
; Shot 2 in units of 4 frames ('beat'): 0 the light comes up, 17 the last keys, 40 the RETURN key, then nothing;
; 54 the wrong tone; 64 the tone stops and the room is darker; 78 and 120 the sentences; 200 the end
play2                               ; subroutine: one frame of shot 2
        lda beat
        cmp #12                     ; the light comes up
        bcs +
        lsr                         ; 0 to 5
        sta light
        tax
        lda fade_hum2,x
        ora #$10
        sta SID_VOLUME
        rts
+       cmp #54
        bcs .wrong
        jsr steady                  ; full light, with a flicker now and then
        lda frame
        and #3                      ; the keys fall on the first frame of a beat
        bne .done
        ldx #KEYS2 - 1
-       lda keys2,x
        cmp beat
        beq .key
        dex
        bpl -
        lda beat
        cmp #40
        bne .done
        jsr press                   ; RETURN: a heavier key
        lda #$18
        sta SID_FREQ3H
        lda #$05
        sta SID_AD3
        sta SID_SR3                 ; it rings on a little after the key is let go
        lda #$81
        sta SID_CTRL3
.done   rts
.key    jmp press
.wrong
        cmp #64
        bcs .after
        lda #6                      ; the light is weak while it sounds
        sta light
        lda #$00
        sta SID_FREQ3L
        lda #$07                    ; 105 Hz, almost the note of the hum, and not quite
        sta SID_FREQ3H
        sta SID_PW2H + 7            ; voice 3 pulse width: thin
        lda #$00
        sta SID_AD3
        lda #$a0
        sta SID_SR3
        lda #$41
        sta SID_CTRL3
        rts
.after
        ldx #4                      ; the far corners of the room are gone
        stx light
        cmp #64
        bne +
        ldx #$00                    ; the tone stops dead
        stx SID_SR3
        stx SID_CTRL3
+       cmp #110                    ; his head sinks, one line in 12 frames
        bcc +
        cmp #119
        bcs +
        sbc #109                    ; (the carry is 0: one more) 0 to 8
        tax
        lda third,x
        sta sink
+       lda frame                   ; a letter every beat
        and #3
        bne .done
        lda beat
        sec
        sbc #78
        bcc .done
        cmp #LEN2A
        bcs +
        adc #TEXT2A
        tax
        jmp show_letter
+       lda beat
        sec
        sbc #122
        bcc .done
        cmp #LEN2B
        bcs .done
        adc #TEXT2B
        tax
        jmp show_letter

KEYS2 = 9
keys2     !byte 17, 19, 22, 23, 26, 28, 29, 32, 34
third     !byte 1, 1, 1, 2, 2, 2, 3, 3, 3
fade_hum2 !byte 1, 3, 4, 5, HUM, HUM

!zone fade
fade                                ; subroutine: the light and the hum come up, flicker, and go down at the end
        lda frame + 1
        bne .full
        lda frame
        bmi .flicker                ; after 128 frames: full light
        lsr
        lsr
        lsr                         ; frame / 8 = 0 to 15
        tax
        lda fade_light,x
        sta light
        lda fade_hum,x
        ora #$10                    ; low-pass filter on
        sta SID_VOLUME
        rts
.full   cmp #2                      ; from frame 512: the light goes out
        bcc .flicker
        lda frame
        lsr
        lsr
        lsr                         ; 0 to 7
        tax
        lda out_light,x
        sta light
        lda out_light,x
        ora #$10
        sta SID_VOLUME
        rts
.flicker
steady                              ; subroutine: full light, with a flicker now and then
        lda random_light
        beq .calm
        dec random_light
        lda #6                      ; the light is a little weaker now
        sta light
        rts
.calm   lda #5
        sta light
        jsr random
        cmp #6                      ; about once a second
        bcs +
        and #3
        sta random_light
+       rts

!zone type
type                                ; subroutine: the next letter, with the tick of a key
        lda frame + 1
        bne +
        lda frame
        cmp #144                    ; no typing yet
        bcc .done
+
        lda typed
        cmp #TEXT_LEN
        bcs .done
        dec wait
        bne .done
        lda typed
        clc
        adc #TEXT1
        tax
        jsr show_letter
        ldx typed
        inc typed
        lda text_wait,x
        sta wait                    ; his rhythm
        cmp #20
        bcc +
        lda #3                      ; a long wait: he looks at the magazine
        sta look
        bne ++
+       lda #0
        sta look
++
press                               ; subroutine: the tick of a key, the head goes down a little
        lda #3
        sta nod                     ; the head goes down a little
        jsr random                  ; every key sounds a little different
        and #$0f
        adc #$28
        sta SID_FREQ3H
        lda #$00
        sta SID_SR3
        lda #$02                    ; very short
        sta SID_AD3
        lda #$81
        sta SID_CTRL3               ; noise on
.done   rts

key_off                             ; subroutine: let the key go (a key is never longer than a frame)
        lda shot                    ; not while the wrong tone sounds: that would restart it every frame
        beq +
        cmp #2                      ; the door and the bed do it themselves
        bcs .tone
        lda beat
        cmp #54
        bcs .tone
+       lda #$80
        sta SID_CTRL3
.tone   rts

!zone place_head
place_head                          ; subroutine: the head, two sprites high, and the rim of light in front of it
        ldy #0
        lda light
        cmp #4                      ; no head in the dark: the picture is black there anyway
        bcc +
        lda in_bed                  ; and not when he is in bed
        bne +
        ldy #$0f
+       sty SPR_ENABLE
        ldx light
        lda rim_color,x
        sta SPR0_COLOR
        sta SPR1_COLOR
        lda #HEAD_X
        sec
        sbc look
        sta SPR0_X
        sta SPR1_X
        sta SPR2_X
        sta SPR2_X + 2
        lda nod
        beq +
        dec nod
        lda #1
+       clc
        adc sink
        adc #HEAD_Y
        sta SPR0_Y
        sta SPR2_Y
        adc #21
        sta SPR1_Y
        sta SPR2_Y + 2
        rts

random                              ; subroutine: A = a random number
        lda rnd
        asl
        bcc +
        eor #$1d
+       sta rnd
        rts

fade_light !byte 0, 0, 0, 1, 1, 0, 1, 2, 2, 3, 3, 4, 4, 5, 5, 5      ; a tube that warms up
fade_hum   !byte 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, HUM, HUM, HUM, HUM
out_light  !byte 5, 4, 4, 3, 2, 1, 0, 0
rim_color  !byte 0, 6, 6, 6, 14, 3, 14, 14, 8, 8
text_wait                           ; frames after every letter of "He typed it in. Every line."
        !byte 7, 12, 14, 6, 7, 5, 6, 8, 13, 6, 9, 15, 7, 8, 48, 6, 6, 8, 5, 7, 9, 14, 6, 7, 6, 9, 5

        !if * > TEXTS { !error "the code runs into the texts" }
        * = TEXTS
        !bin "src/intro/text.bin"
        * = BED
        !bin "src/intro/bed.bin"
        * = ROOM
        !bin "src/intro/room.bin"
        * = DOOR
        !bin "src/intro/door.bin", $1000
        * = TITLE                   ; in the gap in door.bin, between its sprites and its bitmap
        !bin "src/intro/title.bin"
        * = DOOR + $2000
        !bin "src/intro/door.bin", , $2000
        * = DREAM
        !bin "src/intro/dream.bin"
