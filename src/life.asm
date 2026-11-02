; life.asm - Conway's Game of Life: the grid, the start pattern, the generation step and the renderer
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

; The sum tables of the generation step (see life_step). One entry per grid byte, so 8 cells per entry.
; The H3 tables have 5 extra bytes before and after: a copy of the last row in front and a copy of the first
; row behind. Entry i + 5 belongs to grid byte i, so 'the row above' of byte i is simply entry i and 'the row
; below' is entry i + 10, also for the top and bottom rows: that is the vertical wraparound.
H3S       = $2200                   ; (135 bytes) bit 0 of the sum left + self + right
H3C       = $2300                   ; (135 bytes) bit 1 of that sum (the carry)
H2S       = $2400                   ; (125 bytes) bit 0 of the sum left + right (self not counted)
H2C       = $2480                   ; (125 bytes) bit 1 of that sum

; zero page scratch. The program switches the KERNAL interrupt off and never returns to BASIC, so the
; BASIC work area at the bottom of zero page is free to use.
GI        = $02                     ; render: index of the grid byte being drawn
TMP       = $03                     ; general scratch
B0        = $04                     ; life_step pass 1: the 5 bytes of the row being summed, B0 = column 0-7
B1        = $05
B2        = $06
B3        = $07
B4        = $08                     ; ... B4 = columns 32-39
LEFT      = $09                     ; pass 1: for each of 8 cells its left neighbour
RIGHT     = $0a                     ; pass 1: for each of 8 cells its right neighbour
X12       = $0b                     ; pass 2: s1 XOR s2
ONES      = $0c                     ; pass 2: bit 0 of the neighbour count, OR the cell itself
K1        = $0d                     ; pass 2: carry out of the ones column
Q         = $0e                     ; pass 2: c3 XOR k1
BOTH      = $0f                     ; pass 2: a pair of the twos column that is both 1

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
; life_step: compute the next generation from CUR into NXT, then swap CUR and NXT
; ============================================================================================================
; BIT-SLICED: 8 cells are worked on at once, one per bit. A neighbour count is 0..8 and needs 4 bits, so
; for 8 cells we keep 4 bytes: byte 'bit 0 of the count', byte 'bit 1 of the count', and so on, and add with
; AND/OR/EOR exactly like a hardware adder does, one bit position per cell. No loop ever looks at one cell.
;
;       half adder   a + b      = sum a EOR b,          carry a AND b
;       full adder   a + b + c  = sum a EOR b EOR c,    carry (a AND b) OR (c AND (a EOR b))
;
; The 8 neighbours of a cell are 3 in the row above (left, up, right), 2 in its own row (left, right) and 3
; in the row below. Each row's sum is a 2-bit number (s, c), so:
;
;       above:  s1 + 2 * c1         (full adder over left, self, right of the row above: 0..3)
;       below:  s2 + 2 * c2         (the same for the row below)
;       own:    s3 + 2 * c3         (half adder over left and right: the cell itself does not count)
;
;       count = (s1 + s2 + s3)  +  2 * (c1 + c2 + c3)
;             =  S0 + 2 * k1    +  2 * (c1 + c2 + c3)      full adder over s1, s2, s3: sum S0, carry k1
;             =  S0 + 2 * t                                with t = c1 + c2 + c3 + k1, so 0..4
;
; THE RULES then become very short. Survive with 2 or 3, birth with 3: a cell lives in the next generation
; when the count is 3, or when it is 2 and the cell is alive now. Count 2 or 3 means t = 1 exactly (S0 is
; then 0 or 1), and from those two the 3 needs S0 = 1 and the 2 needs the cell alive:
;
;       next = (t == 1) AND (S0 OR self)
;
; "exactly one of the four bits c1, c2, c3, k1" is: an odd number of them (1 or 3), but no pair of them both
; set (that would make 2 or more, so with an odd total 3):
;
;       t == 1  =  (c1 EOR c2 EOR c3 EOR k1)  AND NOT ((c1 AND c2) OR (c3 AND k1))
;
; TWO PASSES, because every row is the 'above' row for one row and the 'below' row for another. Pass 1
; works out the per-row sums once for every grid byte and keeps them in the H tables, pass 2 combines three
; rows into the new generation.

