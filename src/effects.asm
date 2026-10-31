; effects.asm - the demo effects inside the game: the explosion (a burst of sprites, a screen shake, fire bars)
; and the parallax bands. The raster bars themselves are drawn by game_bars in demo.asm.

!zone plasma_prep
plasma_prep                         ; subroutine: once per frame: the colour ramp, the phases and the horizontal wave of the 40 columns
        ldx #0                      ; the ramp: nebula ...
        lda exp_timer
        bne .fire
        lda dodge_flash
        beq .set
        ldx #2                      ; ... a glow just after a dodge ...
        bne .set                    ; (always)
.fire
        ldx #1                      ; ... fire while an explosion runs
.set
        lda ramp_lo,x               ; self-modifying code: the address of the ramp goes into the lda in plasma_step
        sta plasma_lda_ramp + 1
        lda ramp_hi,x
        sta plasma_lda_ramp + 2
        lda mood_bg1,x              ; the main colour of the plasma changes with the mood too
        sta VIC_BG1
        lda frame_count             ; the three waves drift at different speeds
        lsr
        sta plasma_ph1              ; horizontal: half a step per frame
        lda frame_count
        lsr
        lsr
        sta plasma_ph3
        eor #$ff
        sta plasma_ph2              ; vertical: a quarter step per frame, the other way
        lda plasma_ph3
        and #%00111111              ; the diagonal wave repeats every 64 steps
        sta plasma_ph3
        ldy plasma_ph1              ; the horizontal wave: sine of (10 * column + phase), the same for every row
        ldx #0
.col
        lda sine,y                  ; 0 to 63
        sta PLASMA_COLX,x
        tya
        clc
        adc #10
        tay
        inx
        cpx #40
        bne .col
        rts                         ; return to the caller

!zone plasma_step
plasma_step                         ; subroutine: colour one row of the plasma (the rows 1 to 24 come round one after the other) and put the stars back on it
        lda plasma_row              ; the vertical wave: sine of (16 * row + phase), one number for the whole row
        asl
        asl
        asl
        asl                         ; 16 * row (the part that does not fit in a byte does not matter: a sine repeats)
        clc
        adc plasma_ph2
        tay
        lda sine,y
        sta plasma_rowv
        ldy plasma_row
        lda crow_lo,y               ; self-modifying code: the colour RAM address of this row goes into the sta below
        sta .st + 1
        lda crow_hi,y
        sta .st + 2
        lda srow_lo,y               ; ... and the screen RAM address of this row into the second sta
        sta .sc + 1
        lda srow_hi,y
        sta .sc + 2
        tya                         ; the diagonal wave: dtab at (row + phase), then plus the column in the loop
        clc
        adc plasma_ph3
        clc
        adc #<dtab
        sta .d + 1                  ; and the address of that spot goes into the adc below
        lda #>dtab
        adc #0
        sta .d + 2
        ldx #39                     ; the 40 columns, counting down
        clc                         ; the sum never goes past 189, so the carry stays clear in the loop
.cell
        lda PLASMA_COLX,x           ; horizontal wave of this column ...
        adc plasma_rowv             ; ... plus the vertical wave of the row ...
.d      adc dtab,x                  ; ... plus the diagonal wave: 0 to 189
        tay
plasma_lda_ramp
        lda plasma_ramp,y           ; the colour for that number (the ramp is picked in plasma_prep)
.st     sta COLOR_RAM,x             ; into colour RAM
        lda plasma_code,y           ; and the screen code that goes with that number (with its background colour in bits 6 and 7)
.sc     sta SCREEN,x                ; into screen RAM
        dex
        bpl .cell
        ldy plasma_row              ; the plasma has just covered the stars of this row: draw them again
        lda srow_lo,y
        sta fx_tmp                  ; the address of the start of the row
        lda srow_hi,y
        sta plasma_rowv
        ldx #STARS - 1
