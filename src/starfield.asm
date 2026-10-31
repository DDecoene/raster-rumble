; starfield.asm - the RAM character set, the scrolling stars and random_column
; (random_column is also used by spawn_enemy in actors.asm)

!zone setup_charset
setup_charset                       ; subroutine: copy the ROM letters/digits to RAM and add 8 star shapes
        lda CPU_PORT                ; current memory configuration
        and #%11111011              ; clear bit 2: the character ROM now shows at $d000 (I/O is hidden)
        sta CPU_PORT                ; interrupts are off, so nothing else is using $d000 meanwhile
        ldx #0                      ; X counts 0 to 255
.copy
        lda $d000,x                 ; ROM shapes of screen codes 0-31 (letters), first page
        sta CHARSET,x               ; copy to our RAM charset
        lda $d100,x                 ; screen codes 32-63 (space, digits), second page
        sta CHARSET + $100,x        ; copy
        inx                         ; next byte
        bne .copy                   ; until X wrapped around to 0
        lda CPU_PORT                ; memory configuration again
        ora #%00000100              ; set bit 2: I/O is back at $d000
        sta CPU_PORT                ; done with the ROM
        ldx #63                     ; clear the 8 shapes (8 bytes each) of screen codes 64-71
        lda #0                      ; empty
.clear
        sta CHARSET + 512,x         ; shape bytes are 0
        dex                         ; previous byte
        bpl .clear                  ; until X goes below 0
        lda #%00011000              ; a 2 pixel wide dot in the middle of the 8 pixels
!for k, 0, 7 {
        sta CHARSET + 512 + 9 * k   ; star shape k: the dot sits in pixel row k (8 bytes per shape + k)
}
        lda #$1a                    ; screen memory at $0400 (high nibble 1), characters at $2800 (5 * $800)
        sta VIC_MEMCTL              ; the VIC now reads our charset
        rts                         ; return to the caller

!zone setup_stars
setup_stars                         ; subroutine: stars on rows 1, 3, 5 ... 23, each in a random column
        lda #<(SCREEN + 40)         ; address of row 1, column 0 (row 0 holds the score)
        sta star_ptr                ; low byte
        lda #>(SCREEN + 40)         ; high byte
        sta star_ptr + 1            ; high byte
        ldx #STARS - 1              ; star number, counting down
.next
        jsr random_column           ; A = a random screen column 0-39
        clc                         ; clear carry before adding
        adc star_ptr                ; row address + column
        sta star_lo,x               ; store this star's address, low byte
        lda star_ptr + 1            ; high byte of the row
        adc #0                      ; plus carry
        sta star_hi,x               ; store it
        lda star_ptr                ; move the row pointer down 2 rows = 80 characters
        clc                         ; clear carry
        adc #80                     ; + 80
        sta star_ptr                ; low byte
        bcc .nocarry                ; no overflow
        inc star_ptr + 1            ; overflow: high byte + 1
.nocarry
        txa                         ; speed depends on the star number: 1, 2 or 3 pixels per frame
        and #%00000011              ; 0-3
        cmp #3                      ; 3 would be too many ...
        bcc .speed                  ; 0, 1, 2 are fine
        lda #0                      ; ... so make it 0
.speed
        tay                         ; Y = 0, 1 or 2
        lda speed_table,y           ; pixels per frame
        sta star_spd,x              ; store the speed
        lda colour_table,y          ; far (slow) stars are dark, near (fast) stars bright
        sta star_col,x              ; store the colour
        lda #0                      ; sub-pixel position 0
        sta star_sub,x              ; start at the top of its cell
        dex                         ; next star
        bpl .next                   ; until X goes below 0
        rts                         ; return to the caller

!zone update_stars
update_stars                        ; subroutine: erase every star, move it down, draw it again
        ldx #STARS - 1              ; star number, counting down
.loop
        lda star_lo,x               ; screen address of this star, low byte
        sta star_ptr                ; into the zero page pointer
        lda star_hi,x               ; high byte
        sta star_ptr + 1            ; into the pointer
        ldy #0                      ; (pointer),y with Y = 0 means "the byte the pointer points at"
        lda #$20                    ; space
        sta (star_ptr),y            ; erase the star
        lda star_sub,x              ; pixel row inside the cell (0-7)
        clc                         ; clear carry before adding
        adc star_spd,x              ; move down by the star's speed
        cmp #8                      ; past the bottom of the cell?
        bcc .draw                   ; no, same cell, just a different shape
        sbc #8                      ; yes: back into 0-7 (carry is set here) ...
        sta star_sub,x              ; (store it before the address changes)
        lda star_ptr                ; ... and one row down = + 40 characters
        clc                         ; clear carry
        adc #40                     ; + 40
        sta star_ptr                ; low byte
        bcc .check                  ; no overflow
        inc star_ptr + 1            ; overflow: high byte + 1
.check
        lda star_ptr + 1            ; did the star leave the screen? Screen ends at $07e8
        cmp #7                      ; high byte below 7 is still on screen
        bcc .draw2                  ; fine
        lda star_ptr                ; high byte is 7: look at the low byte
        cmp #$e8                    ; $07e8 or more is past the last row
        bcc .draw2                  ; fine
        jsr random_column           ; respawn at the top in a random column 0-39 (returned in A)
        clc                         ; clear carry
        adc #<(SCREEN + 40)         ; plus the address of row 1, column 0
        sta star_ptr                ; low byte
        lda #>(SCREEN + 40)         ; high byte of row 1
        sta star_ptr + 1            ; high byte
        lda star_sub,x              ; keep the pixel row it had, it flows straight on into .draw
.draw
        sta star_sub,x              ; remember the new pixel row
.draw2
        lda star_ptr                ; remember where the star is now
        sta star_lo,x               ; low byte
        lda star_ptr + 1            ; high byte
        sta star_hi,x               ; store it
        lda star_sub,x              ; the pixel row decides which of the 8 shapes to use
        ora #STAR_CHAR              ; screen code 64 + row
        sta (star_ptr),y            ; draw the star
        lda star_ptr                ; colour RAM is at screen address + $d400
        sta star_cptr               ; low byte is the same
        lda star_ptr + 1            ; high byte
        clc                         ; clear carry
        adc #$d4                    ; $04xx + $d400 = $d8xx
        sta star_cptr + 1           ; high byte
        lda star_col,x              ; this star's colour
        sta (star_cptr),y           ; colour the star
        dex                         ; next star
        bpl .loop                   ; until X goes below 0
        rts                         ; return to the caller

!zone random_byte
random_byte                         ; subroutine: A = a random byte (only A is changed)
        lda rnd                     ; the state: an 8 bit shift register with feedback (it visits all 255 values but 0)
        lsr                         ; shift right, the bit that falls off goes into the carry
        bcc .store                  ; it was 0: nothing more to do
        eor #$b8                    ; it was 1: flip the feedback bits
.store
        sta rnd                     ; the next state
        eor VIC_RASTER              ; mix in the raster line, so the answer also depends on when we ask
        rts                         ; return to the caller

!zone random_column
random_column                       ; subroutine: A = a random screen column 0-39
        jsr random_byte             ; random byte
        eor frame_count             ; mix in the frame counter: two reads a few cycles apart are strongly
                                    ; related, and throwing them away and re-reading left the stars bunched left
        eor star_ptr                ; and whatever the star code was working on, for a bit more variety
.reduce
        cmp #40                     ; already a column?
        bcc .done                   ; yes
        sbc #40                     ; no: subtract 40 (carry is set here) and look again
        bcs .reduce                 ; the carry is still set, so this always loops
.done
        rts                         ; return to the caller