; --- pass 1, one grid byte: .p, .c, .n are the zero page bytes left of, at and right of it in the row -------
; LEFT and RIGHT are the neighbour bytes: bit k of LEFT is the cell to the left of the cell in bit k of .c.
; Column 0 is bit 7, so the left neighbour is one bit HIGHER, and the cell in bit 7 takes its left neighbour
; from bit 0 of the byte before it. LSR of that byte puts its bit 0 in the carry, and ROR of .c shifts .c one
; place right and lets that carry in at bit 7. The right neighbours are the mirror image: ASL of the next
; byte puts its bit 7 (its column 0) in the carry, ROL of .c lets it in at bit 0.
; For the first and last byte of a row the 'byte before' and 'byte after' are the other end of the same row,
; which is the horizontal wraparound.
!macro row_sums .p, .c, .n, .j {
        lda .p
        lsr                         ; carry = the cell just left of this byte
        lda .c
        ror
        sta LEFT                    ; the 8 left neighbours
        lda .n
        asl                         ; carry = the cell just right of this byte
        lda .c
        rol
        sta RIGHT                   ; the 8 right neighbours
        eor LEFT                    ; half adder left + right: sum ...
        sta TMP
        sta H2S + .j,x
        eor .c                      ; ... and with the cell itself (full adder): sum
        sta H3S + 5 + .j,x
        lda .c
        and TMP                     ; self AND (left EOR right)
        sta TMP
        lda LEFT
        and RIGHT                   ; carry of left + right
        sta H2C + .j,x
        ora TMP                     ; carry of left + self + right
        sta H3C + 5 + .j,x
}

!zone life_step
life_step
        ; --- pass 1: the row sums of every grid byte -------------------------------------------------------
        ldx #0                      ; X = the first byte of the row, 0, 5, 10 ... 120
.row
        txa
        tay
        lda (CUR),y                 ; the 5 bytes of the row into zero page, each is used 3 times
        sta B0
        iny
        lda (CUR),y
        sta B1
        iny
        lda (CUR),y
        sta B2
        iny
        lda (CUR),y
        sta B3
        iny
        lda (CUR),y
        sta B4
        +row_sums B4, B0, B1, 0     ; byte 0: its left neighbour is byte 4 (wraparound)
        +row_sums B0, B1, B2, 1
        +row_sums B1, B2, B3, 2
        +row_sums B2, B3, B4, 3
        +row_sums B3, B4, B0, 4     ; byte 4: its right neighbour is byte 0 (wraparound)
        txa
        clc
        adc #ROW_BYTES
        tax
        cpx #GRID_SIZE
        beq .rows_done
        jmp .row                    ; the 5 row_sums make the loop too long for a branch back
.rows_done

        ; --- the vertical wraparound: last row in front of the H3 tables, first row behind them ------------
        ldx #ROW_BYTES - 1
-       lda H3S + 5 + GRID_SIZE - ROW_BYTES,x
        sta H3S,x                   ; entries 0-4: row 24, the row above row 0
        lda H3C + 5 + GRID_SIZE - ROW_BYTES,x
        sta H3C,x
        lda H3S + 5,x
        sta H3S + 5 + GRID_SIZE,x   ; entries 130-134: row 0, the row below row 24
        lda H3C + 5,x
        sta H3C + 5 + GRID_SIZE,x
        dex
        bpl -

        ; --- pass 2: count and apply the rules, 8 cells per byte -------------------------------------------
        ; Y = the grid byte. H3x,y is the row above, H3x + 10,y the row below, H2x,y the own row.
        ldy #GRID_SIZE - 1
.next_byte
        lda H3S,y                   ; s1
        eor H3S + 10,y              ; s1 EOR s2
        sta X12
        eor H2S,y                   ; S0 = s1 EOR s2 EOR s3: bit 0 of the count
        ora (CUR),y                 ; S0 OR self: everything the rules need from bit 0 and the cell itself
        sta ONES
        lda H2S,y
        and X12                     ; s3 AND (s1 EOR s2)
        sta K1
        lda H3S,y
        and H3S + 10,y              ; s1 AND s2
        ora K1
        sta K1                      ; k1: the carry of s1 + s2 + s3, it counts as 2 like c1, c2, c3

        ; the twos column: c1, c2, c3, k1. Is exactly one of them set?
        eor H2C,y                   ; k1 EOR c3
        sta Q
        lda H2C,y
        and K1                      ; c3 AND k1
        sta BOTH
        lda H3C,y
        and H3C + 10,y              ; c1 AND c2
        ora BOTH
        sta BOTH                    ; a pair with both bits set
        lda H3C,y
        eor H3C + 10,y              ; c1 EOR c2
        eor Q                       ; c1 EOR c2 EOR c3 EOR k1: an odd number of them
        ora BOTH
        eor BOTH                    ; odd AND NOT both (OR then EOR clears exactly the bits of BOTH)
        and ONES                    ; (t == 1) AND (S0 OR self)
        sta (NXT),y                 ; 8 cells of the next generation
        dey
        bpl .next_byte              ; 124 down to 0

        ; --- swap: the new generation becomes the current one. Only the pointers change, no bytes move ----
        lda CUR+1
        ldx NXT+1
        sta NXT+1
        stx CUR+1
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
