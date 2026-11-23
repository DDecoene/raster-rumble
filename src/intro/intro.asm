; intro.asm - the intro of the film, shot by shot (see docs/story.md). A program of its own, the game is not in it.
; For now: shot 1. It plays and starts again.
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
TEXT_POS  = 22 * 40 + 6             ; the first letter: row 22, column 6
HUM       = 5                       ; the loudest the hum gets (0-15)

frame     = $02                     ; frames since the shot began, 2 bytes
typed     = $04                     ; letters on the screen
wait      = $05                     ; frames until the next letter
light     = $06                     ; the colour screen that shows (0-6)
nod       = $07                     ; frames the head stays one line lower
rnd       = $08                     ; random number
look      = $09                     ; how far the head is turned to the magazine, in pixels
random_light = $0a                  ; frames left of a flicker

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

shot1                               ; everything to the start of the shot
        ldx #24                     ; the SID silent
        lda #0
-       sta $d400,x
        dex
        bpl -
        sta frame
        sta frame + 1
        sta typed
        sta light
        sta nod
        sta look
        sta random_light
        sta SPR_ENABLE
        lda #1
        sta wait
        ldx #TEXT_LEN - 1           ; hide the sentence: black on black, in the two screens it shows on
        lda #0
-       sta ROOM + 5 * $400 + TEXT_POS,x
        sta ROOM + 5 * $400 + TEXT_POS + 40,x
        sta ROOM + 6 * $400 + TEXT_POS,x
        sta ROOM + 6 * $400 + TEXT_POS + 40,x
        dex
        bpl -
        lda #0
        sta SPR2_COLOR              ; sprites 2 and 3: the head, black
        sta SPR2_COLOR + 1

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
        lda #$f0
        sta SID_SR1                 ; as loud as it gets, all the time
        lda #$60
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
        lda light                   ; show the colour screen: its number * 16, plus 8 for the bitmap at $6000
        asl
        asl
        asl
        asl
        ora #$08
        sta VIC_MEMCTL
        jsr place_head
        jsr key_off
        jsr fade
        jsr type
        inc frame
        bne +
        inc frame + 1
+       lda frame + 1
        cmp #>700                   ; 14 seconds
        bne +
        lda frame
        cmp #<700
        bne +
        jmp shot1                   ; from the start again
+       lda VIC_RASTER              ; the work is done within one line sometimes: do not run twice on line 251
-       cmp VIC_RASTER
        beq -
        jmp loop

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
        lda random_light
        beq +
        dec random_light
        lda #6                      ; the light is a little weaker now
        sta light
        rts
+       lda #5
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
        ldx typed
        lda #$10                    ; white on black
        sta ROOM + 5 * $400 + TEXT_POS,x
        sta ROOM + 5 * $400 + TEXT_POS + 40,x
        sta ROOM + 6 * $400 + TEXT_POS,x
        sta ROOM + 6 * $400 + TEXT_POS + 40,x
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
++      lda #3
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

key_off                             ; subroutine: let the key go
        lda #$80
        sta SID_CTRL3
        rts

!zone place_head
place_head                          ; subroutine: the head, two sprites high, and the rim of light in front of it
        ldy #0
        lda light
        cmp #4                      ; no head in the dark: the picture is black there anyway
        bcc +
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
fade_hum   !byte 0, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, HUM, HUM, HUM, HUM
out_light  !byte 5, 4, 4, 3, 2, 1, 0, 0
rim_color  !byte 0, 6, 6, 6, 14, 3, 14, 0
text_wait                           ; frames after every letter of "He typed it in. Every line."
        !byte 7, 12, 14, 6, 7, 5, 6, 8, 13, 6, 9, 15, 7, 8, 48, 6, 6, 8, 5, 7, 9, 14, 6, 7, 6, 9, 5

        * = ROOM
        !bin "src/intro/room.bin"
