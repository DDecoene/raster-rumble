; config.asm - the game's own settings: difficulty, screen layout and where our variables live
; Only names live here, no code or data, so nothing in this file takes up any memory.

SHOW_JOY   = 0                      ; 1 = temporary test readout of the raw joystick bits on the top row
; Limits so the sprite stays in the visible part of the screen
MIN_X = 24                          ; left edge of the screen area
MAX_X = 320                         ; right edge: the screen area is X 24 to 343 and the sprite is 24 wide.
                                    ; X is 9 bits wide, bit 8 lives in $d010 (see SPR_XHI)
MIN_Y = 50                          ; top edge of the screen area
MAX_Y = 229                         ; bottom edge
ENEMY_SPEED = 2                     ; pixels the enemy falls per frame at the start of a game
MAX_SPEED   = 5                     ; the enemy never falls faster than this
DODGES_PER_LEVEL = 10               ; every 10 dodged enemies the enemy gets 1 pixel per frame faster
LIVES       = 5                    ; lives at the start of a game
HIT_FRAMES  = 10                    ; how many frames the border stays red after a hit
SCORE_POS  = SCREEN + 6             ; where the three score digits are printed (after the word "score ")
LIVES_POS  = SCREEN + 24            ; where the lives digit is printed (after "lives " at column 18)
HI_POS     = SCREEN + 34            ; where the three high score digits are printed (after "hi " at column 31)
; The high score lives at $c000, a free RAM block outside our program and the zero page.
; Nothing loads over it or clears it, so it survives hits, a restart with RUN and a reload.
; A power-off wipes it, which is why a magic byte says whether the bytes are valid.
hi_score   = $c000                  ; three bytes, $c000 $c001 $c002: hundreds, tens, ones (each 0-9)
hi_magic   = $c003                  ; holds HI_MAGIC once hi_score has been set up
HI_MAGIC   = $a5                    ; any value that random power-on RAM is unlikely to hold
joy       = $02                     ; a spare zero-page byte where we keep a copy of the joystick
hit_timer = $03                     ; frames left to show the red border (0 = not flashing)
score     = $04                     ; three bytes, $04 $05 $06: hundreds, tens, ones (each 0-9)
enemy_speed = $07                   ; pixels the enemy falls per frame right now (ENEMY_SPEED up to MAX_SPEED)
dodge_count = $08                   ; dodged enemies since the last speed-up (0 to DODGES_PER_LEVEL - 1)
frame_count = $09                   ; counts frames, its lowest bit flips every frame (used to slow the homing)
music_timer = $0a                   ; frames left until the next music note
music_step  = $0b                   ; which of the 32 notes plays next
key_count   = $0c                   ; title screen: frames in a row that a key has been down
clean_count = $0d                   ; title screen: frames since the title appeared, counts up to RELEASE_FRAMES, then RELEASE_FRAMES + 1 once a frame with no key was seen
lives       = $0e                   ; lives left, 0 means game over
title_mode  = $0f                   ; 0 = the title is showing, 1 = the game over screen
bar_phase   = $10                   ; title/game over: where the raster bars are in their sine wave
scr_fine    = $11                   ; the scroller: fine scroll in pixels (7 down to 0), then it moves one letter
scr_idx     = $12                   ; the scroller: index of the letter at the left edge of the row
txt_ptr     = $13                   ; $13 $14: the 13 letters that bounce ("raster rumble" or the game over text)
scr_ptr     = $15                   ; $15 $16: the scroller text, ends with $ff
pal_base    = $17                   ; 0 = blue bar colours, 32 = fire bar colours (index into bar_pal)
col_base    = $18                   ; 0 = title letter colours, 8 = game over letter colours (index into letter_cols)
row_ptr     = $19                   ; $19 $1a: screen address where the current bouncing letter goes (column of the letter included)
crow_ptr    = $1b                   ; $1b $1c: the matching colour RAM address
star_ptr    = $fb                   ; $fb $fc: screen address of the star being updated (zero page pointer)
xlo         = $fd                   ; scratch: 9-bit X being built for the enemy (low byte), shares $fd/$fe with star_cptr
xhi         = $fe                   ; ... and its high byte (0 or 1)
star_cptr   = $fd                   ; $fd $fe: the matching colour RAM address
STARS      = 12                     ; number of stars
CHARSET    = $2800                  ; our copy of the character set (VIC reads it from here, see $d018 below)
STAR_CHAR  = 64                     ; screen code of the first star shape: 8 shapes, a dot in pixel row 0 to 7
MUSIC_FRAMES = 7                    ; frames per note (about 7 notes a second)
MUSIC_LEN  = 32                     ; notes in the tune before it loops
TITLE_ROW  = 7                      ; title screen: screen row of the big name
SUB_ROW    = 10                     ; row of the tagline
PROMPT_ROW = 16                     ; row of "push any key to start"
TITLE_LEN  = 13                     ; letters in "raster rumble"
SUB_LEN    = 23                     ; letters in "dodge the falling enemy"
PROMPT_LEN = 21                     ; letters in "push any key to start"
TITLE_COL  = 13                     ; first column of each line, picked to centre it on 40 columns
SUB_COL    = 8                      ;
PROMPT_COL = 9                      ;
TITLE_POS  = SCREEN + TITLE_ROW * 40 + TITLE_COL   ; screen address of the first letter of each line
SUB_POS    = SCREEN + SUB_ROW * 40 + SUB_COL
PROMPT_POS = SCREEN + PROMPT_ROW * 40 + PROMPT_COL
RESTART_LEN = 23                    ; letters in "push any key to restart"
RESTART_COL = 8
RESTART_POS = SCREEN + PROMPT_ROW * 40 + RESTART_COL
OVER_WAIT  = 50                     ; frames (1 second) the game over screen ignores keys, so the last joystick moves do not skip it
barcol      = $c100                 ; 256 bytes in free RAM: the colour of each step of the sine wave, filled by make_bars
BAR_TOP    = 80                     ; first raster line of the colour bars
BAR_END    = 210                    ; first raster line after the bars
BAR_FREQ   = 4                      ; sine steps per raster line: 4 gives a bar every 64 lines
BOUNCE_ROW = 6                      ; the bouncing letters sit on rows 6 to 9 (a sine wave of 4 rows)
SCROLL_ROW = 22                     ; row of the scroller
SCROLL_POS = SCREEN + SCROLL_ROW * 40
SCROLL_LINE = 51 + SCROLL_ROW * 8 - 3 ; raster line just above the scroller row: fine scroll switches on (display starts at line 51)
SCROLL_STOP = SCROLL_LINE + 12      ; a line below the scroller row: fine scroll back to 0
KEY_FRAMES = 1                      ; frames a key must be down to start the game: a quick tap in the browser emulator lasts only one frame
RELEASE_FRAMES = 250                ; the title ignores all keys for this many frames (5 seconds) after loading: emulators type their own RUN keys then
