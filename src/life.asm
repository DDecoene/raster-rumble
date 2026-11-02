; life.asm - Conway's Game of Life: the grid, the start patterns, the generation step and the renderer
; Included by main.asm. Everything that knows how a generation is stored lives in this file.
;
; THE GRID: 1 bit per cell, 40 x 24 cells = 960 bits = 120 bytes. The 25th screen row is the status bar.
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

GRID_A    = $2000                   ; the two grids, each 120 bytes. Both start on a page boundary, so the
GRID_B    = $2100                   ; low byte of CUR and NXT is always 0 and only the high byte changes
ROWS      = 24                      ; rows of cells (the screen has 25, the last one is the status bar)
ROW_BYTES = 5                       ; bytes per row
GRID_SIZE = ROWS * ROW_BYTES        ; 120

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
H3S       = $2200                   ; (130 bytes) bit 0 of the sum left + self + right
H3C       = $2300                   ; (130 bytes) bit 1 of that sum (the carry)
H2S       = $2400                   ; (120 bytes) bit 0 of the sum left + right (self not counted)
H2C       = $2480                   ; (120 bytes) bit 1 of that sum

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
PTR       = $10                     ; (2 bytes) life_plant: the pattern being planted
PCOL      = $12                     ; life_plant: the column of the cell being planted
PIDX      = $13                     ; life_plant: index in the pattern
SEED      = $14                     ; (2 bytes) life_random: state of the random number generator, never 0

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
; life_clear: point CUR at GRID_A and NXT at GRID_B, and empty the current grid
; ============================================================================================================
; After every reset the program starts from the same state, whichever grid was current before.

!zone life_clear
life_clear
        lda #0
        sta CUR                     ; low bytes: both grids start on a page boundary
        sta NXT
        lda #>GRID_A
        sta CUR+1
        lda #>GRID_B
        sta NXT+1
        lda #0
        ldy #GRID_SIZE - 1
-       sta (CUR),y
        dey
        bpl -                       ; 119 down to 0: Y stays below 128, so BPL is the loop test
        rts

; ============================================================================================================
; life_plant: empty grid with the pattern in A (0 .. PATTERN_COUNT - 1)
; ============================================================================================================
; A pattern is a list of (row, column) pairs ending with $ff. pattern_lo / pattern_hi (at the end of this
; file) hold the address of every pattern.

!zone life_plant
life_plant
        tax
        lda pattern_lo,x
        sta PTR
        lda pattern_hi,x
        sta PTR+1
        jsr life_clear

        ldy #0
.next_cell
        lda (PTR),y                 ; the row, or $ff at the end of the list
        cmp #$ff
        beq .done
        tax
        lda row_offset,x            ; row * 5: the first byte of the row
        sta TMP
        iny
        lda (PTR),y                 ; the column
        sta PCOL
        iny
        sty PIDX                    ; Y is needed below to reach the grid byte
        lsr
        lsr
        lsr                         ; column / 8: which of the 5 bytes in the row
        clc
        adc TMP
        tay                         ; Y = the grid byte that holds the cell
        lda PCOL
        and #7                      ; column mod 8: which bit, counted from the left
        tax
        lda bit_mask,x              ; $80 for column 0 of the byte, $01 for column 7
        ora (CUR),y                 ; switch the cell on, keep the others in the byte
        sta (CUR),y
        ldy PIDX
        bne .next_cell              ; always taken: Y is at least 2 here
.done
        rts

; ============================================================================================================
; life_random: fill the grid with random cells, about 3 in 8 alive
; ============================================================================================================
; The random numbers come from a 16-bit xorshift generator (shifts 7, 9, 8): fast, and it only repeats
; after 65535 numbers. It must never hold 0, because 0 stays 0.
; Before every fill the seed is stirred with two things that differ every time: the low byte of CIA 1 timer A
; (it keeps counting down every cycle: the KERNAL set it running and SEI only stops its interrupt) and the
; raster line. Both depend on the exact moment R was pressed, so every R gives another world.
; One random byte alone would make half the cells alive, which chokes itself within a few generations.
; r1 AND (r2 OR r3) keeps a bit with chance 1/2 x 3/4 = 3/8, a density where Life stays busy for long.

!zone life_random
life_random
        jsr life_clear              ; for the pointers; every byte is overwritten below
        lda CIA1_TA_LO
        eor SEED
        sta SEED
        lda VIC_RASTER
        eor SEED+1
        sta SEED+1
        lda SEED
        ora SEED+1
        bne +
        inc SEED                    ; a seed of 0 would give 0 forever
+       ldy #GRID_SIZE - 1
.next_byte
        jsr random
        sta TMP
        jsr random
        sta PCOL
        jsr random
        ora PCOL                    ; r2 OR r3: 3 in 4 bits set
        and TMP                     ; AND r1: 3 in 8
        sta (CUR),y
        dey
        bpl .next_byte
        rts

; random: the next number of the xorshift generator in A (and in SEED). Changes only A and the flags.
random
        lda SEED+1
        lsr
        lda SEED
        ror
        eor SEED+1
        sta SEED+1                  ; seed ^= seed << 7 ... (the high byte part)
        ror
        eor SEED
        sta SEED                    ; ... seed ^= seed >> 9 ...
        eor SEED+1
        sta SEED+1                  ; ... seed ^= seed << 8
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
        sta H3S,x                   ; entries 0-4: the last row, the row above row 0
        lda H3C + 5 + GRID_SIZE - ROW_BYTES,x
        sta H3C,x
        lda H3S + 5,x
        sta H3S + 5 + GRID_SIZE,x   ; entries 125-129: row 0, the row below the last row
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
        bpl .next_byte              ; 119 down to 0

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
; (256 characters). The last strip has only 24 grid bytes (192 characters), together the 960 characters of
; the 24 rows above the status bar.
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
        +render_strip 96, GRID_SIZE - 96, SCREEN + $300
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

