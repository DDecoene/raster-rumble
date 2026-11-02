; sandbox - my own C64 experiments: Conway's Game of Life
; Assembler: ACME   (build: make, run in the browser emulator: make test)
;
; A 40 x 25 world, one cell per character, drawn as balls on the screen. The world is a torus: what leaves
; on the right comes back on the left, what leaves at the bottom comes back at the top.
; Space, or fire on the joystick in port 2, starts again from the start pattern.
;
; How a generation is stored and drawn is explained in life.asm.
;
; MEASURED with CIA 2 timer A (see 'Cycle measurement' below) in VICE x64sc, PAL. A frame has 19656 cycles.
;       life_step       25854 cycles = 1.32 frames   (24768 for the 6510 alone, the same for every pattern:
;                                                     the step has no branches that depend on the cells)
;       life_render     13639 cycles = 0.69 frame    (12555 for the 6510 alone)
; The difference is the VIC-II stealing the bus on badlines. Together about 2 frames per generation, so at
; FRAMES_PER_GEN = 0 the world runs at about 25 generations per second.

!source "src/hardware.asm"

; ============================================================================================================
; Names
; ============================================================================================================
FRAMES_PER_GEN = 6                  ; frames to wait after every generation, so the eye can follow it (0 = full speed)

; ============================================================================================================
; Cycle measurement with CIA 2 timer A
; ============================================================================================================
; The timer counts down from $ffff by one every cycle. Start it, run the code, stop it, and $ffff minus
; what is left is the number of cycles. The results stay in memory (cycles_render, ... at the end of this
; file, build/sandbox.lbl has their addresses), so they can be read in the emulator's monitor.

!macro timer_start {
        lda #$ff
        sta CIA2_TA_LO
        sta CIA2_TA_HI              ; start value $ffff (the timer is stopped, so this loads it straight away)
        lda #%00010001              ; bit 4: load the start value now, bit 0: run
        sta CIA2_CRA
}

!macro timer_stop .result {
        lda #%00000000              ; stop
        sta CIA2_CRA
        sec
        lda #$ff
        sbc CIA2_TA_LO
        tax
        lda #$ff
        sbc CIA2_TA_HI
        tay                         ; Y:X = cycles counted, including the start and the stop themselves
        txa
        sec
        sbc timer_overhead          ; minus the calibrated cost of the start and the stop
        sta .result
        tya
        sbc #0
        sta .result + 1
}

        * = $0801                   ; BASIC programs always start loading here

; BASIC stub: "10 SYS 2064", so typing RUN jumps into our machine code
        !word basic_end, 10
        !byte $9e                   ; BASIC token for SYS
        !text "2064"                ; the address of 'start' as decimal text
        !byte 0
basic_end
        !word 0

        * = 2064

; ============================================================================================================
; Start: screen colours, tables, timer calibration
; ============================================================================================================
!zone start
start
        sei                         ; KERNAL interrupt off: we read the keyboard ourselves, and the cursor
                                    ; blink would otherwise write into the screen we draw

        lda #COLOR_BLACK
        sta VIC_BORDER
        sta VIC_BG

        ; --- colour RAM: set once, a generation only rewrites the characters --------------------------
        lda #COLOR_GREEN
        ldx #0
-       sta COLOR_RAM,x
        sta COLOR_RAM + $100,x
        sta COLOR_RAM + $200,x
        sta COLOR_RAM + $300,x      ; this also fills the 24 unused bytes after the screen, which is harmless
        inx
        bne -

        jsr life_build_tables

        ; --- timer calibration -------------------------------------------------------------------------
        ; Starting and stopping the timer costs a few cycles of its own. Measure 'nothing' once and
        ; subtract that from every later measurement, so the numbers are the routine alone.
        lda #0
        sta timer_overhead
        +timer_start
        +timer_stop timer_overhead_word
        lda timer_overhead_word
        sta timer_overhead

; ============================================================================================================
; The main loop
; ============================================================================================================
!zone main_loop
restart
        jsr life_reset
        +timer_start
        jsr life_render
        +timer_stop cycles_render

main_loop
        jsr reset_pressed
        beq restart                 ; space or fire: back to the start pattern

        +timer_start
        jsr life_step               ; the next generation, CUR and NXT swap places
        +timer_stop cycles_step

        +timer_start
        jsr life_render
        +timer_stop cycles_render

        ldx #FRAMES_PER_GEN
        beq main_loop
-       jsr wait_frame
        dex
        bne -
        jmp main_loop

; ============================================================================================================
; reset_pressed: Z set (BEQ) while space or fire on joystick port 2 is held down
; ============================================================================================================
; The keyboard is a grid of 8 rows x 8 columns. Port A selects the rows (a 0 bit = that row is scanned),
; port B reads the columns of the selected rows (a 0 bit = key down). Space is row 7, column 4.
; The joystick in port 2 shares port A: fire pulls bit 4 of port A to 0, whatever we write there.
!zone reset_pressed
reset_pressed
        lda #%01111111              ; scan only row 7
        sta CIA1_PORTA
        lda CIA1_PORTB
        and #%00010000              ; column 4: space
        beq .done                   ; 0 = held down
        lda CIA1_PORTA
        and #%00010000              ; joystick port 2 fire
.done
        rts

; ============================================================================================================
; wait_frame: wait until the raster beam has passed line 250 (below the text area), once per frame
; ============================================================================================================
!zone wait_frame
wait_frame
-       lda VIC_RASTER
        cmp #250
        bne -                       ; wait for line 250
-       lda VIC_RASTER
        cmp #250
        beq -                       ; and until it is over, so two calls in a row never see the same line
        rts

!source "src/life.asm"

; ============================================================================================================
; Measurements (16 bits, low byte first)
; ============================================================================================================
cycles_step         !word 0         ; cycles of the last life_step
cycles_render       !word 0         ; cycles of the last life_render
timer_overhead_word !word 0         ; calibration result, only the low byte is used
timer_overhead      !byte 0         ; cycles that a start + stop adds to every measurement

!if * > GRID_A {
        !error "the program runs into the grids at $2000"
}
