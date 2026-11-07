; sandbox - SID experiments: rewrite the ADSR (and more) on every timer tick
; Assembler: ACME   (build: make, run in the browser emulator: make test)
;
; One note (voice 1, sawtooth, about 440 Hz) and a timer interrupt that touches the SID on every tick.
; What a tick does depends on the mode:
;
;       0   steady note              the reference: gate on, nothing changes
;       1   gate stutter             every tick the gate flips: on, off, on, off. Pumping amplitude.
;       2   sustain table            every second tick the gate goes on again with a new sustain level
;                                    from a table: the volume follows the table in steps
;       3   envelope as LFO          voice 3 plays an envelope nobody hears (muted); every tick we read it
;                                    from $d41c and add it to the pitch of voice 1: a hardware LFO
;
;       0-3     choose the mode
;       + / -   faster / slower ticks (6 speeds, from 50 Hz up to about 1600 Hz)
;
; The KERNAL IRQ is driven by CIA 1 timer A. We change its start value, so the IRQ comes faster, and
; hook the vector at $0314 so our routine runs first. The KERNAL then still scans the keyboard (so GETIN works).

!source "src/hardware.asm"

IRQ_VECTOR = $0314                  ; the KERNAL jumps through this vector on every IRQ
KERNAL_IRQ = $ea31                  ; the normal IRQ routine: keyboard scan and so on
CHROUT     = $ffd2                  ; KERNAL: print the character in A
GETIN      = $ffe4                  ; KERNAL: A = the key pressed, 0 = none
SCREEN     = $0400                  ; screen memory, 40 x 25 characters

TEXT_PTR   = $fb                    ; (2 bytes) print_text: where we are in the text

        * = $0801                   ; BASIC programs always start loading here

; BASIC stub: "10 SYS 2064", so typing RUN jumps into our machine code
        !word basic_end, 10
        !byte $9e                   ; BASIC token for SYS
        !text "2064"                ; the address of 'start' as decimal text
        !byte 0
basic_end
        !word 0

        * = 2064

start
        lda #<title                 ; print the screen text
        sta TEXT_PTR
        lda #>title
        sta TEXT_PTR+1
        jsr print_text

        lda #$8f                    ; master volume 15, bit 7 = voice 3 muted (we only want its envelope)
        sta SID_VOLUME
        lda #$1d                    ; voice 1 frequency $1d45 = about 440 Hz on a PAL machine
        sta SID_FREQ1H
        lda #$45
        sta SID_FREQ1L

        lda #0                      ; first mode 0, speed 0
        sta mode
        sta speed
        jsr set_speed
        lda #0
        jsr set_mode

        sei                         ; hook our routine into the IRQ vector
        lda #<irq
        sta IRQ_VECTOR
        lda #>irq
        sta IRQ_VECTOR+1
        cli

main_loop
        jsr GETIN                   ; wait for a key
        beq main_loop
        cmp #'0'
        bcc +                       ; below '0': not a mode key
        cmp #'4'
        bcs +                       ; '4' or more: not a mode key
        sec
        sbc #'0'                    ; '0'..'3' -> 0..3
        jsr set_mode
        jmp main_loop
+       cmp #'+'
        bne +
        lda speed
        cmp #5
        beq main_loop               ; already the fastest
        inc speed
        jsr set_speed
        jmp main_loop
+       cmp #'-'
        bne main_loop
        lda speed
        beq main_loop               ; already the slowest
        dec speed
        jsr set_speed
        jmp main_loop

; ------------------------------------------------------------------------------------------------------------
; set_mode: A = the new mode. Silences everything, loads the envelope settings that mode needs, shows the digit.
; ------------------------------------------------------------------------------------------------------------
set_mode
        sei                         ; the IRQ must not see a half-finished change
        sta mode
        clc
        adc #'0'                    ; the digit as a screen code ('0' is $30 there too)
        sta SCREEN+40*8+6           ; show it on row 8, after "mode: "
        lda #0
        sta ticks
        sta phase
        sta SID_CTRL1               ; gate off, start from nothing
        sta SID_CTRL3
        lda #$00                    ; attack 0 (2 ms) and decay 0 (6 ms): as fast as the SID can do
        sta SID_AD1
        lda #$f0                    ; sustain 15 (full), release 0 (6 ms)
        sta SID_SR1
        lda mode
        cmp #2
        bne +
        lda #$00                    ; mode 2: sustain comes from the table, start at 0
        sta SID_SR1
