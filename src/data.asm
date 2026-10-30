; data.asm - tables and text, placed after all the code

; Star data: one entry per star. Zero is a placeholder, setup_stars fills them in at start.
star_lo   !fill STARS, 0            ; screen address, low byte
star_hi   !fill STARS, 0            ; screen address, high byte
star_sub  !fill STARS, 0            ; pixel row inside the cell (0-7), picks the star shape
star_spd  !fill STARS, 0            ; pixels per frame
star_col  !fill STARS, 0            ; colour
speed_table  !byte 1, 2, 3          ; far, middle and near stars
colour_table !byte COLOR_DGREY, COLOR_LGREY, COLOR_WHITE

; The tune: an A minor, F, C, G arpeggio, 8 notes per chord, as SID frequency values (PAL clock)
music_lo
        !byte $51, $f6, $a2, $67, $ed, $67, $a2, $f6   ; A2 E3 A3 C4 E4 C4 A3 E3
        !byte $cf, $b3, $9d, $a2, $67, $a2, $9d, $b3   ; F2 C3 F3 A3 C4 A3 F3 C3
        !byte $b3, $0a, $67, $ed, $13, $ed, $67, $0a   ; C3 G3 C4 E4 G4 E4 C4 G3
        !byte $85, $c4, $0a, $6d, $89, $6d, $0a, $c4   ; G2 D3 G3 B3 D4 B3 G3 D3
music_hi
        !byte $07, $0a, $0e, $11, $15, $11, $0e, $0a   ; A2 E3 A3 C4 E4 C4 A3 E3
        !byte $05, $08, $0b, $0e, $11, $0e, $0b, $08   ; F2 C3 F3 A3 C4 A3 F3 C3
        !byte $08, $0d, $11, $15, $1a, $15, $11, $0d   ; C3 G3 C4 E4 G4 E4 C4 G3
        !byte $06, $09, $0d, $10, $13, $10, $0d, $09   ; G2 D3 G3 B3 D4 B3 G3 D3

score_label
        !scr "score "               ; 6 characters, !scr converts them to C64 screen codes
hi_label
        !scr "hi "                  ; 3 characters, printed at column 31

lives_label
        !scr "lives "              ; 6 characters, printed at column 18
over_text
        !scr "game over"            ; 9 letters, OVER_LEN
restart_text
        !scr "push any key to restart" ; 23 letters, RESTART_LEN
title_text
        !scr "raster rumble"        ; 13 letters, TITLE_LEN
sub_text
        !scr "dodge the falling enemy" ; 23 letters, SUB_LEN
prompt_text
        !scr "push any key to start" ; 21 letters, PROMPT_LEN
title_colours
        !byte 2, 8, 7, 5, 3, 14, 4, 10 ; red orange yellow green cyan lblue purple lred: the colours that slide along the title