; ------------------------------------------------------------------------------------------------------------
; The fixed patterns. F on the keyboard steps through them, the status bar shows the name.
; TO ADD ONE: write its (row, column) pairs ending with $ff and its name (lower case in the source becomes
; upper case on the screen, at most 21 characters, ending with 0), then add it to the four tables below.
; PATTERN_COUNT follows by itself.
; ------------------------------------------------------------------------------------------------------------
pattern_lo   !byte <pat_glider, <pat_rpent, <pat_acorn, <pat_gun
pattern_hi   !byte >pat_glider, >pat_rpent, >pat_acorn, >pat_gun
pat_name_lo  !byte <name_glider, <name_rpent, <name_acorn, <name_gun
pat_name_hi  !byte >name_glider, >name_rpent, >name_acorn, >name_gun
PATTERN_COUNT = pattern_hi - pattern_lo

; A glider in the top left corner that moves 1 cell down and 1 cell right every 4 generations, and a blinker
; on the right that flips between horizontal and vertical every generation. After 20 generations the glider
; has only moved 5 cells (rows 7-9, columns 7-9), the blinker stays in rows 11-13, columns 25-27: they are far
; apart, so what you see is only the rules at work. This is the test pattern, shown at the start.
;
;       glider (rows 2-4, columns 2-4)      blinker (row 12, columns 25-27)
;           . O .                               O O O
;           . . O
;           O O O
pat_glider
        !byte 2, 3
        !byte 3, 4
        !byte 4, 2, 4, 3, 4, 4
        !byte 12, 25, 12, 26, 12, 27
        !byte $ff
name_glider !scr "glider + blinker", 0

; The R-pentomino: 5 cells that keep changing for more than 1100 generations on an endless plane.
;           . O O
;           O O .
;           . O .
pat_rpent
        !byte 11, 20, 11, 21
        !byte 12, 19, 12, 20
        !byte 13, 20
        !byte $ff
name_rpent !scr "r-pentomino", 0

; The acorn: 7 cells, more than 5000 generations of growth on an endless plane. On this small torus the
; debris meets itself much earlier.
;           . O . . . . .
;           . . . O . . .
;           O O . . O O O
pat_acorn
        !byte 11, 17
        !byte 12, 19
        !byte 13, 16, 13, 17, 13, 20, 13, 21, 13, 22
        !byte $ff
name_acorn !scr "acorn", 0

; Gosper's glider gun (Bill Gosper, 1970): it shoots a new glider every 30 generations, down and to the right.
; On this small torus the first glider comes back round after 60 to 90 generations and wrecks the gun:
; from then on it is chaos, but the start of it is the real gun.
; 36 x 9 cells, here at rows 1-9, columns 1-36:
;           . . . . . . . . . . . . . . . . . . . . . . . . O . . . . . . . . . . .
;           . . . . . . . . . . . . . . . . . . . . . . O . O . . . . . . . . . . .
;           . . . . . . . . . . . . O O . . . . . . O O . . . . . . . . . . . . O O
;           . . . . . . . . . . . O . . . O . . . . O O . . . . . . . . . . . . O O
;           O O . . . . . . . . O . . . . . O . . . O O . . . . . . . . . . . . . .
;           O O . . . . . . . . O . . . O . O O . . . . O . O . . . . . . . . . . .
;           . . . . . . . . . . O . . . . . O . . . . . . . O . . . . . . . . . . .
;           . . . . . . . . . . . O . . . O . . . . . . . . . . . . . . . . . . . .
;           . . . . . . . . . . . . O O . . . . . . . . . . . . . . . . . . . . . .
GUN_R = 1
GUN_C = 1
!macro gun_cell .r, .c {
        !byte GUN_R + .r, GUN_C + .c
}
pat_gun
        +gun_cell 0, 24
        +gun_cell 1, 22
        +gun_cell 1, 24
        +gun_cell 2, 12
        +gun_cell 2, 13
        +gun_cell 2, 20
        +gun_cell 2, 21
        +gun_cell 2, 34
        +gun_cell 2, 35
        +gun_cell 3, 11
        +gun_cell 3, 15
        +gun_cell 3, 20
        +gun_cell 3, 21
        +gun_cell 3, 34
        +gun_cell 3, 35
        +gun_cell 4, 0
        +gun_cell 4, 1
        +gun_cell 4, 10
        +gun_cell 4, 16
        +gun_cell 4, 20
        +gun_cell 4, 21
        +gun_cell 5, 0
        +gun_cell 5, 1
        +gun_cell 5, 10
        +gun_cell 5, 14
        +gun_cell 5, 16
        +gun_cell 5, 17
        +gun_cell 5, 22
        +gun_cell 5, 24
        +gun_cell 6, 10
        +gun_cell 6, 16
        +gun_cell 6, 24
        +gun_cell 7, 11
        +gun_cell 7, 15
        +gun_cell 8, 12
        +gun_cell 8, 13
        !byte $ff
name_gun !scr "glider gun", 0
