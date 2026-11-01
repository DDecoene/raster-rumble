# raster-rumble

A Commodore 64 game written in 6502 assembly. Built for fun, nostalgia and, one day, real hardware.

**Status: alpha.** Download the latest build from the [Releases page](https://github.com/DDecoene/raster-rumble/releases/latest): the `.prg` for an emulator, Kung Fu Flash or Ultimate, or the `.d64` disk image. Two of the six chapters of the story are playable so far.

A title screen waits for a key (or the joystick) before the game starts. You fly a ship along the bottom of the screen and dodge a falling enemy. Every dodge scores a point. The enemy gets faster as your score climbs and drifts toward you while it falls. You have 5 lives (`lives` at the top). A hit flashes the border, plays an explosion and costs a life. After the last one a game over screen waits for any key, then a new game starts with score 000. The best score stays on screen as `hi`. Stars scroll behind the action and a looping arpeggio plays while you dodge. After ten dodges a chapter screen opens and the Glitch, a second falling enemy that suddenly speeds up, joins in.

## Tools

    brew install acme

- **ACME** is the assembler (no Java needed).
- **vc64web** is the emulator. It runs in the browser and `make test` fetches it for you (see Testing in the browser).
- Editor: VS Code with the VS64 extension (`code --install-extension rosc.vs64`). It builds with ACME: press Ctrl-Shift-B. VS64 only supports ACME and Kick Assembler, which is why this project uses ACME.

## Build and run

    make        # assembles build/raster-rumble.prg
    make test   # builds, then runs it in the browser emulator (see below)
    make clean

Controls: joystick in port 2. In the browser emulator (`make test`) the arrow keys are the joystick (port 2), and Space is fire.

### Testing in the browser

The game runs in the vc64web browser emulator:

    make test      # builds, (re)starts a local server and opens the game in your browser
    make serve     # only the server, on http://127.0.0.1:8000 (Ctrl-C stops it)
    make stop      # stops the server that make test leaves running in the background

The first run clones the emulator into `tools/vc64web` (about 26 MB, ignored by git). `tools/serve.py` serves the emulator at `/` and the newest build at `/game/raster-rumble.prg`. It also changes the emulator a little as it serves it: it adds a small loader that fetches the newest build once the emulator runs (the emulator's own load-from-address feature did not work in every browser) and puts the keyboard on joystick port 2, and it replaces the offline cache that would keep serving an old build. So there is nothing to upload. After a change, run `make test` again, or `make` and reload the page. `make test` waits until the server answers before it opens the browser. The server keeps running in the background until you run `make stop`.

#### The dodging bot

`tools/bot.js` plays the game for you, to reach later chapters without playing by hand. Paste it into the browser console of the emulator page (or load it with a test tool), then use `bot.start()`, `bot.status()` and `bot.stop()`. It reads the sprite positions from the emulated C64 and steers with the arrow keys, walking to the spot on the screen that is farthest from the falling things (the enemy, and the Glitch once it is active). On the title and game over screens it taps Space, so it plays on after a game over. To test hits it can ram instead of dodge: `bot.start('enemy')` or `bot.start('glitch')` flies into that one (`'glitch'` dodges the enemy until the Glitch is in the game). In that mode it ignores the other falling thing, so that one hits too now and then. It only moves left and right and does not always survive: the status shows `best`, `maxChapter` and `games`.

### Joystick readout

To see what the C64 actually receives, set `SHOW_JOY = 1` in `src/config.asm`: the five digits on the top row are up, down, left, right and fire (0 = pressed).

To run on a real C64, copy `build/raster-rumble.prg` to an SD card for a Kung Fu Flash, Ultimate 64 or similar.

## The story

The game tells *The Night of the Raster Beam*. It is 1986 and a kid forgot to switch off the Commodore 64. Inside lives Pixel, a small ship. The Raster Beam that draws the screen has started to stutter, and at 07:00 someone will pull the plug. Pixel has until morning to write its name to the floppy disk, the only place that survives the power cut. Every hour of the night is a chapter, and a chapter screen with the time and one sentence shows between them.

| Time | Chapter | Playable |
|---|---|---|
| 23:00 | Boot | yes |
| 01:00 | The Glitch | yes |
| 03:00 | The Border | not yet |
| 04:30 | The Memory | not yet |
| 06:00 | The Raster Beam | not yet |
| 07:00 | The Disk | not yet |

The full story and the plans per chapter are in `docs/story.md`.

## Releases

The latest build is always on the [Releases page](https://github.com/DDecoene/raster-rumble/releases/latest): `raster-rumble-vX.Y.Z.prg` (emulators, Kung Fu Flash, Ultimate) and `raster-rumble-vX.Y.Z.d64` (disk image). We are in alpha, so versions are `0.0.x`.

How it works:

- The version lives in `src/version.asm` (`!scr "v0.0.1"`) and is shown on the title screen. `make version` prints it.
- `main` only changes through a pull request from `dev`. `.github/workflows/pr-check.yml` fails a pull request that comes from another branch, that does not raise the version above the one on `main`, or that does not build.
- When the pull request is merged, `.github/workflows/release.yml` builds the game, makes the disk image (with `c1541`, part of VICE), tags the commit `vX.Y.Z` and creates a release with both files and generated release notes.
- So the steps are: on `dev`, raise the version in `src/version.asm` in a commit, open a pull request `dev` to `main`, wait for the checks, merge.
- `make d64` and `make dist` (the release files in `build/dist`) do the same locally. They need `c1541`: `brew install vice`.

One-time GitHub setup (Settings, Branches, rule for `main`): require a pull request before merging, require the status check `check` (the job of `pr-check.yml`), and include administrators, so nobody can push to `main` directly.

## Contributing and license

Contributions are welcome, see `CONTRIBUTING.md` (pull requests go to `dev`).

The game, its code, story and assets are licensed under [CC BY-NC-SA 4.0](LICENSE): you may play, share and adapt them with credit, for non-commercial use, and what you make from them must use the same license.

I have no intention of selling this game, but I do not want anyone else to sell it either. That is why the license is non-commercial, and why contributions are handed over to me: it keeps the whole project under one owner, free to play for everyone and protected from commercial use.

## Project layout

    LICENSE               CC BY-NC-SA 4.0
    CONTRIBUTING.md       how to contribute, and who owns a contribution
    src/main.asm          startup code and the main loop, includes everything else
    src/hardware.asm      names for the VIC, SID and CIA registers, colours, fixed memory areas
    src/config.asm        difficulty settings, screen layout, zero page and RAM variable addresses
    src/actors.asm        ship and enemy: 9-bit X movement, spawning, homing, difficulty
    src/score.asm         score and high score
    src/starfield.asm     RAM character set, scrolling stars, random_column
    src/music.asm         the tune: synth arpeggio on SID voice 2, bass on voice 1, sound effects on voice 3
    src/title.asm         the title and game over screens and the any-key check
    src/demo.asm          their demo effects: raster bars, bouncing letters, scroller
    src/chapter.asm       the screen between two chapters of the story (see docs/story.md)
    src/data.asm          tables and text (star data, note tables, labels)
    src/version.asm       the version number (the one place it lives), shown on the title screen
    src/sprites.asm       the ship and enemy shapes at $2000
    tools/serve.py        local server for the browser emulator (make test)
    tools/bot.js          dodging bot for test runs in the browser emulator
    tools/version.sh      prints the version from src/version.asm (Makefile and workflows use it)
    .github/workflows/    pr-check.yml checks pull requests to main, release.yml builds and publishes a release
    project-config.json   VS64 project settings (toolkit: acme)
    .vscode/              build task, test task, launch config
    Makefile              command-line build

Every line of every file is commented. `main.asm` pulls the others in with `!source`, in the order they should sit in memory: code first, then data, then the sprites at `$2000`. `hardware.asm` and `config.asm` only contain names, so they use no memory. When you add a file, add a `!source` line for it in `main.asm` (paths are relative to the project folder) and check that the sprites still start at `$2000`. The Makefile rebuilds when any file in `src/` changes.

## How it works

- The program loads at `$0801` with a BASIC stub (`10 SYS 2064`), and the code starts at `$0810`. A build-time check fails if `start` moves off 2064.
- Sprite 0 is the ship, sprite 1 is the enemy. Both are multicolor (12 fat pixels per row, 2 bits each: transparent, own colour, plus orange and yellow shared by both sprites via `$d025`/`$d026`) and have two animation frames. Shapes: ship A `$2000` (pointer 128), enemy A `$2040` (129), ship B `$2080` (130), enemy B `$20c0` (131). The frame switches every 8 frames by bit 3 of `frame_count`. The shapes are drawn as ASCII art in the comments next to each row (`.` transparent, `a` orange, `b` own colour, `c` yellow).
- The main loop waits for raster line `$fb` once per frame, then picks the animation frame, scrolls the stars, plays the next music note if it is time, reads the joystick, moves the enemy, checks the hardware sprite collision register (`$d01e`) and updates the score. All of that takes about 7% of a PAL frame.
- Sprite X positions are 9 bits wide: the low 8 bits are in `$d000` (ship) and `$d002` (enemy), bit 8 is in `$d010` (bit 0 = ship, bit 1 = enemy). The visible area is X 24 to 343, so the ship moves between `MIN_X` = 24 and `MAX_X` = 320 (a 24 pixel wide sprite just fits). `ship_left`, `ship_right`, `enemy_left`, `enemy_right` and `home_enemy` do the 9-bit arithmetic: when the low byte wraps, they set or clear bit 8.
- Random numbers come from `random_byte` (in `src/starfield.asm`): an 8 bit shift register with feedback in zero page `$1e` (`rnd`), mixed with the raster line. (It used to read the SID voice 3 noise, but voice 3 now plays the drums.) The enemy spawns at X = 24 + random column x 8 + 0 to 7 (`spawn_enemy`).
- The score is three separate digit bytes (hundreds, tens, ones) in zero page `$04`-`$06`, printed by adding `$30` to each digit.

### Title screen

`title_screen` (in `src/title.asm`) runs once at startup, before the first enemy appears. It hides the sprites, then loops once per frame: scroll the stars, play the tune, redraw the three text lines (a star passing over a letter would otherwise leave a hole), and call `any_key`. The title letters cycle through 8 colours and "push any key to start" flashes. `any_key` first calls `cia_inputs` (both CIA ports back to inputs, timers off the port pins), then reports carry set when joystick port 2 has a pin low or any key in the keyboard matrix is down: it briefly drives all 8 keyboard columns low and reads the rows, then puts the CIA ports back as inputs for the game. For the first `RELEASE_FRAMES` frames all input is ignored (an emulator types its own RUN keys then), and a press only counts after one frame with nothing pressed; it then has to be down for `KEY_FRAMES` frames.

Note: in an emulator the title used to start by itself, and a joystick direction seemed to stick (raw bits `10101`). Three causes were found in the browser emulator. (1) CIA 1 timer B was set to show on port B pin 7, so keyboard row 7 (Space, Q, Run/Stop ...) read as a key down. (2) Data direction of port B (`$dc03`) read back as `$0f` instead of 0, which let the emulated keyboard pull joystick lines low. (3) The emulator types its own `run` a few seconds after loading the game. The game now calls `cia_inputs` before every joystick read, which sets both ports back to inputs and takes the timers off the port pins, and the title ignores all keys for `RELEASE_FRAMES` frames (5 seconds) after loading. After that, a key counts as soon as it is seen down for `KEY_FRAMES` frame (a quick tap in the browser emulator lasts about one frame).

### Memory map

| Address | Use |
|---------|-----|
| `$0400`-`$07e7` | screen memory (`$07f8`/`$07f9` hold the sprite pointers) |
| `$0801` | BASIC stub, `10 SYS 2064` |
| `$0810` | the code, data tables and music (ends around `$0e50`) |
| `$2000`-`$20ff` | the four sprite shapes (blocks 128-131) |
| `$2800`-`$2fff` | RAM character set: ROM letters and digits plus the star shapes |
| `$c000`-`$c003` | high score and its signature byte |

### Zero page

| Address | Name | Use |
|---------|------|-----|
| `$02` | `joy` | working copy of the joystick byte |
| `$03` | `hit_timer` | frames left of the red border flash |
| `$04`-`$06` | `score` | hundreds, tens, ones |
| `$07` | `enemy_speed` | pixels per frame the enemy falls |
| `$08` | `dodge_count` | dodges since the last speed-up |
| `$09` | `frame_count` | frame counter, slows the homing, drives the sprite animation |
| `$0a` | `music_timer` | ticks left until the next step of the tune |
| `$0b` | `music_step` | which of the 64 steps (16th notes) plays next |
| `$1e` | `rnd` | random number generator state (never 0) |
| `$1f` | `drum_idx` | tick of the playing drum (1 to `DRUM_LEN`), 0 = no drum playing |
| `$20` | `drum_base` | where the playing drum starts in the drum tables |
| `$1d` | `sfx_timer` | frames left in which a sound effect owns voice 3 (the drums wait) |
| `$21` | `dodge_flash` | frames left of the glow after a dodge |
| `$29`-`$2d`, `$2f` | `plasma_ph1`-`plasma_ph3`, `plasma_row`, `plasma_rowv`, `plasma_cnt` | the plasma: phases, next row, the vertical wave value, row counter for `plasma_init` |
| `$22`-`$24` | `band1`-`band3` | `$d016` value of each parallax band |
| `$25` | `exp_timer` | frames left of the explosion (0 = none) |
| `$26`-`$28` | `shake_x`, `shake_y`, `fx_tmp` | this frame's shake and a scratch byte |
| `$0c` | `key_count` | title screen: frames in a row with a key down (needs `KEY_FRAMES`) |
| `$0e` | `lives` | lives left, 0 = game over |
| `$0f` | `title_mode` | 0 = title screen, 1 = game over screen |
| `$0d` | `clean_count` | title screen: frames since it appeared, counts up to `RELEASE_FRAMES`, then `RELEASE_FRAMES` + 1 once a frame with no key was seen |
| `$fb`-`$fe` | `star_ptr`, `star_cptr` | pointers to a star's screen and colour RAM cell |
| `$fd`-`$fe` | `xlo`, `xhi` | scratch for building the enemy's 9-bit spawn X (shares the bytes of `star_cptr`, never used at the same time) |

### Starfield

12 stars scroll down behind everything, in three speeds (1, 2, 3 pixels per frame) and three greys, so the slow dark ones look far away. The ROM letters and digits (screen codes 0-63) are copied to RAM at `$2800` and `$d018` points the VIC at that copy. Screen codes 64-71 are 8 star shapes, each a dot in a different pixel row. A star moves down by switching to the next shape, and by one character row when it passes the bottom of its cell. Stars never touch row 0, which holds the score. Random columns come from `random_column`: a random byte mixed with the frame counter and reduced to 0-39 by subtracting 40 repeatedly. Re-reading the SID noise register a few cycles after a rejected value (the old source) gave strongly related values, which bunched all the stars into the left quarter of the screen. `setup_charset`, `setup_stars` and `update_stars` do the work.

### Sound

- Voice 1: only the bass, a sawtooth: the root of the current chord (`bass_lo`, `bass_hi`) on steps 0 and 8 of each chord, started by `bass_start`. Nothing else uses this voice, so the bass and the arpeggio never drop out.
- Voice 2: the music, a 32 note A minor, F, C, G arpeggio on a plucked pulse wave (decay 6, short). Every frame `update_music` also moves the pulse width (a sine, 4 to 11) and the filter cutoff (`$d416`, a slow sine from 24 to 87, one turn per 256 frames) with a resonant low-pass filter on this voice only, which gives the synth sound. `update_music` plays a new note every `MUSIC_FRAMES` frames from the `music_lo` and `music_hi` tables (PAL SID frequency values).
- Double speed: the tune runs at 100 Hz. `music_tick` is called twice per frame (game: inside `game_bars`, at raster line 54 and line 210; title: inside `raster_show`, at line 54 and after the bars), `update_music` once (synth sweeps, `sfx_timer`). A step is `MUSIC_TICKS` (7) ticks, a 16th note; the arpeggio plays on even steps, the bass on steps 0 and 8 of a chord, drums on any step (`drum_pat`, 16 per bar).
- Hard restart: one tick before a note the voice gets gate off and AD/SR 0, so the envelope is empty when the note starts (avoids the SID ADSR bug). Voice 2 does it for every note, the bass for its notes (unless an effect owns voice 1), the drum voice before each drum (this also stops the old drum's table).
- Voice 3: the drums, and the sound effects (a short triangle blip for every scored point, from `score_point` in `score.asm` (it adds the point, checks the high score and calls `sfx_blip` in `music.asm`, for the enemy and for the Glitch alike), a noise explosion on a hit, `sfx_explosion` in `music.asm`, called from the hit code in `main.asm`; and the two rising bell notes "ting ting" when a chapter screen opens, `sfx_ting` in `music.asm`, called by `chapter_screen` on frame 0 and frame `CHAP_TING_GAP`). An effect sets `sfx_timer` (`$1d`, `SFX_BLIP` or `SFX_FRAMES` frames) and stops the drum table; until it runs out no new drum starts, so the effect is never cut short. Only a few drum hits are lost, the melody stays. Voice 3 is table driven for the drums. `drum_pat` gives one drum per step (0 none, 1 kick, 2 snare, 3 hat): kick on 0, 8, 10, hat on 6 and 14 (no snare: the user did not like it; its table is there). Each drum has `DRUM_LEN` (14) entries per table, one per tick: `drum_fhi`/`drum_flo` the pitch and `drum_ctrl` a new waveform with gate on (0 = keep). `drum_ad` is the envelope. Noise must never be combined with another waveform (it locks and goes silent). The kick: 2 ticks of noise click at 1.4 kHz, then a triangle falling from 366 Hz to 60 Hz in 5 ticks (the shape came from the user, now at 100 Hz resolution). The hat is high noise rising a little, the snare noise that gets darker.

### Joystick and the keyboard

Joystick port 2 is read from `$dc00`, the same CIA chip pins the keyboard matrix uses. When the joystick is mapped to keys in an emulator (arrow keys also count as C64 cursor keys), a held key combination can pull those pins low and show up as a phantom button: in VICE, arrow Up+Left read as fire as well. At startup the game sets both CIA 1 ports to inputs with their latches high (`$dc00`-`$dc03`), which stops that. `SHOW_JOY = 1` in `src/config.asm` prints the five raw bits (up, down, left, right, fire; 0 = pressed) on the top row for testing.

### Demo effects

The title and game over screens share the code in `src/demo.asm`, only the colours and texts differ (`pal_base`, `col_base`, `txt_ptr`, `scr_ptr`).

- **Raster bars.** `raster_show` waits for line `BAR_TOP`, then for every raster line up to `BAR_END` it writes one colour to the background and border (`$d021`, `$d020`). The colour comes from `barcol`, 256 bytes at `$c100` that `make_bars` fills once from the sine table and the bar palette. The sine step goes up by 4 per line, so a bar repeats every 64 lines, and `bar_phase` moves them. The writes sit right at the start of each line so the edges stay fairly straight. They are not cycle exact, so you may see small steps at the left edge. This works because the game does not use interrupts: the title polls the beam itself.
- **Scroller.** Row 22 is redrawn every frame from the text (`scr_ptr`, ends with `$ff`). `raster_show` sets the fine scroll (`$d016` bits 0-2) on a raster line just above that row and back to 0 just below it, so only that row slides. `scr_fine` counts down by 2 pixels per frame, and every 8 pixels `scr_idx` moves one letter.
- **Bouncing letters.** `draw_bounce` puts each of the 13 letters on one of 4 rows (6 to 9), picked from the sine table, 16 steps apart per letter and moving 3 steps per frame. The game over text is padded to 13 letters, so both screens use the same code.

The frame sync is now `raster_show` itself. The rest of the frame (stars, music, text, key check) runs after the bars and must be done before line `BAR_TOP` of the next frame.

### Game over

A hit does `dec lives`. When it reaches 0, `game_over` (in `src/title.asm`) runs the same wait-for-a-key loop as the title with `title_mode` = 1, so `draw_over` draws a red "game over" and a flashing "push any key to restart". It ignores keys for `OVER_WAIT` frames only (the player was just using the joystick). Then the score, lives, speed and ship position reset. The score and speed are not reset by a single hit, only by a new game. The high score is untouched.

### High score

The high score is three digit bytes at `$c000`-`$c002`, with a signature byte `$a5` at `$c003`. `$c000` is free RAM outside the program and the zero page, so nothing clears it: it survives hits, a restart with `RUN` and a reload of the program. Power-off wipes it. At startup `init_hiscore` checks the signature: if it is missing the high score is set to 000 and signed, otherwise the old value is kept. `update_hiscore` runs after every dodge and copies the score over when it is higher. It is drawn at the top right (`hi 000`).

### Tuning

These constants in `src/config.asm` change the difficulty without touching the logic:

- `ENEMY_SPEED`: starting fall speed in pixels per frame.
- `MAX_SPEED`: the fastest the enemy gets.
- `DODGES_PER_LEVEL`: dodges needed per speed-up.
- `LIVES`: lives per game. `OVER_WAIT`: frames the game over screen ignores keys.
- `HIT_FRAMES`: how long the border flashes after a hit.
- `MUSIC_TICKS`: ticks per step of the tune (a tick is 10 ms), higher is slower.
- `STARS`: number of stars (the speed and colour tables repeat every 3).
- Homing rate: the `and #%00000001` before the homing code, in `src/main.asm`. Use `#%00000011` for slower homing.

## Notes on ACME

- `.local` labels belong to a `!zone`, not to the nearest normal label. Give each subroutine its own `!zone` if they share a local label name such as `.done`.
- `+` and `-` are anonymous labels: a branch to `+` goes to the next `+` below, a branch to `-` to the previous `-` above.
- `!scr "text"` converts to C64 screen codes. Lowercase in the source shows as capitals on screen in the default character set.
- `!source "src/file.asm"` pastes another file in at that spot, so a program can be split over several files and still assemble into one `.prg`. ACME looks for the path from the folder you run it in, and VS64 passes the project folder with `-I`.
- `!for k, 0, 7 { ... }` repeats a block at assembly time, which is how the 8 star shapes are written.
- VS64 passes `-DDEBUG=1` to ACME for its debug build, so never name your own symbol `DEBUG`: the build fails with "Symbol already defined". Test that build with `acme -DDEBUG=1 -f cbm --cpu 6510 -o /dev/null src/main.asm`.

## Ideas for later

- Save the high score to disk now that there is a title screen.
- More enemies at once (sprites 2-7 are free).
- A title tune.


### Game effects (src/effects.asm, game_bars in src/demo.asm)

- **Plasma behind the playfield.** A real 2D text mode plasma in dark blue, in the 24 rows under the score, drawn in extended colour mode (ECM, bit 6 of `$d011`): every cell has its own background colour, picked by bits 6 and 7 of its screen code from `$d021` (black) and `$d022` (the plasma colour, `VIC_BG1`). That is also why stars can sit on the plasma without a black box around them: a star gets the background bits of the cell it is in. ECM only has 64 characters, so the star shapes live at screen codes 33 to 40 (`STAR_CHAR`) and the two dither patterns at 41 (sparse) and 42 (checkerboard); the title screens do not use those codes. The value of a cell is the sum of three sine waves, as in the classic plasma: a horizontal one per column (`PLASMA_COLX`, once per frame in `plasma_prep`), a vertical one per row (`plasma_rowv`, once per row) and a diagonal one (`dtab`, period 32, read at x + row + phase). The sum (0 to 189) picks a screen code from `plasma_code` (black, sparse dots, checkerboard, or the plasma colour as background) and a colour for the dots from `plasma_ramp`; below 110 it is black, so only the peaks show. The inner loop of `plasma_step` patches its own addresses (self-modifying code) per row. `game_bars` colours 4 rows per frame between the music ticks and scroll bands, so the whole plasma is renewed every 6 frames. A star remembers the code and colour that were in its cell (`star_ucode`, `star_ucol`) and puts them back when it moves on; `plasma_step` redraws the stars of its row. A star inside a dithered cell gets a plain cell (one background colour per cell). `plasma_init` colours all rows at once after the title and game over screens and switches ECM on; `reset_scroll` switches it off for those screens. Moods: nebula, fire during an explosion, a glow just after a dodge (`ramp_lo`/`ramp_hi`, `mood_bg1`). To make it dimmer, raise the 110, 125, 140, 160 thresholds in `plasma_code` and `plasma_ramp` (`data.asm`).
- **Explosion.** On a hit `start_explosion` launches 5 sprites (2 to 6, a round dot at `$2100`) from the ship in a star shape. `update_particles` moves them (9-bit X in `PART_LO`/`PART_HI` at `$c600`, switches a sprite off when it leaves the screen) and cycles white, yellow, orange, red. For `EXP_FRAMES` (28) frames the screen shakes: `update_bands` writes a random vertical scroll to `$d011` (below the playfield, where the VIC does not mind) and adds a random horizontal shake to the bands, with `shake_mask` making it smaller as the explosion ages. While `exp_timer` runs no new hit counts (the particles also set the sprite collision bits), a short grace period.
- **The Glitch (chapter 1 and later).** A second falling enemy on sprite 7: a green microchip in two hi-res frames (`glitch_data`/`glitch_data_b`, pointers 133/134, flickering every 8 frames). It appears when chapter 1 begins: `main.asm` calls `start_glitch` right after `chapter_screen` (the chapter screen switches all sprites off and back on, so it must come after). `start_glitch` sets `glitch_active` (`$33`), spawns it at a random X with `spawn_glitch` (which uses `pick_x`, shared with `spawn_enemy`) and sets bit 7 of `$d015`. `move_glitch` runs every frame: it falls slowly (`GLITCH_SLOW`) for `GLITCH_WAIT` frames (`glitch_timer`, `$34`), then fast (`GLITCH_FAST`), and gives +1 point when it reaches the bottom. A hit by the ship (`$d01e` `%10000001`) costs a life like the enemy does, and afterwards both respawn at the top. `reset_difficulty` clears `glitch_active`, so a new game starts without it. The explosion only uses sprites 2 to 6 so that sprite 7 stays the Glitch, and `update_particles` and `chapter_screen` keep bit 7 of `$d015` on while it is active.
- **Parallax bands.** The playfield is split in three bands (rows 1 to 6, 7 to 14, 15 to 24; the score row never moves). Each band has its own horizontal fine scroll (`$d016`, `band1` to `band3`, set at lines `BAND1_LINE` to `BAND3_LINE` by `game_bars`), 0 to 2, 0 to 4 and 0 to 7 pixels, from the ship X (`par_far`, `par_mid`, `par_near`): the stars lean the other way when you fly, the near ones most.
