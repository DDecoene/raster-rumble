# Design: all sound through the WebSidTracker player

Status: built (2026-11-22), see As built at the end.

## Why

The game's sound was written by hand: a tune on voice 2 with a filter and pulse sweep done by the game, a bass on voice 1, table drums on voice 3, and three sound effects (blip, ting, explosion) that wrote the SID directly. It worked, but it sounded basic and it could only be changed in assembly. WebSidTracker (a SID tracker in the browser, with a small MIT player) was made for this game: music and effects are seen, heard and edited in the tracker, exported, and played by the same player in the game.

## Goals

- The game writes nothing to the SID itself. Everything that sounds comes from the player: `music_init`, `music_play`, `sfx_play`.
- The current tune is carried over note for note as a tracker project, so the game still sounds like itself; from then on it is edited in the tracker.
- The three moments (a dodge, a new chapter, a hit) play tracker-made effects.
- A clear loop: open the project in the tracker, change it, export, put the files in `src/sound/`, `make`.

Not now: a new soundtrack (that is the next step, by ear), a filter (the player has none; the tune sounds a little brighter without it).

## How

- **Files.** `src/sound/` holds the files from WebSidTracker: `music.asm` (the player, release 0.2.0, MIT, with its licence in `src/sound/LICENSE`), and the exported `instruments.asm`, `sfx.asm` and `song_raster_rumble.asm`. The tracker project is `music/raster-rumble.json`.
- **Memory.** The sound files are assembled right after the game's code and tables, below the sprites at `$2000` (an `!error` guards that). The player's 14 zero page bytes are `$E0` to `$ED`, which the game does not use.
- **When the player runs.** Once per frame, in the place where `update_music` is called now: in the game right after the wait for line `$FB` (before the frame work), on the title and chapter screens after the raster bars. The two calls of the old 100 Hz tune inside the raster code (`music_tick` in `raster_show` and `game_bars`) go. A frame of the player takes about 2,000 to 6,000 cycles; that is measured in VICE so that the game frame still ends before line 54.
- **The tune.** Speed 1 (a tick is a frame). The old tune moved a step every 3.5 frames; every note, bass note and drum of it falls on an even step, so all of them land on whole frames: an arpeggio note lasts 7 frames, a bass note 28, a bar 56. Voice 1 the saw bass (A1 F1 C2 G1, two notes per chord), voice 2 the plucked pulse arpeggio (32 notes, Am F C G), voice 3 a kick (steps 0, 8, 10) and a hat (steps 6, 14). The pulse sweep becomes part of the arpeggio instrument; the filter sweep is gone.
- **Effects.** Dodge (a chirp up) on voice 3; Chapter (two bell notes, one effect) on voice 3; a hit is two effects at once: Hit (a noise rumble) on voice 3 and Hit body (a falling thump) on voice 1, the bass, so the tune on voice 2 is never cut.
- **The bars pump on the kick**, as before: after `music_play` the game looks at the player's state of voice 3 (a note of the kick instrument that started this frame) and pushes `bar_phase` on.
- **Removed:** `music_tick`, the old `update_music` body, the three `sfx_*` routines, the SID set-up in `main.asm`, the music and drum tables in `data.asm`, and their variables and constants.

Other ways that were not taken: a raster interrupt for `music_play` (the game draws its bars by waiting on raster lines, an interrupt in the middle would shift them); two player calls per frame (the player counts one call as one frame).

## As built

What the work found and changed against the plan above:

- **Memory.** The game's code and data already reach almost to `$2000`, so the 2 KB player does not fit below the sprites. The sound sits at `$3000`, after the sprites and the character set at `$2800`-`$2fff`. A build check stops when the code reaches `$2000` (a few dozen bytes are left) and another when the sound reaches the tables at `$c000`.
- **The game frame.** The frame work after line `$fb` already takes the beam to about line 26, so the player could not run there: `game_bars` waited for exactly line 54 and lost a whole frame. Now `game_bars` waits for its first band (line 59, "at least") and calls `update_music` after the plasma, in the free lines from about 200; the main loop waits for line `$fb` *or later*, so a frame where the music runs long goes on at once. Measured: 3244 frames, no frame lost, the first band at most one line late.
- **The title, game over and chapter screens** were already full: their work after the bars ended near line 53 with the bars at 54. To make room without changing the picture: `raster_show` no longer waits for line 54 (the bars wait for line 80 themselves); `update_stars` has a quick path for a star that stays in its cell; the scroller colours, the tagline, the prompt and the clearing of the bouncing letters are written out. Measured: the work with the music ends at most 148 of 156 lines after the bars, no late frame.
- **The hit** plays its thump on voice 1 (the bass), as designed, so the arpeggio on voice 2 is never cut.
- **A new tune (v0.0.6).** The ported tune was replaced by a new one made in the tracker for the 6581: dark, industrial techno at 125 BPM, with new effects under the same names. The kick is still instrument 2. Its peak in the player is a little lower than the old tune's; the title screen work ends at most 153 of 156 lines after the bars (152 before).
