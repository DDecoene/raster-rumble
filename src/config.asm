; config.asm - the game's own settings: difficulty, screen layout and where our variables live
; Only names live here, no code or data, so nothing in this file takes up any memory.
;
; WHERE IS WHAT? Search for the number in front of the heading (for example "[3]").
;
;   [1] Debug switch
;   [2] Game rules          difficulty, lives, story chapters
;   [3] Playfield           the area the ship and enemy may move in
;   [4] Game screen         where score, lives and hi score are printed
;   [5] Title screen        text positions, waiting times, raster bars, scroller
;   [6] Sound               music and sound effect timing
;   [7] Stars               the scrolling starfield
;   [8] Game effects        explosion, flash, parallax bands
;   [9] Zero page           all variables in $02 to $fe, in address order
;  [10] RAM tables          the big tables outside the zero page ($c000 and up)

; ============================================================================================================
; [1] DEBUG SWITCH
; ============================================================================================================
SHOW_JOY   = 0                      ; 1 = temporary test readout of the raw joystick bits on the top row

; ============================================================================================================
; [2] GAME RULES
; ============================================================================================================
ENEMY_SPEED = 2                     ; pixels the enemy falls per frame at the start of a game
MAX_SPEED   = 5                     ; the enemy never falls faster than this
DODGES_PER_LEVEL = 10               ; every 10 dodged enemies the enemy gets 1 pixel per frame faster
LIVES       = 5                     ; lives at the start of a game
HIT_FRAMES  = 10                    ; how many frames the border stays red after a hit
; The story: the night is split into chapters (see docs/story.md)
CHAPTER_DODGES = 25                 ; dodges needed to finish a chapter (use 2 while testing, 25 takes minutes)
CHAPTERS       = 6                  ; number of chapters in the story
; The Border (chapter 2): some enemies drift sideways and bounce off the left and right edges
ENEMY_DRIFT = 2                     ; pixels per frame a drifting enemy moves sideways (half the screen while it falls)
; The Glitch (chapter 2, the second enemy): it falls slowly, then suddenly fast, with no warning
GLITCH_WAIT = 60                    ; frames the Glitch falls slowly (1.2 seconds), then it speeds up
GLITCH_SLOW = 1                     ; pixels per frame while it falls slowly
GLITCH_FAST = 5                     ; pixels per frame after the wait (the same as MAX_SPEED of the first enemy)

; ============================================================================================================
; [3] PLAYFIELD: limits so the sprite stays in the visible part of the screen
; ============================================================================================================
MIN_X = 24                          ; left edge of the screen area
MAX_X = 320                         ; right edge: the screen area is X 24 to 343 and the sprite is 24 wide.
                                    ; X is 9 bits wide, bit 8 lives in $d010 (see SPR_XHI)
MIN_Y = 50                          ; top edge of the screen area
MAX_Y = 229                         ; bottom edge

; ============================================================================================================
; [4] GAME SCREEN: where the numbers on the top row are printed
; ============================================================================================================
SCORE_POS  = SCREEN + 6             ; where the three score digits are printed (after the word "score ")
LIVES_POS  = SCREEN + 24            ; where the lives digit is printed (after "lives " at column 18)
HI_POS     = SCREEN + 34            ; where the three high score digits are printed (after "hi " at column 31)

; ============================================================================================================
; [5] TITLE SCREEN AND GAME OVER SCREEN
; ============================================================================================================
; Text lines: row, first column, length and the resulting screen address
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
VERSION_ROW = 19                    ; row of the version number on the title screen
VERSION_POS = SCREEN + VERSION_ROW * 40 + (40 - VERSION_LEN) / 2 ; centred, VERSION_LEN is set in version.asm
RESTART_LEN = 23                    ; letters in "push any key to restart"
RESTART_COL = 8
RESTART_POS = SCREEN + PROMPT_ROW * 40 + RESTART_COL
; Chapter screen (between two chapters of the story)
CHAP_TIME_POS = SCREEN + 9 * 40 + 17   ; screen address of the time, "23:00" (5 letters) on row 9
CHAP_TEXT_POS = SCREEN + 12 * 40 + 4   ; screen address of the sentence, row 12, column 4
CHAPTER_LEN   = 32                  ; letters reserved for every sentence (the macro in data.asm pads shorter ones with spaces).
                                    ; Keep it 32: chapter.asm finds a sentence with 5 shifts left (chapter * 32)
