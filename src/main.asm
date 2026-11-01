; sandbox - my own C64 experiments
; Assembler: ACME   (build: make, run in the browser emulator: make test)
; ============================================================================================================
; Game of Life
; ============================================================================================================

!source "src/hardware.asm"          ; the names of the C64 chips and memory areas (SCREEN and so on)

GRID_A = $2000                      ; the grid: 1 bit per cell, 125 bytes * 8 bits = 1000 cells = 40 x 25

;Zero page pointers
SCREEN_PTR = $fb                    ; points to the screen position we draw the next cell on ($fb and $fc)
GRID_PTR = $fd                      ; points to the start of the grid in memory ($fd and $fe)

        * = $0801                   ; BASIC programs always start loading here

; BASIC stub: "10 SYS 2064", so typing RUN jumps into our machine code
        !word basic_end, 10         ; address of the next BASIC line, and this line's number (10)
        !byte $9e                   ; BASIC token for SYS
        !text "2064"                ; the address of 'start' as decimal text
        !byte 0                     ; end of this BASIC line
basic_end
        !word 0                     ; a next-line address of 0 means: end of the BASIC program

        * = 2064                    ; the machine code starts here, this is where SYS 2064 jumps to

start
        jsr init_pointers           ; set up the grid pointer and the screen pointer
        jsr render_grid             ; draw every cell of the grid on the screen
        rts                         ; nothing yet: back to BASIC

init_pointers
        lda #<GRID_A                ; low byte of the grid address
        sta GRID_PTR                ; store it in the low byte of the grid pointer
        lda #>GRID_A                ; high byte of the grid address
        sta GRID_PTR+1              ; store it in the high byte of the grid pointer
        lda #<SCREEN                ; low byte of the screen address
        sta SCREEN_PTR              ; store it in the low byte of the screen pointer
        lda #>SCREEN                ; high byte of the screen address
        sta SCREEN_PTR+1            ; store it in the high byte of the screen pointer
        rts                         ; back to the caller

render_grid
        ldx #0                      ; clear X (the bit counter below sets its own value, so this does nothing)

.byte_loop
        lda (GRID_PTR), y           ; read grid byte number Y (8 cells in one byte)
        sta .tmp_a                  ; keep it in memory, because we shift it bit by bit

        ldx #8                      ; X counts the 8 bits (cells) of this byte

.bit_loop
        asl .tmp_a                  ; shift the top bit out into the carry flag
        bcc .draw_dead              ; carry clear means the bit was 0: the cell is dead

.draw_alive
        lda #$A0                    ; screen code $a0 = a reversed space, a solid block
        jmp .write_screen           ; go and put it on the screen

.draw_dead
        lda #$20                    ; screen code $20 = a plain space, an empty spot

.write_screen
        sty .save_y                 ; save Y (the grid byte number), because we need Y for the screen pointer
        ldy #0                      ; (SCREEN_PTR),y with Y = 0 is exactly the address SCREEN_PTR points to
        sta (SCREEN_PTR),y          ; write the cell's screen code to the screen

        inc SCREEN_PTR              ; move the screen pointer on by one position (low byte first)
        bne +                       ; low byte did not wrap round to 0: the high byte stays the same
        inc SCREEN_PTR+1            ; low byte wrapped from $ff to 0: carry on into the high byte
+
        ldy .save_y                 ; get the grid byte number back in Y

        dex                         ; one cell of this byte is done
        bne .bit_loop               ; more bits left in this byte: do the next one

        iny                         ; this byte is done: on to the next grid byte
        cpy #125                    ; have we done all 125 bytes (1000 cells)?
        bne .byte_loop              ; no: go and read the next byte

        rts                         ; the whole grid is drawn: back to the caller

;temp vars
.tmp_a !byte 0                      ; the grid byte we are shifting bit by bit
.save_y !byte 0                     ; where Y is kept while we use it for the screen pointer