.star
        lda star_lo,x               ; star address minus row start = column, if the high byte is then 0 and the column below 40 ...
        sec
        sbc fx_tmp
        tay
        lda star_hi,x
        sbc plasma_rowv
        bne .nostar
        cpy #40
        bcs .nostar                 ; ... the star is in this row
        lda star_lo,x
        sta star_ptr
        lda star_hi,x
        sta star_ptr + 1
        lda star_ptr                ; colour RAM is screen address + $d400
        sta star_cptr
        lda star_ptr + 1
        clc
        adc #$d4
        sta star_cptr + 1
        ldy #0
        lda (star_ptr),y            ; the plasma code that was just written under the star: remember it for when the star leaves ...
        sta star_ucode,x
        and #%11000000              ; ... and give the star the same background colour
        sta star_bg
        lda (star_cptr),y
        and #$0f
        sta star_ucol,x
        lda star_sub,x              ; its shape
        clc
        adc #STAR_CHAR
        ora star_bg
        sta (star_ptr),y
        lda star_col,x              ; and its colour
        sta (star_cptr),y
.nostar
        dex
        bpl .star
        inc plasma_row              ; next row, next time
        lda plasma_row
        cmp #25
        bcc +
        lda #1                      ; after row 24 back to row 1
        sta plasma_row
+       rts                         ; return to the caller

!zone plasma_init
plasma_init                         ; subroutine: colour all 24 rows of the playfield at once (a screen that was blank, or had text)
        jsr plasma_prep
        lda #1
        sta plasma_row
        lda #24
        sta plasma_cnt
.rows
        jsr plasma_step
        dec plasma_cnt
        bne .rows
        lda #%01011011              ; extended colour mode on (bit 6 of $d011), vertical scroll 3
        sta VIC_CTRL1
        rts                         ; return to the caller

!zone start_explosion
start_explosion                     ; subroutine: a hit! six sprites (2 to 7) fly out from where the enemy is, the screen shakes
        ldx #5                      ; particle number, counting down
