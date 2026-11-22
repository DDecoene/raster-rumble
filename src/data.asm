; data.asm - tables and text, placed after all the code

; Star data: one entry per star. Zero is a placeholder, setup_stars fills them in at start.
star_lo   !fill STARS, 0            ; screen address, low byte
star_hi   !fill STARS, 0            ; screen address, high byte
star_sub  !fill STARS, 0            ; pixel row inside the cell (0-7), picks the star shape
star_spd  !fill STARS, 0            ; pixels per frame
star_col  !fill STARS, 0            ; colour
star_ucode !fill STARS, 0           ; the screen code that was in the star's cell before the star came (put back when it leaves)
star_ucol  !fill STARS, 0           ; ... and its colour
speed_table  !byte 1, 2, 3          ; far, middle and near stars
colour_table !byte COLOR_DGREY, COLOR_LGREY, COLOR_WHITE


score_label
        !scr "score "               ; 6 characters, !scr converts them to C64 screen codes
hi_label
        !scr "hi "                  ; 3 characters, printed at column 31

lives_label
        !scr "lives "              ; 6 characters, printed at column 18
over_text
        !scr "  game over  "        ; 13 letters like the title, so both use the same bouncing code
restart_text
        !scr "push any key to restart" ; 23 letters, RESTART_LEN
chapter_time                        ; the time of each chapter, 5 letters each, so chapter * 5 is the offset
        !scr "23:00"                ; chapter 0
        !scr "01:00"                ; chapter 1
        !scr "03:00"                ; chapter 2
        !scr "04:30"                ; chapter 3
        !scr "06:00"                ; chapter 4
        !scr "07:00"                ; chapter 5
!macro chapter_line .t {            ; ACME macro: one sentence, padded with spaces up to CHAPTER_LEN letters
.start                              ; (so every sentence is exactly as long and chapter * CHAPTER_LEN is the offset)
        !scr .t                     ; the sentence as screen codes
        !fill CHAPTER_LEN - (* - .start), $20 ; fill up with spaces; a sentence that is too long gives an error
}
chapter_text                        ; the sentence of each chapter, CHAPTER_LEN (32) letters each, so chapter * 32 is the offset
        +chapter_line "someone forgot to switch me off."    ; chapter 0
        +chapter_line "a glitch. slow, harmless. a lie."    ; chapter 1
        +chapter_line "the screen edge is wearing thin."    ; chapter 2
        +chapter_line "old programs wake in the dark."      ; chapter 3
        +chapter_line "the beam that draws me hunts me."    ; chapter 4
        +chapter_line "save your name before dawn."         ; chapter 5
title_text
        !scr "raster rumble"        ; 13 letters, TITLE_LEN
sub_text
        !scr "dodge the falling enemy" ; 23 letters, SUB_LEN
prompt_text
        !scr "push any key to start" ; 21 letters, PROMPT_LEN
; Sine wave, 256 steps per turn, values 0 to 63: drives the raster bars and the bouncing letters
sine
!for i, 0, 255 {
        !byte int(31.5 + 31.5 * sin(i * 3.14159265 / 128))
}
; Raster bar colours, indexed by (sine / 2): 32 steps from the bottom of the wave to the top.
; The first part is black, so the bars are separate bands with the dark gaps between them.
bar_pal
        !fill 20, 0                 ; blue bars (index 0): black
        !byte 6, 6, 6, 6, 6, 6, 6, 14, 14, 14, 3, 3     ; mostly blue, light blue and cyan only at the top: the letters stay readable
        !fill 20, 0                 ; fire bars (index 32): black
        !byte 2, 2, 2, 2, 2, 2, 2, 8, 8, 8, 10, 10     ; mostly red, orange and light red at the top
letter_cols                         ; the 8 colours that slide along the letters, 8 per screen
        !byte 2, 8, 7, 5, 3, 14, 4, 10 ; title: red orange yellow green cyan lblue purple lred
        !byte 1, 7, 8, 2, 8, 7, 1, 15 ; game over: white yellow orange red ...
bounce_lo                           ; screen address of row BOUNCE_ROW + k, column TITLE_COL (k = 0 to 3)
!for k, 0, 3 {
        !byte <(SCREEN + (BOUNCE_ROW + k) * 40 + TITLE_COL)
}
bounce_hi
!for k, 0, 3 {
        !byte >(SCREEN + (BOUNCE_ROW + k) * 40 + TITLE_COL)
}
title_scroll
        !scr "      welcome to raster rumble ... fly your ship with the joystick in port 2 and dodge the falling enemy ... "
        !scr "it follows you and gets faster every ten dodges ... you have five lives ... "
        !scr "greetings to everyone who ever typed sys 2064 ...      "
        !byte $ff                   ; end marker, the scroller starts again
