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
HIT_FRAMES  = 10                    ; how many frames the border stays red after a hit
SCORE_POS  = SCREEN + 6             ; where the three score digits are printed (after the word "score ")
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
clean_count = $0d                   ; title screen: frames in a row without any key, counts up to RELEASE_FRAMES
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
KEY_FRAMES = 3                      ; a key must be down this many frames in a row to start the game (emulators can give stray bits)
RELEASE_FRAMES = 250                ; the title waits for this many clean frames in a row (5 seconds) before it accepts a key: the emulator types its own RUN keys a few seconds after loading
