; score.asm - the 3-digit score and the high score (kept in RAM at $c000)

!zone add_score                     ; a new zone, so this '.done' is a different label than the one above
add_score                           ; subroutine: score + 1, three decimal digits, stops at 999
        inc score + 2               ; ones + 1
        lda score + 2               ; load it to compare
        cmp #10                     ; still 0-9?
        bcc .done                   ; yes, finished
        lda #0                      ; ones overflowed: back to 0 ...
        sta score + 2               ; ... store it
        inc score + 1               ; ... and tens + 1
        lda score + 1               ; load it to compare
        cmp #10                     ; still 0-9?
        bcc .done                   ; yes, finished
        lda #0                      ; tens overflowed: back to 0 ...
        sta score + 1               ; ... store it
        inc score                   ; ... and hundreds + 1
        lda score                   ; load it to compare
        cmp #10                     ; still 0-9?
        bcc .done                   ; yes, finished
        lda #9                      ; we reached 1000: stay at 999
        sta score                   ; hundreds = 9
        sta score + 1               ; tens = 9
        sta score + 2               ; ones = 9
.done
        jmp draw_score              ; show the new score (draw_score returns to our caller)

reset_score                         ; subroutine: score = 000
        lda #0                      ; A = 0
        sta score                   ; hundreds = 0
        sta score + 1               ; tens = 0
        sta score + 2               ; ones = 0
        jmp draw_score              ; show it (draw_score returns to our caller)

draw_score                          ; subroutine: print the three digits on the screen
        lda score                   ; hundreds digit, a number 0-9
        ora #$30                    ; screen code for '0' is $30, so $30 + digit is the character
        sta SCORE_POS               ; print it
        lda score + 1               ; tens digit
        ora #$30                    ; turn the number into a character
        sta SCORE_POS + 1           ; print it
        lda score + 2               ; ones digit
        ora #$30                    ; turn the number into a character
        sta SCORE_POS + 2           ; print it
        rts                         ; return to the caller

!zone init_hiscore
init_hiscore                        ; subroutine: validate the high score in RAM, then draw it
        lda hi_magic                ; is our signature there?
        cmp #HI_MAGIC               ; compare with the expected value
        beq .draw                   ; yes, the old high score is valid, keep it
        lda #0                      ; no (fresh power-on): A = 0
        sta hi_score                ; hundreds = 0
        sta hi_score + 1            ; tens = 0
        sta hi_score + 2            ; ones = 0
        lda #HI_MAGIC               ; now sign it ...
        sta hi_magic                ; ... so the next start keeps it
.draw
        jmp draw_hiscore            ; show it (draw_hiscore returns to our caller)

!zone update_hiscore
update_hiscore                      ; subroutine: if score > hi_score, copy score into hi_score
        lda score                   ; compare hundreds first, the most significant digit
        cmp hi_score                ; carry clear if score < hi_score
        bcc .done                   ; lower, so no new record
        bne .copy                   ; higher, so a new record
        lda score + 1               ; hundreds equal: compare tens
        cmp hi_score + 1            ; same test
        bcc .done                   ; lower
        bne .copy                   ; higher
        lda score + 2               ; tens equal too: compare ones
        cmp hi_score + 2            ; same test
        bcc .done                   ; lower
        beq .done                   ; all equal: not a new record
.copy
        lda score                   ; copy the three digits
        sta hi_score                ; hundreds
        lda score + 1               ; tens
        sta hi_score + 1            ; store it
        lda score + 2               ; ones
        sta hi_score + 2            ; store it
        jmp draw_hiscore            ; show it (draw_hiscore returns to our caller)
.done
        rts                         ; return to the caller

draw_hiscore                        ; subroutine: print the three high score digits
        lda hi_score                ; hundreds digit, a number 0-9
        ora #$30                    ; turn the number into a character
        sta HI_POS                  ; print it
        lda hi_score + 1            ; tens digit
        ora #$30                    ; turn the number into a character
        sta HI_POS + 1              ; print it
        lda hi_score + 2            ; ones digit
        ora #$30                    ; turn the number into a character
        sta HI_POS + 2              ; print it
        rts                         ; return to the caller
