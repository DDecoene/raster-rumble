; sandbox - SID experiments: rewrite the ADSR (and more) on every timer tick
; Assembler: ACME   (build: make, run in the browser emulator: make test)
;
; One note (voice 1, about 440 Hz) and a timer interrupt that touches the SID on every tick.
; What a tick does depends on the mode:
;
;       0   steady note              the reference: gate on, nothing changes
;       1   gate stutter             every tick the gate flips: on, off, on, off. Pumping amplitude.
;       2   sustain table            every second tick the gate goes on again with a new sustain level
;                                    from a table: the volume follows the table in steps
;       3   envelope as LFO          voice 3 plays an envelope nobody hears (muted); every tick we read it
;                                    from $d41c and add it to the pitch of voice 1: a hardware LFO
;
; Modes 4 to 8 are techniques from the classic players (Rob Hubbard's Monty on the Run, Cybernoid II), written
; from scratch. They are made for 50 ticks per second (speed 0):
;
;       4   vibrato                  the pitch swings 0-1-2-3-3-2-1-0 steps of a quarter of the distance to the
;                                    next semitone, so the vibrato is just as wide on every note
;       5   drum, a formula          a drum every 16 ticks: one frame of noise, then a triangle wave whose pitch
;                                    falls one step per frame (Hubbard's "drum" effect)
;       6   drum, a table            the same, but every frame has its own waveform and pitch in a table (Cybernoid
;                                    II style): a kick and a snare in turn
;       7   octave arpeggio          every tick the note jumps between itself and the octave above it
;
;       8   bass kick                a kick with real weight, three layers: a pulse body on voice 1 whose pitch falls
;                                    exponentially (every frame to 3/4 of the pitch before: fast first, then slower,
;                                    like a real drum) down to about 75 Hz, a triangle one octave lower on voice 3 as
;                                    the sub, and a one-frame noise click on voice 2
;
;       0-8     choose the mode
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
JUMP_PTR   = $fd                    ; (2 bytes) irq: the address of the routine of the current mode
MODES      = 9                      ; number of modes

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
        cmp #'0'+MODES
        bcs +                       ; past the last mode: not a mode key
        sec
        sbc #'0'                    ; '0'.. -> 0..
        jsr set_mode
        jmp main_loop
+       cmp #$4d                    ; 'M': sound on / off
        bne +
        lda muted
        eor #1
        sta muted
        jsr apply_volume
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
        sta SCREEN+40*15+6          ; show it on row 15, after "mode: "
        lda #$ff                    ; the tick counter starts at $ff: the first IRQ makes it 0, so a drum starts at once
        sta ticks
        lda #0
        sta phase
        sta drum_pos                ; no drum running
        sta drum_end
        sta SID_CTRL1               ; gate off, start from nothing
        sta SID_CTRL3
        lda note_freq               ; every mode starts on the same note ...
        sta SID_FREQ1L
        lda note_freq+1
        sta SID_FREQ1H
        lda #$00                    ; ... with a square pulse width (only the pulse waves of mode 6 use it)
        sta SID_PW1L
        lda #$08
        sta SID_PW1H

        jsr apply_volume
        ldx mode                    ; (apply_volume used X)
        lda ad_table,x              ; the envelope of this mode, from the tables at the end
        sta SID_AD1
        lda sr_table,x
        sta SID_SR1

        ; the vibrato step, worked out from the distance to the next semitone (like Hubbard does on every frame)
        sec
        lda note_next               ; next semitone minus this note: how far apart they are ...
        sbc note_freq
        sta vdif_lo
        lda note_next+1
        sbc note_freq+1
        lsr                         ; ... divided by 4: the 16-bit shift right goes through the carry
        ror vdif_lo
        lsr
        ror vdif_lo
        sta vdif_hi

        lda mode
        cmp #8
        bne +
        lda ad_table+8              ; mode 8: the sub on voice 3 gets the envelope of the body ...
        sta SID_AD3
        lda sr_table+8
        sta SID_SR3
        lda #$00                    ; ... and the click on voice 2 is as short as the SID can do it
        sta SID_AD2
        sta SID_SR2
+       lda mode
        cmp #3
        bne +
        lda #$69                    ; mode 3, voice 3: attack 6 (68 ms), decay 9 (750 ms) ...
        sta SID_AD3
        lda #$00                    ; ... down to sustain 0
        sta SID_SR3
        lda #$21                    ; voice 3 on (sawtooth + gate)
        sta SID_CTRL3
+       ldx mode
        lda gate_table,x            ; does this mode start with the gate on?
        beq +                       ; no: its IRQ starts the notes
        lda #$21                    ; voice 1 on: sawtooth + gate
        sta SID_CTRL1
+       cli
        rts

; ------------------------------------------------------------------------------------------------------------
; apply_volume: master volume 15 (bit 7 = voice 3 muted: mode 3 only wants its envelope), or 0 when the sound is
; switched off with M. Also shows ON or OFF on the screen.
; ------------------------------------------------------------------------------------------------------------
apply_volume
        ldx mode
        lda vol_table,x
        ldy muted
        beq +
        lda #0                      ; muted: volume 0
+       sta SID_VOLUME
        lda muted                   ; the text: 3 screen codes per state, "ON " or "OFF"
        asl
        clc
        adc muted                   ; muted * 3
        tax
        ldy #0
-       lda sound_text,x
        sta SCREEN+40*17+7,y
        inx
        iny
        cpy #3
        bne -
        rts

sound_text
        !byte 15, 14, 32            ; "ON "  (screen codes: O = 15, N = 14, F = 6)
        !byte 15, 6, 6              ; "OFF"

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
        sta SCREEN+40*16+7
        rts

; Cycles per tick: 19656 = 50 Hz, then half of that each step
period_lo
        !byte <19656, <9828, <4914, <2457, <1228, <614
period_hi
        !byte >19656, >9828, >4914, >2457, >1228, >614

; ------------------------------------------------------------------------------------------------------------
; irq: runs on every tick. Jumps to the routine of the current mode (through a table), which ends with a jump to
; irq_done: the normal KERNAL IRQ.
; ------------------------------------------------------------------------------------------------------------
irq
        inc ticks
        ldx mode
        lda mode_lo,x               ; the address of this mode's routine ...
        sta JUMP_PTR
        lda mode_hi,x
        sta JUMP_PTR+1
        jmp (JUMP_PTR)              ; ... and go there. (JMP with brackets: jump to the address stored at JUMP_PTR)

mode_lo
        !byte <irq_done, <mode1, <mode2, <mode3, <mode4, <mode5, <mode6, <mode7, <mode8
mode_hi
        !byte >irq_done, >mode1, >mode2, >mode3, >mode4, >mode5, >mode6, >mode7, >mode8

; --- mode 1: gate stutter ---------------------------------------------------------------------------------
mode1
        lda phase                   ; flip the gate every tick
        eor #1
        sta phase
        beq +
        lda #$21                    ; gate on
        !byte $2c                   ; BIT absolute: skips the next two bytes (the lda #$20)
+       lda #$20                    ; gate off
        sta SID_CTRL1
        jmp irq_done

; --- mode 2: sustain table --------------------------------------------------------------------------------
mode2
        lda phase                   ; even tick gate off, odd tick gate on with the next sustain
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

; --- mode 3: the envelope of voice 3 drives the pitch of voice 1 ------------------------------------------
mode3
        lda SID_ENV3                ; voice 3's envelope (0-255) becomes the pitch of voice 1
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
        bne +
        lda #$21
        sta SID_CTRL3
+       jmp irq_done

; --- mode 4: vibrato --------------------------------------------------------------------------------------
; The swing goes 0 1 2 3 3 2 1 0 (8 ticks): counter and 7, and from 4 on turned around with EOR 7 (7 -> 3, 6 -> 2).
; The pitch is the note plus that many steps of 'vdif' (a quarter of the way to the next semitone).
mode4
        lda ticks
        and #7
        cmp #4
        bcc +
        eor #7                      ; 4,5,6,7 -> 3,2,1,0
+       tax                         ; X = how many steps up
        lda note_freq
        sta vfrq_lo
        lda note_freq+1
        sta vfrq_hi
-       dex                         ; X steps: add vdif to the pitch X times (0 steps: leave at once)
        bmi +
        clc
        lda vfrq_lo
        adc vdif_lo
        sta vfrq_lo
        lda vfrq_hi
        adc vdif_hi
        sta vfrq_hi
        jmp -
+       lda vfrq_lo
        sta SID_FREQ1L
        lda vfrq_hi
        sta SID_FREQ1H
        jmp irq_done

; --- mode 5: a drum from a formula (Hubbard) --------------------------------------------------------------
; Every 16 ticks: tick 15 gate off, tick 0 noise starts the drum, the next ticks switch to a triangle wave while the
; high byte of the pitch drops by 1 per tick ($14 -> about 300 Hz, down to $07 -> about 100 Hz): a kick.
mode5
        lda ticks
        and #$0f
        cmp #15
        bne +
        lda #$80                    ; noise, gate off: the envelope releases, the next gate-on starts clean
        sta SID_CTRL1
        jmp irq_done
+       cmp #0
        bne +
        lda #$14                    ; start pitch
        sta drum_hi
        sta SID_FREQ1H
        lda #$81                    ; noise + gate on: the click of the drum
        sta SID_CTRL1
        jmp irq_done
+       dec drum_hi                 ; the pitch falls one step
        lda drum_hi
        sta SID_FREQ1H
        lda #$11                    ; triangle + gate on
        sta SID_CTRL1
        jmp irq_done

; --- mode 6: drums from tables (Cybernoid II) -------------------------------------------------------------
; Eight frames per drum, the waveform and the pitch of every frame come from a table. Kick and snare in turn.
mode6
        lda ticks
        and #$0f
        cmp #15
        bne +
        lda #$80                    ; gate off before the next drum
        sta SID_CTRL1
        jmp irq_done
+       cmp #0
        bne step                    ; not the start of a drum: just carry on with the one that is running
        lda ticks                   ; which drum? bit 4 of the tick counter: 0 = kick, 1 = snare
        lsr
        lsr
        lsr
        lsr
        and #1
        asl
        asl
        asl                         ; 0 or 8: where its rows start in the tables
        sta drum_pos
        clc
        adc #8
        sta drum_end                ; 8 rows per drum
step    lda drum_pos
        cmp drum_end
        beq +                       ; no row left: the drum is finished
        tax
        lda drum_wave,x             ; this frame's waveform (with the gate bit) ...
        sta SID_CTRL1
        lda drum_freq,x             ; ... and pitch
        sta SID_FREQ1H
        inc drum_pos
+       jmp irq_done

; --- mode 7: octave arpeggio ------------------------------------------------------------------------------
; Even ticks the note, odd ticks the note doubled (shift left = times 2 = one octave up).
mode7
        lda ticks
        and #1
        bne +
        lda note_freq
        sta SID_FREQ1L
        lda note_freq+1
        sta SID_FREQ1H
        jmp irq_done
+       lda note_freq
        asl                         ; low byte times 2, the top bit goes into the carry ...
        sta SID_FREQ1L
        lda note_freq+1
        rol                         ; ... and in at the bottom of the high byte
        sta SID_FREQ1H
        jmp irq_done

; --- mode 8: bass kick ------------------------------------------------------------------------------------
; Every 16 ticks. Tick 0: all three layers start. Every tick after that the pitch of the body drops to 3/4:
; pitch = pitch - pitch/4 (two shifts right of a 16-bit number). It stops dropping below $0500 (about 75 Hz).
; Tick 1: the click stops. Tick 15: gate off, ready for the next kick.
mode8
        lda ticks
        and #$0f
        cmp #15
        bne +
        lda #$40                    ; pulse, gate off
        sta SID_CTRL1
        lda #$10                    ; triangle, gate off
        sta SID_CTRL3
        lda #$80                    ; noise, gate off
        sta SID_CTRL2
        jmp irq_done
+       cmp #0
        bne +
        lda #$00                    ; the start pitch: $1a00 = about 390 Hz
        sta kick_lo
        lda #$1a
        sta kick_hi
        lda #$30                    ; the click: noise at a fixed pitch, gate on for one tick
        sta SID_FREQ2H
        lda #$81
        sta SID_CTRL2
        lda #$41                    ; body: PULSE wave, gate on. Unlike a triangle it has overtones, so small speakers
        sta SID_CTRL1               ; (that cannot play 50 Hz) still make you hear the bass
        lda #$11                    ; sub: triangle, gate on
        sta SID_CTRL3
        jmp m8_write
+       cmp #1
        bne +
        lda #$80                    ; the click is over
        sta SID_CTRL2
+       lda kick_hi
        cmp #5                      ; already at the bottom?
        bcc m8_write
        lsr                         ; pitch / 4 into t_hi:t_lo
        sta t_hi
        lda kick_lo
        ror
        sta t_lo
        lsr t_hi
        ror t_lo
        sec                         ; pitch = pitch - pitch/4
        lda kick_lo
        sbc t_lo
        sta kick_lo
        lda kick_hi
        sbc t_hi
        sta kick_hi
m8_write
        lda kick_lo                 ; the body
        sta SID_FREQ1L
        lda kick_hi
        sta SID_FREQ1H
        lsr                         ; the sub: half the pitch, one octave lower
        sta SID_FREQ3H
        lda kick_lo
        ror
        sta SID_FREQ3L
        ; fall through

irq_done
        jmp KERNAL_IRQ

; ------------------------------------------------------------------------------------------------------------
; Data
; ------------------------------------------------------------------------------------------------------------
note_freq  !word $1d45              ; A-4, 440 Hz on a PAL machine
note_next  !word $1f02              ; A#4: one semitone higher

; per mode: attack/decay, sustain/release, and does the mode start with the gate on?
;                0     1     2     3     4     5     6     7
ad_table   !byte $00, $00, $00, $00, $00, $05, $05, $00, $08       ; mode 8: attack 0, decay 8 (about 300 ms)
sr_table   !byte $f0, $f0, $00, $f0, $f0, $00, $00, $f0, $00
gate_table !byte 1,   1,   0,   1,   1,   0,   0,   1,   0
vol_table  !byte $0f, $0f, $0f, $8f, $0f, $0f, $0f, $0f, $0f      ; only mode 3 mutes voice 3

; Sustain level (high nibble) in 16 steps: a smooth wave from soft to loud and back
sustain_table
        !byte $20, $40, $60, $80, $a0, $c0, $e0, $f0
        !byte $f0, $e0, $c0, $a0, $80, $60, $40, $20

; Drum tables, 8 frames each: the first 8 are a kick, the next 8 a snare
;                 frame: 0    1    2    3    4    5    6    7
drum_wave  !byte $81, $81, $11, $11, $11, $11, $11, $11    ; kick:  noise, then triangle
           !byte $81, $81, $41, $81, $81, $81, $81, $81    ; snare: noise, a pulse in the middle, noise
drum_freq  !byte $18, $10, $0e, $0c, $0a, $09, $08, $07    ; kick:  the pitch falls
           !byte $50, $48, $20, $40, $3c, $38, $34, $30    ; snare: noisy, with a dip

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
        !pet "4  vibrato", 13
        !pet "5  drum from a formula", 13
        !pet "6  drums from a table", 13
        !pet "7  octave arpeggio", 13
        !pet "8  bass kick", 13
        !pet "+ -  faster / slower ticks", 13
        !pet "m    sound on / off", 13
        !pet "(modes 4-8 are made for speed 0)", 13, 13
        !pet "mode: 0", 13
        !pet "speed: 0", 13
        !pet "sound: on", 13, 0

; variables
mode     !byte 0                    ; 0-8
speed    !byte 0                    ; 0-5
muted    !byte 0                    ; 1 = sound off (the M key)
ticks    !byte 0                    ; counts IRQs
phase    !byte 0                    ; 0/1 flip-flop for the gate
vdif_lo  !byte 0                    ; vibrato: the size of one step (16 bits)
vdif_hi  !byte 0
vfrq_lo  !byte 0                    ; vibrato: the pitch we are working out (16 bits)
vfrq_hi  !byte 0
drum_hi  !byte 0                    ; mode 5: the pitch of the drum (high byte)
drum_pos !byte 0                    ; mode 6: the row of the drum table that comes next
drum_end !byte 0                    ; mode 6: one past the last row of this drum
kick_lo  !byte 0                    ; mode 8: the pitch of the kick body (16 bits)
kick_hi  !byte 0
t_lo     !byte 0                    ; mode 8: working space for pitch / 4
t_hi     !byte 0
