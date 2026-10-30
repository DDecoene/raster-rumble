; actors.asm - the ship and the enemy: 9-bit X movement, spawning, homing and difficulty

!zone spawn_enemy
spawn_enemy                         ; subroutine: enemy to the top, random X anywhere in the visible range
        lda #MIN_Y - 10             ; just above the visible area, so it slides in
        sta SPR1_Y                  ; set enemy Y
        jsr random_column           ; A = 0 to 39
        cmp #37                     ; we want 0 to 36 so the enemy stays fully on screen
        bcc .ok                     ; already in range
        sbc #37                     ; 37-39 become 0-2 (carry is set here)
.ok
        sta xlo                     ; build X = 24 + column * 8 + 0..7 in 9 bits: first the column ...
        lda #0                      ; ... as a 16-bit number xhi:xlo
        sta xhi                     ; high byte 0
        asl xlo                     ; times 2: shift left, the bit that falls out goes into carry ...
        rol xhi                     ; ... and rol shifts that carry into the high byte
        asl xlo                     ; times 4
        rol xhi                     ; (carry into the high byte again)
        asl xlo                     ; times 8
        rol xhi                     ; (and again)
        lda SID_OSC3                ; random byte
        and #%00000111              ; 0 to 7: a random pixel inside the column
        clc                         ; clear carry before adding
        adc xlo                     ; add it to the low byte
        sta xlo                     ; store it
        bcc .noc1                   ; no overflow
        inc xhi                     ; overflow: high byte + 1
.noc1
        lda xlo                     ; now add the left edge
        clc                         ; clear carry
        adc #MIN_X                  ; + 24
        sta xlo                     ; store it
        bcc .noc2                   ; no overflow
        inc xhi                     ; overflow: high byte + 1
.noc2
        sta SPR1_X                  ; low 8 bits of the enemy X (A still holds xlo)
        lda SPR_XHI                 ; bit 8 of all sprites
        and #%11111101              ; clear the enemy's bit (bit 1)
        ldx xhi                     ; is X 256 or more?
        beq .store                  ; no, bit stays clear
        ora #%00000010              ; yes, set the enemy's bit 8
.store
        sta SPR_XHI                 ; write it back
        rts                         ; return to the caller

!zone ship_left
ship_left                           ; subroutine: ship X - 1 as a 9-bit number, stops at MIN_X
        lda SPR_XHI                 ; bit 0 = bit 8 of the ship X
        and #%00000001              ; keep only that bit
        bne .move                   ; X is 256 or more, the left edge is far away
        lda SPR0_X                  ; low byte
        cmp #MIN_X                  ; at the left edge?
        beq .done                   ; yes, don't move
.move
        lda SPR0_X                  ; low byte again
        bne .dec                    ; not 0, so no borrow from bit 8 needed
        lda SPR_XHI                 ; low byte is 0: X goes from 256 to 255, so clear bit 8
        and #%11111110              ; clear the ship's bit
        sta SPR_XHI                 ; write it back
.dec
        dec SPR0_X                  ; low byte - 1 (0 wraps around to 255)
.done
        rts                         ; return to the caller

!zone ship_right
ship_right                          ; subroutine: ship X + 1 as a 9-bit number, stops at MAX_X
        lda SPR_XHI                 ; bit 0 = bit 8 of the ship X
        and #%00000001              ; keep only that bit
        beq .move                   ; X is below 256, the right edge is far away
        lda SPR0_X                  ; low byte (X = 256 + low byte)
        cmp #MAX_X - 256            ; at the right edge?
        beq .done                   ; yes, don't move
.move
        inc SPR0_X                  ; low byte + 1
        bne .done                   ; it did not wrap around to 0, finished
        lda SPR_XHI                 ; it wrapped: X went from 255 to 256, so set bit 8
        ora #%00000001              ; set the ship's bit
        sta SPR_XHI                 ; write it back
.done
        rts                         ; return to the caller

!zone enemy_left
enemy_left                          ; subroutine: enemy X - 1 as a 9-bit number
        lda SPR1_X                  ; low byte
        bne .dec                    ; not 0, so no borrow needed
        lda SPR_XHI                 ; low byte is 0: clear bit 8 (X goes from 256 to 255)
        and #%11111101              ; the enemy's bit is bit 1
        sta SPR_XHI                 ; write it back
.dec
        dec SPR1_X                  ; low byte - 1
        rts                         ; return to the caller

!zone enemy_right
enemy_right                         ; subroutine: enemy X + 1 as a 9-bit number
        inc SPR1_X                  ; low byte + 1
        bne .done                   ; did not wrap around to 0
        lda SPR_XHI                 ; wrapped: X went from 255 to 256, so set bit 8
        ora #%00000010              ; the enemy's bit is bit 1
        sta SPR_XHI                 ; write it back
.done
        rts                         ; return to the caller

!zone home_enemy
home_enemy                          ; subroutine: move the enemy one pixel towards the ship (9-bit compare)
        lda SPR_XHI                 ; bit 0 = ship bit 8, bit 1 = enemy bit 8
        and #%00000011              ; keep those two
        cmp #%00000001              ; only the ship is past 255?
        beq .right                  ; then the enemy is left of it
        cmp #%00000010              ; only the enemy is past 255?
        beq .left                   ; then the enemy is right of the ship
        lda SPR1_X                  ; same bit 8 for both: compare the low bytes, enemy X
        cmp SPR0_X                  ; compared with the ship X (carry set if enemy X >= ship X)
        beq .done                   ; same X, nothing to do
        bcs .left                   ; the enemy is right of the ship
.right
        jmp enemy_right             ; move the enemy right (enemy_right returns to our caller)
.left
        jmp enemy_left              ; move the enemy left
.done
        rts                         ; return to the caller

!zone count_dodge                   ; ACME: '.labels' are local to a zone, so each subroutine gets its own
count_dodge                         ; subroutine: after every 10th dodge the enemy gets faster
        inc dodge_count             ; one more dodge
        lda dodge_count             ; load it to compare
        cmp #DODGES_PER_LEVEL       ; reached 10?
        bcc .done                   ; no, finished
        lda #0                      ; yes: start counting again ...
        sta dodge_count             ; ... from 0
        lda enemy_speed             ; current speed
        cmp #MAX_SPEED              ; already at the maximum?
        bcs .done                   ; yes, leave it
        inc enemy_speed             ; no, one pixel per frame faster
.done
        rts                         ; return to the caller

reset_difficulty                    ; subroutine: back to the slow start speed
        lda #ENEMY_SPEED            ; the starting speed
        sta enemy_speed             ; set it
        lda #0                      ; A = 0
        sta dodge_count             ; no dodges counted yet
        rts                         ; return to the caller
