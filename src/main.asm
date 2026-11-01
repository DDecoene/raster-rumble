; sandbox - my own C64 experiments: an 8-bit SUBLEQ virtual machine
; Assembler: ACME   (build: make, run in the browser emulator: make test)
;
; SUBLEQ = "SUBtract and branch if Less than or EQual to zero", a computer with ONE instruction.
; Every instruction is 3 bytes: A, B, C. What it does:
;
;       M[B] = M[B] - M[A]
;       if the result <= 0 then jump to C, otherwise carry on with the next instruction
;
; The virtual machine has 256 bytes of memory (SUB_MEM), and A, B, C are all addresses in it.
; The virtual program counter V_PC is an index in that same memory.
; Jumping to C = $ff means HALT (a real SUBLEQ machine halts by jumping outside the memory).
;
; MEMORY-MAPPED I/O: a SUBLEQ machine has no input or output of its own, so two virtual addresses are wired to
; the C64. Whatever a SUBLEQ instruction writes to them is not stored but sent on:
;       $f0  the value is printed on the screen (KERNAL CHROUT)
;       $f1  the value is put in the border colour register

!source "src/hardware.asm"

; ============================================================================================================
; Names
; ============================================================================================================
V_PC    = $fb                       ; virtual program counter: index in SUB_MEM of the next instruction
ARG_A   = $fc                       ; the three bytes of the current instruction, kept in zero page
ARG_B   = $fd                       ; (zero page is smaller and faster to reach than normal RAM)
ARG_C   = $fe

SUB_MEM = $2000                     ; the virtual machine's 256 bytes of memory
HALT_ADDR = $ff                     ; jumping to this address stops the machine
IO_CHAR   = $f0                     ; virtual address: a write here prints a character
IO_BORDER = $f1                     ; virtual address: a write here sets the border colour
CHROUT    = $ffd2                   ; KERNAL routine: print the character in the A register

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
; The interpreter
; ============================================================================================================
start
        lda #0
        sta V_PC                    ; the virtual machine starts at address 0 of its own memory
        sta SUB_MEM+IO_CHAR         ; the two I/O cells are never really written (see 'io_write'), so they
        sta SUB_MEM+IO_BORDER       ; must start at 0: a program then gets exactly (0 - M[A]) as its value

fetch
        ; --- read the three bytes of the instruction -------------------------------------------------------
        ; We step Y one at a time (iny) instead of using SUB_MEM+1,y, because when V_PC is 254 or 255 an
        ; indexed address would run past $20ff into the next page, while Y simply wraps round to 0 like a
        ; real 8-bit program counter does.
        ldy V_PC
        lda SUB_MEM,y
        sta ARG_A
        iny
        lda SUB_MEM,y
        sta ARG_B
        iny
        lda SUB_MEM,y
        sta ARG_C
        iny
        sty V_PC                    ; by default the next instruction follows right after this one

        ; --- M[B] = M[B] - M[A] ----------------------------------------------------------------------------
        ldx ARG_A
        ldy ARG_B
        lda SUB_MEM,y               ; A register = M[B]
        sec                         ; the 6502 has no plain subtract: SBC always subtracts the carry as well,
                                    ; so set carry first or the result is one too low
        sbc SUB_MEM,x               ; A register = M[B] - M[A]

        ; --- store the result, or send it to the C64 if B is one of the I/O addresses ------------------------
        ; The branch test below needs the flags of the SBC, but CPY changes them. PHP puts the flags on the
        ; stack and PLP gets them back, so every path through here keeps them (and the result in A).
        php
        cpy #IO_CHAR                ; Y still holds B: is the destination the 'print' address?
        beq io_char
        cpy #IO_BORDER              ; or the 'border colour' address?
        beq io_border
        sta SUB_MEM,y               ; an ordinary address: store the result (STA does not touch the flags)
        jmp io_done

io_char                             ; trap: do NOT store, print the result instead
        jsr CHROUT                  ; KERNAL prints the character code in A (13 = new line)
        jmp io_done

io_border                           ; trap: do NOT store, show the result as the border colour instead
        sta VIC_BORDER              ; the VIC-II only looks at the lowest 4 bits: colour = value mod 16

io_done
        plp                         ; the flags of the subtraction are back

        ; --- is the result <= 0 (as a signed 8-bit number)? ------------------------------------------------
        ; Z set means exactly zero. Otherwise N says negative, unless the subtraction overflowed (V set,
        ; for example 100 - (-100)): then the sign bit is the wrong way round and N must be read inverted.
        beq jump                    ; zero: yes
        bvs overflowed
        bmi jump                    ; no overflow and negative: yes
        jmp fetch                   ; no overflow and positive: carry on with the next instruction
overflowed
        bpl jump                    ; overflow and N clear: the real result is negative: yes
        jmp fetch                   ; overflow and N set: the real result is positive: carry on

jump
        lda ARG_C
        cmp #HALT_ADDR
        beq halt                    ; jump target $ff: the program is finished
        sta V_PC                    ; otherwise continue at address C
        jmp fetch

halt
        rts                         ; back to BASIC

; ============================================================================================================
; SUBLEQ assembler macros (they only write bytes into the virtual memory, they are not 6502 code)
; ============================================================================================================
; Every operand is a real C64 address (a label) and the macro turns it into an index (address - SUB_MEM).

