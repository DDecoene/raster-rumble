; sandbox - my own C64 experiments: Conway's Game of Life
; Assembler: ACME   (build: make, run in the browser emulator: make test)
;
; A 40 x 24 world, one cell per character, drawn as balls on the screen. The world is a torus: what leaves
; on the right comes back on the left, what leaves at the bottom comes back at the top.
; The bottom row is the status bar:
;
;       (R)ANDOM  (F)IXED: GLIDER + BLINKER
;
;       R   start again with a random world
;       F   start again with the next fixed pattern (its name follows the colon)
;
; The part of the bar that is running is shown in reverse. Adding a fixed pattern: see the end of life.asm.
; How a generation is stored, computed and drawn is explained in life.asm.
;
; MEASURED with CIA 2 timer A (see 'Cycle measurement' below) in VICE x64sc, PAL. A frame has 19656 cycles.
;       life_step       24753 cycles = 1.26 frames   (23671 for the 6510 alone, the same for every pattern:
;                                                     the step has no branches that depend on the cells)
;       life_render     13051 cycles = 0.66 frame    (12055 for the 6510 alone)
; The difference is the VIC-II stealing the bus on badlines. Together about 2 frames per generation, so at
; FRAMES_PER_GEN = 0 the world runs at about 26 generations per second.

!source "src/hardware.asm"

; ============================================================================================================
; Names
; ============================================================================================================
NAME_PTR       = $16                ; (2 bytes) draw_status: the name of the pattern (life.asm uses $02-$15)
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
        lda #COLOR_LGREY
        ldx #39
-       sta COLOR_RAM + STATUS_ROW - SCREEN,x   ; the status bar in grey
        dex
        bpl -

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

        ; --- the first world: fixed pattern 0, the test pattern -----------------------------------------
        lda #0
        sta pattern
        jsr show_fixed

; ============================================================================================================
; The main loop: keys, generation step, render, wait
; ============================================================================================================
!zone main_loop
main_loop
        jsr new_keys
        bne .key

        +timer_start
        jsr life_step               ; the next generation, CUR and NXT swap places
        +timer_stop cycles_step

        +timer_start
        jsr life_render
        +timer_stop cycles_render

        lda #FRAMES_PER_GEN
        beq main_loop
        sta wait_count
-       jsr wait_frame
        jsr new_keys                ; also look at the keys while waiting, or a short tap could be missed
        bne .key
        dec wait_count
        bne -
        jmp main_loop

.key                                ; A = the keys that just went down
        and #KEY_R
        beq .fixed                  ; not R, so it was F (R wins if both come at once)
        jsr show_random
        jmp main_loop
.fixed
        ldx pattern
        inx                         ; the next fixed pattern ...
        cpx #PATTERN_COUNT
        bne +
        ldx #0                      ; ... and after the last one the first again
+       stx pattern
        jsr show_fixed
        jmp main_loop

; ============================================================================================================
; show_fixed / show_random: start a new world, update the status bar, draw it
; ============================================================================================================
!zone show
show_fixed
        lda pattern
        jsr life_plant
        lda #0
        sta rev_random              ; the bar shows the 'fixed' part in reverse
        lda #$80
        sta rev_fixed
        jmp .show

show_random
        jsr life_random
        lda #$80
        sta rev_random              ; the bar shows the 'random' part in reverse
        lda #0
        sta rev_fixed

.show
        jsr draw_status
        +timer_start
        jsr life_render
        +timer_stop cycles_render
        rts

; ============================================================================================================
; draw_status: the bottom row, "(R)ANDOM  (F)IXED: <name of the pattern>"
; ============================================================================================================
; Screen codes with bit 7 set are shown in reverse (light on dark swapped). rev_random and rev_fixed hold
; $80 or 0 and are ORed into the characters of each part.
STATUS_ROW  = SCREEN + 24 * 40      ; the 25th screen row
NAME_COLUMN = 19                    ; where the name of the pattern starts, right after "(F)IXED: "

!zone draw_status
draw_status
        ldx #39
        lda #CHAR_DEAD
-       sta STATUS_ROW,x            ; clear the row
        dex
        bpl -

        ldx #0
-       lda text_random,x
        ora rev_random
        sta STATUS_ROW,x
        inx
        cpx #text_fixed - text_random
        bne -

        ldx #0
-       lda text_fixed,x
        ora rev_fixed
        sta STATUS_ROW + 10,x
        inx
        cpx #text_end - text_fixed
        bne -

        ldx pattern
        lda pat_name_lo,x
        sta NAME_PTR
        lda pat_name_hi,x
        sta NAME_PTR+1
        ldy #0
-       lda (NAME_PTR),y                 ; the name ends with a 0
        beq .done
        ora rev_fixed
        sta STATUS_ROW + NAME_COLUMN,y
        iny
        bne -
.done
        rts

text_random !scr "(r)andom"         ; lower case in the source = the normal upper case letters on screen
text_fixed  !scr "(f)ixed: "
text_end

; ============================================================================================================
; new_keys: which of R and F went down since the last call (A = KEY_R / KEY_F bits, Z set when none)
; ============================================================================================================
; The keyboard is a grid of 8 rows x 8 columns. Port A selects the rows (a 0 bit = that row is scanned),
; port B reads the columns of the selected rows (a 0 bit = key down). R and F are both in row 2: R is
; column 1, F is column 5. Only a key that was up last time counts, so holding a key down does one reset.
KEY_R = %00000010
KEY_F = %00100000

!zone new_keys
new_keys
        lda #%11111011              ; scan only row 2
        sta CIA1_PORTA
        lda CIA1_PORTB
        eor #$ff                    ; now 1 = down
        and #KEY_R | KEY_F
        tax                         ; X = the keys down now
        eor keys_down               ; the keys that changed since last time
        stx keys_down
        and keys_down               ; changed and down now = just pressed
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
; Variables and measurements (16 bits, low byte first)
; ============================================================================================================
pattern             !byte 0         ; the fixed pattern shown last (0 .. PATTERN_COUNT - 1)
rev_random          !byte 0         ; $80 when the random part of the status bar is shown in reverse
rev_fixed           !byte 0         ; $80 when the fixed part is
keys_down           !byte 0         ; KEY_R / KEY_F bits of the keys that were down at the last look
wait_count          !byte 0         ; frames left to wait in the main loop

cycles_step         !word 0         ; cycles of the last life_step
cycles_render       !word 0         ; cycles of the last life_render
timer_overhead_word !word 0         ; calibration result, only the low byte is used
timer_overhead      !byte 0         ; cycles that a start + stop adds to every measurement

!if * > GRID_A {
        !error "the program runs into the grids at $2000"
}