.p
        lda SPR1_X                  ; start at the enemy: X low byte ...
        sta PART_LO,x
        lda SPR_XHI                 ; ... and bit 8 (the enemy's bit is bit 1: shift it down to bit 0)
        lsr
        and #%00000001
        sta PART_HI,x
        lda SPR1_Y                  ; ... Y
        sta PART_Y,x
        lda burst_dx,x              ; each particle has its own direction
        sta PART_DX,x
        lda burst_dy,x
        sta PART_DY,x
        lda #particle_data / 64     ; the dot shape (pointer 132)
        sta SPRITE2_PTR,x           ; (sprite 2 + X)
        lda SPR_ENABLE              ; switch the sprite on; update_particles gives it its position this same frame
        ora bit_tab,x
        sta SPR_ENABLE
        dex                         ; next particle
        bpl .p
        lda #EXP_FRAMES
        sta exp_timer               ; the explosion has started
        rts                         ; return to the caller

!zone update_particles
update_particles                    ; subroutine: once per frame: move the burst, change its colours, switch the sprites off at the end
        lda exp_timer               ; is there an explosion?
        beq .none                   ; no
        dec exp_timer               ; one frame older
        bne .go
        lda SPR_ENABLE              ; it is over: only the ship and the enemy stay on
        and #%00000011
        sta SPR_ENABLE
.none
        rts                         ; return to the caller
.go
        lda frame_count             ; the colour cycle: changes every 2 frames
        lsr
        sta fx_tmp
        ldx #5                      ; particle number, counting down
.next
        lda SPR_ENABLE              ; has this particle gone off the screen already?
        and bit_tab,x
        beq .skip                   ; yes
        lda PART_LO,x               ; X = X + dx, 9 bits: add the low bytes ...
        clc
        adc PART_DX,x
        sta PART_LO,x
        lda #0                      ; ... and the high part is 0, or $ff for a negative dx (sign extension), plus the carry
        ldy PART_DX,x               ; (ldy only sets the sign flag, the carry stays)
        bpl +
        lda #$ff
+       adc PART_HI,x
        sta PART_HI,x               ; 0 or 1 is on the screen, anything else (2 or $ff) is far outside
        cmp #2
        bcs .kill
        lda PART_Y,x                ; Y = Y + dy
        clc
        adc PART_DY,x
        sta PART_Y,x
        cmp #250                    ; below the screen?
        bcs .kill
        cmp #30                     ; above it?
        bcc .kill
        txa                         ; the sprite registers of sprite 2 + X are 2 * X further on
        asl
        tay
        lda PART_LO,x
        sta SPR2_X,y
        lda PART_Y,x
        sta SPR2_Y,y
        lda PART_HI,x               ; bit 8 of the X position
        beq .clear
        lda SPR_XHI
        ora bit_tab,x
        bne .storehi                ; (always)
.clear
        lda SPR_XHI
        and nbit_tab,x
.storehi
        sta SPR_XHI
        txa                         ; the colour: white, yellow, orange, red, every particle a step further on
        clc
        adc fx_tmp
        and #%00000011
        tay
        lda part_cols,y
        sta SPR2_COLOR,x
.skip
        dex
        bpl .next
        rts                         ; return to the caller
.kill
        lda SPR_ENABLE              ; this particle is gone
        and nbit_tab,x
        sta SPR_ENABLE
        jmp .skip

!zone update_bands
update_bands                        ; subroutine: once per frame: work out the shake and the scroll of the three bands
        lda #0
        sta shake_x                 ; no shake ...
        lda #3
        sta shake_y                 ; ... the normal vertical scroll is 3
        lda dodge_flash             ; the flash after a dodge counts down
        beq +
        dec dodge_flash
+       lda exp_timer               ; an explosion going on?
        beq .noshake
        lsr                         ; age / 4 = 0 to 7
        lsr
        tay
        lda shake_mask,y            ; how wild: 0, 1, 3 or 7 pixels
        beq .noshake
        sta fx_tmp
        jsr random_byte
        and fx_tmp
        sta shake_x                 ; sideways 0 up to the mask
        jsr random_byte
        and fx_tmp
        sta shake_y
        lda fx_tmp                  ; vertical: 3 plus a random number, minus half the mask, so it shakes around 3
        lsr
        sta fx_tmp
        lda shake_y
        sec
        sbc fx_tmp
        clc
        adc #3
        sta shake_y
.noshake
        lda #%01011000              ; $d011: extended colour mode, screen on, 25 rows, plus the vertical scroll. We are below the playfield now, so the VIC does not mind
        ora shake_y
        sta VIC_CTRL1
        lda SPR0_X                 ; parallax: the ship X / 8 (0 to 40) ...
        lsr
        lsr
        lsr
        tax
        lda SPR_XHI
        and #%00000001              ; ... plus 32 when the ship is on the right of X 255
        beq +
        txa
        clc
        adc #32
        tax
+       lda par_far,x               ; the far stars hardly move, the near stars a lot, and the shake is added to all of them
        clc
        adc shake_x
        and #%00000111
        ora #%11001000              ; keep 40 columns
        sta band1
        lda par_mid,x
        clc
        adc shake_x
        and #%00000111
        ora #%11001000
        sta band2
        lda par_near,x
        clc
        adc shake_x
        and #%00000111
        ora #%11001000
        sta band3
        rts                         ; return to the caller

!zone reset_scroll
reset_scroll                        ; subroutine: no shake, no scroll: the other screens need the normal values
        lda #%00011011              ; vertical scroll 3
        sta VIC_CTRL1
        lda #%11001000              ; no horizontal scroll
        sta VIC_CTRL2
        lda #0
        sta exp_timer               ; no explosion, no flash
        sta dodge_flash
        rts                         ; return to the caller