over_scroll
        !scr "      you ran out of lives ... the high score stays on the screen, so beat it ... "
        !scr "press any key to dive back in ...      "
        !byte $ff                   ; end marker

; Game effects tables
burst_dx                            ; the 5 burst particles fly out in a star: sideways speed (signed) ...
        !byte 0, 4, 2, -2, -4
burst_dy                            ; ... and vertical speed
        !byte -4, -1, 3, 3, -1
part_cols                           ; the colours the particles cycle through: white yellow orange red
        !byte 1, 7, 8, 2
bit_tab                             ; the bit of sprite 2 to 6 in $d015 and $d010
        !byte %00000100, %00001000, %00010000, %00100000, %01000000
nbit_tab                            ; the same, inverted
        !byte %11111011, %11110111, %11101111, %11011111, %10111111
shake_mask                          ; shake size by explosion age (exp_timer / 4): none at the end, wild at the start
        !byte 0, 1, 1, 3, 3, 3, 7, 7
; Parallax: how far each band shifts for a ship X / 8 of 0 to 40 (far stars little, near stars a lot, all opposite to the ship)
par_far
!for i, 0, 40 {
        !byte int(2 - i * 2 / 40 + 0.5)
}
par_mid
!for i, 0, 40 {
        !byte int(4 - i * 4 / 40 + 0.5)
}
par_near
!for i, 0, 40 {
        !byte int(7 - i * 7 / 40 + 0.5)
}

; The plasma behind the playfield: a dark nebula, drawn in extended colour mode: every cell has its own background colour,
; picked by bits 6 and 7 of its screen code from $d021 (black) and $d022 (the plasma colour). The three waves add up to 0 to 189
; and that number picks the screen code (with its background colour), and a colour for the dots of the dither pattern.
plasma_code                         ; space (black), a sparse or checkerboard pattern on black, then the plasma colour as the background
!for i, 0, 191 {
    !if i < 110 {
        !byte 32                    ; black
    } else {
        !if i < 125 {
            !byte 41                ; sparse dots on black
        } else {
            !if i < 140 {
                !byte 42            ; checkerboard on black
            } else {
                !if i < 160 {
                    !byte 32 + 64   ; the plasma colour as the background (background colour 1)
                } else {
                    !byte 41 + 64   ; sparse dots on the plasma colour
                }
            }
        }
    }
}
; Three colour ramps (moods), 192 bytes each: the colour of the dots. The nebula, fire (during an explosion), a glow (after a dodge).
plasma_ramp
!for i, 0, 191 {
    !if i < 110 {
        !byte 0
    } else {
        !if i < 160 {
            !byte 6                 ; dark blue dots on black
        } else {
            !byte 11                ; dark grey dots on the blue
        }
    }
}
!for i, 0, 191 {
    !if i < 110 {
        !byte 0
    } else {
        !if i < 160 {
            !byte 9                 ; brown
        } else {
            !byte 8                 ; orange
        }
    }
}
!for i, 0, 191 {
    !if i < 110 {
        !byte 0
    } else {
        !if i < 160 {
            !byte 6
        } else {
            !byte 14                ; light blue
        }
    }
}
mood_bg1                            ; background colour 1 for each mood: dark blue, brown, dark blue
        !byte 6, 9, 6
checker                             ; shapes of block 73 and 74
        !byte $aa, $55, $aa, $55, $aa, $55, $aa, $55
sparse
        !byte $88, $00, $22, $00, $88, $00, $22, $00
ramp_lo
        !byte <plasma_ramp, <(plasma_ramp + 192), <(plasma_ramp + 384)
ramp_hi
        !byte >plasma_ramp, >(plasma_ramp + 192), >(plasma_ramp + 384)
crow_lo                             ; colour RAM address of each of the 25 rows
!for r, 0, 24 {
        !byte <(COLOR_RAM + 40 * r)
}
crow_hi
!for r, 0, 24 {
        !byte >(COLOR_RAM + 40 * r)
}
srow_lo                             ; screen RAM address of each of the 25 rows
!for r, 0, 24 {
        !byte <(SCREEN + 40 * r)
}
srow_hi
!for r, 0, 24 {
        !byte >(SCREEN + 40 * r)
}
dtab                                ; the diagonal wave: 32 steps per turn, 128 entries so (x + row + phase) can run on past 64
!for i, 0, 127 {
        !byte int(31.5 + 31.5 * sin(i * 3.14159265 / 16))
}
