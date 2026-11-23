; intro.asm - the intro of the film, shot by shot (see docs/story.md). A program of its own, the game is not in it.
; For now: shots 1 to 3. They play and start again.
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
DOOR      = $8000                   ; door.bin: three colour screens, the sprites; its bitmap is at $a000
BED       = $3000                   ; bed.bin: the cells that change when he is in bed
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
shot      = $0b                     ; 0 = shot 1, 1 = shot 2, 2 = the door, 3 = the bed (both shot 3)
sink      = $0c                     ; how far the head hangs down, in lines
beat      = $0d                     ; frame / 4 (not in shot 1)
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
        sta shot
        sta in_bed
        sta SPR2_COLOR              ; sprites 2 and 3: the head, black
        sta SPR2_COLOR + 1

new_shot                            ; everything to the start of the shot in the variable 'shot'
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
.go_on  sta frame
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
        jsr load_text
        lda #0                      ; must he be in bed in this shot?
        ldx shot
        cpx #3
        bne +
        lda #1
+       cmp in_bed
        beq +
        sta in_bed
        jsr swap_bed
+

        ; the hum: two low voices through the low-pass filter. 852 = 50 Hz, 1710 = just above 100 Hz
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
        lda CIA2_PORTA              ; 0 to 6: the room, at $4000. 7 to 9: the door is open, at $8000
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
        clc
        adc #1
        and #3
        sta shot
        jmp new_shot
+       lda VIC_RASTER              ; the work can be done within one line: do not run twice on line 251
-       cmp VIC_RASTER
        beq -
        jmp loop

shot_end_lo !byte <700, <800, <560, <480        ; 14, 16, 11 and 10 seconds
shot_end_hi !byte >700, >800, >560, >480

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
        cmp #100
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
        bne .full                   ; after 256 frames: full light
        lda frame
        lsr
        lsr
        lsr
        lsr                         ; frame / 16 = 0 to 15
        tax
        lda fade_light,x
        sta light
        lda fade_hum,x
        ora #$10                    ; low-pass filter on
        sta SID_VOLUME
        rts
.full
        cmp #>700                   ; the last part of the shot?
        bne .flicker
        lda frame
        cmp #<640
        bcc .flicker
        sec
        sbc #<640
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
        beq .done                   ; first 256 frames: no typing yet
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
        !bin "src/intro/door.bin"