+       lda mode
        cmp #3
        bne +
        lda #$69                    ; voice 3: attack 6 (68 ms), decay 9 (750 ms) ...
        sta SID_AD3
        lda #$00                    ; ... down to sustain 0
        sta SID_SR3
        lda #$21                    ; voice 3 on (sawtooth + gate)
        sta SID_CTRL3
+       lda mode
        cmp #2
        beq +                       ; mode 2 starts its gate from the IRQ
        lda #$21                    ; voice 1 on: sawtooth + gate
        sta SID_CTRL1
+       cli
        rts

; ------------------------------------------------------------------------------------------------------------
; set_speed: load the tick period for 'speed' into the CIA timer and show the speed digit.
; ------------------------------------------------------------------------------------------------------------
set_speed
        ldx speed
        lda period_lo,x
        sta CIA1_TA_LO
        lda period_hi,x
        sta CIA1_TA_HI              ; takes effect at the next underflow
        txa
        clc
        adc #'0'                    ; speed digit (screen code of '0' is $30)
        sta SCREEN+40*9+7
        rts

; Cycles per tick: 19656 = 50 Hz, then half of that each step
period_lo
        !byte <19656, <9828, <4914, <2457, <1228, <614
period_hi
        !byte >19656, >9828, >4914, >2457, >1228, >614

; ------------------------------------------------------------------------------------------------------------
; irq: runs on every tick. Does the mode's SID trick, then goes on with the normal KERNAL IRQ.
; ------------------------------------------------------------------------------------------------------------
irq
        inc ticks
        lda mode
        beq irq_done                ; mode 0: nothing

        cmp #1
        bne mode2
        lda phase                   ; mode 1: flip the gate every tick
        eor #1
        sta phase
        beq +
        lda #$21                    ; gate on
        !byte $2c                   ; BIT absolute: skips the next two bytes (the lda #$20)
+       lda #$20                    ; gate off
        sta SID_CTRL1
        jmp irq_done

mode2   cmp #2
        bne mode3
        lda phase                   ; mode 2: even tick gate off, odd tick gate on with the next sustain
        eor #1
        sta phase
        bne on
        lda #$20                    ; gate off (release 0 drops the sound in 6 ms)
        sta SID_CTRL1
        jmp irq_done
on      lda ticks
        lsr                         ; one step of the table per gate-on
        and #$0f
        tax
        lda sustain_table,x
        sta SID_SR1                 ; high nibble = sustain level, release 0
        lda #$21
        sta SID_CTRL1               ; gate 0 -> 1: attack to the top, then decay down to the new sustain
        jmp irq_done

mode3   lda SID_ENV3                ; mode 3: voice 3's envelope (0-255) becomes the pitch of voice 1
        lsr
        lsr
        lsr                         ; 0..31
        clc
        adc #$0c                    ; the pitch goes from $0c45 up to $2b45
        sta SID_FREQ1H
        lda ticks                   ; every 64 ticks restart voice 3's envelope: gate off at 0, on at 2
        and #$3f
        bne +
        lda #$20
        sta SID_CTRL3
+       cmp #2
        bne irq_done
        lda #$21
        sta SID_CTRL3

irq_done
        jmp KERNAL_IRQ

; Sustain level (high nibble) in 16 steps: a smooth wave from soft to loud and back
sustain_table
        !byte $20, $40, $60, $80, $a0, $c0, $e0, $f0
        !byte $f0, $e0, $c0, $a0, $80, $60, $40, $20

; ------------------------------------------------------------------------------------------------------------
; print_text: print the zero-terminated text at TEXT_PTR with the KERNAL.
; ------------------------------------------------------------------------------------------------------------
print_text
        ldy #0
-       lda (TEXT_PTR),y
        beq +
        jsr CHROUT
        iny
        bne -                       ; the text is shorter than 256 bytes
+       rts

title
        !byte 147                   ; clear the screen
        !pet "sid adsr lab", 13, 13
        !pet "0  steady note", 13
        !pet "1  gate stutter", 13
        !pet "2  sustain table", 13
        !pet "3  envelope drives the pitch", 13
        !pet "+ -  faster / slower ticks", 13, 13
        !pet "mode: 0", 13
        !pet "speed: 0", 13, 0

; variables
mode    !byte 0                     ; 0-3
speed   !byte 0                     ; 0-5
ticks   !byte 0                     ; counts IRQs
phase   !byte 0                     ; 0/1 flip-flop for the gate