CHAP_FRAMES   = 150                 ; how long the chapter screen shows: 3 seconds
CHAP_TING_GAP = 10                  ; frames between the two 'ting' notes when the chapter screen opens (0.2 s)
CHAP_TING_SFX = 22                  ; the drums stay silent this long after a ting, so they do not cut it short
; Waiting times
KEY_FRAMES = 1                      ; frames a key must be down to start the game: a quick tap in the browser emulator lasts only one frame
RELEASE_FRAMES = 250                ; the title ignores all keys for this many frames (5 seconds) after loading: emulators type their own RUN keys then
OVER_WAIT  = 50                     ; frames (1 second) the game over screen ignores keys, so the last joystick moves do not skip it
; Raster bars behind the text
BAR_TOP    = 80                     ; first raster line of the colour bars
BAR_END    = 210                    ; first raster line after the bars
BAR_FREQ   = 4                      ; sine steps per raster line: 4 gives a bar every 64 lines
; Bouncing letters
BOUNCE_ROW = 6                      ; the bouncing letters sit on rows 6 to 9 (a sine wave of 4 rows)
; Scroller
SCROLL_ROW = 22                     ; row of the scroller
SCROLL_POS = SCREEN + SCROLL_ROW * 40
SCROLL_LINE = 51 + SCROLL_ROW * 8 - 3 ; raster line just above the scroller row: fine scroll switches on (display starts at line 51)
SCROLL_STOP = SCROLL_LINE + 12      ; a line below the scroller row: fine scroll back to 0

; ============================================================================================================
; [6] SOUND
; ============================================================================================================
MUSIC_TICKS = 7                     ; ticks per step of the tune. A tick is half a frame (100 Hz), so a step is 3.5 frames (a 16th note)
MUSIC_LEN  = 64                     ; steps in the tune before it loops (the arpeggio plays on every 2nd step: 32 notes)
DRUM_LEN    = 14                    ; ticks per drum table (140 ms, two steps of the tune)
SFX_BLIP   = 6                      ; the dodge blip is short, so the drums only wait this long
SFX_FRAMES = 30                     ; after the explosion the drums stay silent this long (0.6 s), so they do not cut the effect short

; ============================================================================================================
; [7] STARS
; ============================================================================================================
STARS      = 12                     ; number of stars
CHARSET    = $2800                  ; our copy of the character set (VIC reads it from here, see $d018 below)
STAR_CHAR  = 33                     ; screen code of the first star shape: 8 shapes (33 to 40), a dot in pixel row 0 to 7. Below 64, because extended colour mode only has 64 characters

; ============================================================================================================
; [8] GAME EFFECTS: raster bars behind the playfield, a burst of sprites and a shake when the ship is hit, parallax bands
; ============================================================================================================
EXP_FRAMES  = 28                    ; how long the explosion lasts (0.56 s)
DODGE_FLASH = 5                     ; how long the bars flash after a dodge
BAND1_LINE  = 51 + 1 * 8            ; raster line where row 1 starts: the score row above it never moves
BAND2_LINE  = 51 + 7 * 8            ; row 7 starts
BAND3_LINE  = 51 + 15 * 8           ; row 15 starts

