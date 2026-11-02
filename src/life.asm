; life.asm - Conway's Game of Life: the grid, the start pattern and the renderer
; Included by main.asm. Everything that knows how a generation is stored lives in this file.
;
; THE GRID: 1 bit per cell, 40 x 25 cells = 1000 bits = 125 bytes.
;
;       row r, column c   ->   byte  r * 5 + c / 8,   bit  7 - (c mod 8)
;
; So one row is 5 bytes, bit 7 of the first byte is column 0 and bit 0 of the last byte is column 39.
; A 1 bit is a living cell, a 0 bit a dead one. Because a row is exactly 5 bytes and a screen row is exactly
; 40 characters, grid byte i always lands on the screen at character i * 8. The renderer relies on that.

; ============================================================================================================
; Names
; ============================================================================================================
CUR       = $fb                     ; (2 bytes) pointer to the grid that holds the current generation
NXT       = $fd                     ; (2 bytes) pointer to the grid the next generation is written into

GRID_A    = $2000                   ; the two grids, each 125 bytes. Both start on a page boundary, so the
GRID_B    = $2100                   ; low byte of CUR and NXT is always 0 and only the high byte changes
GRID_SIZE = 125                     ; 25 rows of 5 bytes
ROW_BYTES = 5                       ; bytes per row
ROWS      = 25

CHAR_ALIVE = $51                    ; screen code of the filled ball
CHAR_DEAD  = $20                    ; screen code of the space

; The render tables: 8 tables of 256 bytes. Table k answers "what character goes in column k of a grid byte
; with this value": RENDER_TAB + k * 256 + value holds CHAR_ALIVE when bit 7 - k of the value is set and
; CHAR_DEAD when it is not. That turns 'test a bit and choose a character' into one indexed load.
RENDER_TAB = $3000                  ; $3000 - $37ff, filled by life_build_tables

; zero page scratch. The program switches the KERNAL interrupt off and never returns to BASIC, so the
; BASIC work area at the bottom of zero page is free to use.
GI        = $02                     ; render: index of the grid byte being drawn
TMP       = $03                     ; general scratch
PAT       = $04                     ; life_reset: index in the start pattern

; ============================================================================================================
; life_build_tables: fill the 8 render tables (once, at the start)
; ============================================================================================================
; For every possible byte value X (0..255) shift the value left 8 times. Each shift drops the next bit,
; starting with bit 7 (column 0), into the carry, and the carry picks the character for table k.

!macro render_tab_entry .k {
        lda #CHAR_DEAD
        asl TMP                     ; the bit for column .k goes into the carry
        bcc .dead
        lda #CHAR_ALIVE
.dead   sta RENDER_TAB + .k * 256,x
}

!zone life_build_tables
life_build_tables
        ldx #0
.next_value
        stx TMP                     ; TMP = the value whose bits we are taking apart
        !for k, 0, 7 {
        +render_tab_entry k
        }
        inx
        bne .next_value             ; all 256 values done when X wraps back to 0
        rts

; ============================================================================================================
; life_reset: empty the grid and plant the start pattern
; ============================================================================================================
; The start pattern is a list of (row, column) pairs ending with $ff. CUR is set to GRID_A and NXT to
; GRID_B, so after a reset the program always starts from the same state.

!zone life_reset
life_reset
        lda #0
        sta CUR                     ; low bytes: both grids start on a page boundary
        sta NXT
        lda #>GRID_A
        sta CUR+1
        lda #>GRID_B
        sta NXT+1

        ; --- clear the current grid ------------------------------------------------------------------------
        lda #0
        ldy #GRID_SIZE - 1
-       sta (CUR),y
        dey
        bpl -                       ; 124 down to 0: Y stays below 128, so BPL is the loop test

        ; --- set one bit per (row, column) pair ----------------------------------------------------------
        ldx #0
.next_cell
        lda start_pattern,x         ; the row, or $ff at the end of the list
        cmp #$ff
        beq .done
        tay
        lda row_offset,y            ; row * 5: the first byte of the row
        sta TMP
        lda start_pattern+1,x       ; the column
        lsr
        lsr
        lsr                         ; column / 8: which of the 5 bytes in the row
        clc
        adc TMP
        sta TMP                     ; TMP = the byte that holds the cell
        lda start_pattern+1,x
        and #7                      ; column mod 8: which bit, counted from the left
        tay
        lda bit_mask,y              ; $80 for column 0 of the byte, $01 for column 7
        ldy TMP
        ora (CUR),y                 ; switch the cell on, keep the others in the byte
        sta (CUR),y
        inx
        inx
        bne .next_cell              ; always taken: the list is far shorter than 128 pairs
.done
        rts

; ============================================================================================================
; life_render: draw the current generation on the screen
; ============================================================================================================
; Grid byte i becomes screen characters i * 8 .. i * 8 + 7. X walks over the screen in steps of 8, but an
; 8-bit register only reaches 256 characters, so the screen is drawn in 4 strips of 32 grid bytes
; (256 characters). The last strip has only 29 grid bytes (232 characters), together exactly 1000.
; Per grid byte: read it, use it as the index Y in the 8 render tables, store 8 characters.

!macro render_strip .first, .count, .screen {
        lda #.first
        sta GI
        ldx #0                      ; X = the character inside this strip
.next_byte
        ldy GI
        lda (CUR),y                 ; the grid byte with 8 cells
        tay
        !for k, 0, 7 {
        lda RENDER_TAB + k * 256,y  ; the character for column k of this byte
        sta .screen + k,x
        }
        inc GI
        txa
        clc
        adc #8                      ; 8 characters further on the screen
        tax
        cpx #<(.count * 8)          ; end of the strip (for 32 bytes that is 256, which wraps to 0)
        bne .next_byte
}

!zone life_render
life_render
        +render_strip  0, 32, SCREEN
        +render_strip 32, 32, SCREEN + $100
        +render_strip 64, 32, SCREEN + $200
        +render_strip 96, 29, SCREEN + $300
        rts

; ============================================================================================================
; Data
; ============================================================================================================
row_offset                          ; row * 5, the first grid byte of every row
        !for r, 0, ROWS - 1 {
        !byte r * ROW_BYTES
        }

bit_mask                            ; the bit for column c mod 8 of a byte: column 0 is the leftmost, bit 7
        !byte $80, $40, $20, $10, $08, $04, $02, $01

; The start pattern: (row, column) pairs, $ff ends the list.
; A glider in the top left corner that moves 1 cell down and 1 cell right every 4 generations, and a blinker
; on the right that flips between horizontal and vertical every generation. After 20 generations the glider
; has only moved 5 cells (rows 7-9, columns 7-9), the blinker stays in rows 11-13, columns 25-27: they are far
; apart, so what you see is only the rules at work.
;
;       glider (rows 2-4, columns 2-4)      blinker (row 12, columns 25-27)
;           . O .                               O O O
;           . . O
;           O O O
start_pattern
        !byte 2, 3
        !byte 3, 4
        !byte 4, 2, 4, 3, 4, 4
        !byte 12, 25, 12, 26, 12, 27
        !byte $ff