; the one real instruction: M[b] = M[b] - M[a], and if that is <= 0 continue at c
!macro subleq .a, .b, .c {
        !byte .a - SUB_MEM, .b - SUB_MEM, .c - SUB_MEM
}

; b = 0
!macro vm_clear .b {
        +subleq .b, .b, *+3         ; b - b = 0 is always <= 0, and c is simply the next instruction
}

; b = b + a   (a is kept). Z is a cell that always holds 0 between two of these:
;       Z = 0 - a        so Z now holds -a
;       b = b - Z        and b - (-a) is b + a
;       Z = Z - Z        puts the 0 back
; The branch target is always the next instruction (*+3), so it does not matter what the flags say.
; A write to an I/O address works too, as long as that cell holds 0: M[$f0] = 0 + a is printed.
!macro vm_add .a, .b {
        +subleq .a, m_zero, *+3
        +subleq m_zero, .b, *+3
        +subleq m_zero, m_zero, *+3
}

; jump to c: Z - Z is always 0, which is <= 0
!macro vm_goto .c {
        +subleq m_zero, m_zero, .c
}

; ============================================================================================================
; The SUBLEQ program: Fibonacci, printing a '*' and flashing the border for every number
; ============================================================================================================
; Two registers hold the last two numbers of the sequence:
;
;       m_prev1 = 1      m_prev2 = 1      the sequence starts 1, 1, 2, 3, 5, 8 ...
;
; Every round shows m_prev1 and then shifts the pair one step along (a, b) -> (b, a + b):
;
;       round   shown (prev1)   prev1 prev2 at the start of the round
;         1          1             1     1
;         2          1             1     2       next = 1 + 1 = 2, prev1 = prev2, prev2 = next
;         3          2             2     3
;         4          3             3     5
;         ...
;        12        144           144   233
;        13        233           233   377 -> wraps to 121 (does not fit in 8 bits, never shown)
;
; 233 is the last Fibonacci number below 256, so the program stops after 13 rounds. It counts the rounds
; instead of testing for overflow: SUBLEQ compares as signed numbers, so from 128 up a plain "is it
; bigger than 255" test is not possible with 8 bits, but "13 rounds" is exact for this sequence.

        * = SUB_MEM

fib_round
        ; --- show the number ---------------------------------------------------------------------------
        +vm_add k_star, SUB_MEM+IO_CHAR     ; print '*'
        +vm_add m_prev1, SUB_MEM+IO_BORDER  ; border colour = the number (the VIC uses its lowest 4 bits)

        ; --- wait a moment, or the colours would flash past within a blink --------------------------------
        ; A loop in SUBLEQ: subtract 1 from a counter, and when it reaches 0 (<= 0) leave the loop.
        ; Two loops inside each other: 15 x 50 rounds.
        +vm_clear m_outer
        +vm_add   k_outer, m_outer
delay_outer
        +vm_clear m_inner
        +vm_add   k_inner, m_inner
delay_inner
        +subleq   m_one, m_inner, delay_inner_end   ; inner counter - 1, at 0 leave
        +vm_goto  delay_inner                       ; otherwise go round again
delay_inner_end
        +subleq   m_one, m_outer, delay_end         ; outer counter - 1, at 0 leave
        +vm_goto  delay_outer
delay_end

        ; --- shift the registers: (prev1, prev2) = (prev2, prev1 + prev2) ---------------------------------
        +vm_clear m_next
        +vm_add   m_prev1, m_next           ; next = prev1
        +vm_add   m_prev2, m_next           ; next = prev1 + prev2
        +vm_clear m_prev1
        +vm_add   m_prev2, m_prev1          ; prev1 = old prev2
        +vm_clear m_prev2
        +vm_add   m_next, m_prev2           ; prev2 = the sum

        ; --- count the rounds -----------------------------------------------------------------------------
        +subleq   m_one, m_rounds, fib_done ; rounds left - 1, at 0 we are finished
        +vm_goto  fib_round

fib_done
        +vm_add k_newline, SUB_MEM+IO_CHAR  ; finish the line of stars
        +vm_add k_green, SUB_MEM+IO_BORDER  ; green border: the program reached its end
        +subleq m_zero, m_zero, SUB_MEM+HALT_ADDR   ; jump to $ff: HALT

; --- data cells (the program must stay below the I/O addresses at $f0) -------------------------------------
m_zero    !byte 0                   ; Z: always 0 between two additions
m_one     !byte 1                   ; the constant 1, for counting down
m_prev1   !byte 1                   ; the register that is shown, starts as the first 1
m_prev2   !byte 1                   ; the register after it, starts as the second 1
m_next    !byte 0                   ; scratch for the sum
m_rounds  !byte 13                  ; rounds left
m_outer   !byte 0                   ; delay counters
m_inner   !byte 0
k_outer   !byte 15                  ; delay: outer rounds
k_inner   !byte 50                  ; delay: inner rounds per outer round
k_star    !byte $2a                 ; '*'
k_newline !byte $0d                 ; carriage return, CHROUT starts a new line
k_green   !byte COLOR_GREEN

!if * > SUB_MEM + IO_CHAR {
        !error "the SUBLEQ program runs into the I/O addresses"
}