; ============================================================================================================
; [9] ZERO PAGE: every variable in $02 to $fe, in address order. A gap in the list is a free byte.
; ============================================================================================================
; The game itself
joy       = $02                     ; a spare zero-page byte where we keep a copy of the joystick
hit_timer = $03                     ; frames left to show the red border (0 = not flashing)
score     = $04                     ; three bytes, $04 $05 $06: hundreds, tens, ones (each 0-9)
enemy_speed = $07                   ; pixels the enemy falls per frame right now (ENEMY_SPEED up to MAX_SPEED)
dodge_count = $08                   ; dodged enemies since the last speed-up (0 to DODGES_PER_LEVEL - 1)
frame_count = $09                   ; counts frames, its lowest bit flips every frame (used to slow the homing)
; Music
music_timer = $0a                   ; ticks left until the next step of the tune
music_step  = $0b                   ; which of the 64 steps plays next
; Title screen
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
; Sound and random numbers
sfx_timer   = $1d                   ; frames left in which a sound effect owns voice 3 (the drums wait)
rnd         = $1e                   ; the state of the random number generator (never 0)
drum_idx    = $1f                   ; tick of the drum that is playing, 1 to DRUM_LEN (0 = no drum playing)
drum_base   = $20                   ; where the playing drum starts in the drum tables: 0, DRUM_LEN or 2 * DRUM_LEN
; Game effects
dodge_flash = $21                   ; frames left in which the bars flash after a dodge
band1       = $22                   ; $d016 value (fine scroll) for the top band of the playfield, rows 1 to 6
band2       = $23                   ; ... the middle band, rows 7 to 14
band3       = $24                   ; ... the bottom band, rows 15 to 24
exp_timer   = $25                   ; frames left of the explosion (burst, shake, fire bars). 0 = none. No new hit counts while it runs
shake_x     = $26                   ; this frame's shake, horizontal pixels (0 up to the mask)
shake_y     = $27                   ; this frame's vertical scroll value for $d011 (3 = no shake)
fx_tmp      = $28                   ; scratch
plasma_ph1  = $29                   ; plasma: phase of the horizontal wave (it drifts as the frames go by)
plasma_ph2  = $2a                   ; ... of the vertical wave
plasma_ph3  = $2b                   ; ... of the diagonal wave (0 to 63)
plasma_row  = $2c                   ; ... the next row to recolour (1 to 24; row 0 is the score)
plasma_rowv = $2d                   ; ... the vertical wave value of the row that is being coloured
chap_timer  = $2e                   ; chapter screen: frames it has been showing (counts up to CHAP_FRAMES)
plasma_cnt  = $2f                   ; counts rows while the whole plasma is built at once
star_bg     = $30                   ; scratch: the background bits (6 and 7) of the screen code under a star
; The story
chapter        = $31                ; which chapter we are in: 0 = 23:00 up to 5 = 07:00. Set to 0 in reset_difficulty
chapter_dodges = $32                ; dodged enemies in this chapter so far. Back to 0 when a new chapter starts
; The Glitch
glitch_active = $33                 ; 0 = no Glitch yet (chapter 0), 1 = it is falling. Set to 0 in reset_difficulty
glitch_timer  = $34                 ; frames the current Glitch has been falling (counts up, back to 0 when it respawns)
; The Border
enemy_dx      = $35                 ; sideways direction of the enemy: 0 = straight down, 1 = right, $ff (-1) = left
; Scratch bytes shared by several routines (they must not be needed at the same time)
star_ptr    = $fb                   ; $fb $fc: screen address of the star being updated (zero page pointer)
xlo         = $fd                   ; scratch: 9-bit X being built for the enemy (low byte), shares $fd/$fe with star_cptr
xhi         = $fe                   ; ... and its high byte (0 or 1)
star_cptr   = $fd                   ; $fd $fe: the matching colour RAM address

; ============================================================================================================
; [10] RAM TABLES outside the zero page, in address order
; ============================================================================================================
; The high score lives at $c000, a free RAM block outside our program and the zero page.
; Nothing loads over it or clears it, so it survives hits, a restart with RUN and a reload.
; A power-off wipes it, which is why a magic byte says whether the bytes are valid.
hi_score   = $c000                  ; three bytes, $c000 $c001 $c002: hundreds, tens, ones (each 0-9)
hi_magic   = $c003                  ; holds HI_MAGIC once hi_score has been set up
HI_MAGIC   = $a5                    ; any value that random power-on RAM is unlikely to hold
barcol      = $c100                 ; 256 bytes in free RAM: the colour of each step of the sine wave, filled by make_bars
PLASMA_COLX = $c500                 ; 40 bytes: the horizontal wave of each column, worked out once per frame
PART_LO     = $c600                 ; the 5 burst particles (sprites 2 to 6): X low byte ...
PART_HI     = $c605                 ; ... X bit 8 (0 or 1) ...
PART_Y      = $c60a                 ; ... Y ...
PART_DX     = $c60f                 ; ... pixels per frame sideways (signed) ...
PART_DY     = $c614                 ; ... and up or down (signed)
