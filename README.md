# raster-rumble

A Commodore 64 game written in 6502 assembly. Built for fun, nostalgia and, one day, real hardware.

You fly a ship along the bottom of the screen and dodge a falling enemy. Every dodge scores a point. The enemy gets faster as your score climbs and drifts toward you while it falls. A hit flashes the border, plays an explosion and resets your score. The best score stays on screen as `hi`. Stars scroll behind the action and a looping arpeggio plays while you dodge.

## Tools

    brew install acme vice

- **ACME** is the assembler (no Java needed).
- **VICE** (`x64sc`) is the emulator.
- Editor: VS Code with the VS64 extension (`code --install-extension rosc.vs64`). It builds with ACME and debugs in VICE: press F5. VS64 only supports ACME and Kick Assembler, which is why this project uses ACME.

## Build and run

    make        # assembles build/raster-rumble.prg
    make run    # launches it in VICE (x64sc)
    make clean

Controls: joystick in port 2. In VICE, open Settings > Input > Joystick, set port 2 to a keyset (for example arrow keys and space) or a gamepad. A keyset is only a joystick once it is assigned to port 2: if the port is set to "None", the keys go to the C64 keyboard instead and the ship will not move properly.

To run on a real C64, copy `build/raster-rumble.prg` to an SD card for a Kung Fu Flash, Ultimate 64 or similar.

## Project layout

    src/main.asm          the whole game, every line commented
    project-config.json   VS64 project settings (toolkit: acme)
    .vscode/              build task, launch config, VICE path
    Makefile              command-line build

## How it works

- The program loads at `$0801` with a BASIC stub (`10 SYS 2064`), and the code starts at `$0810`. A build-time check fails if `start` moves off 2064.
- Sprite 0 is the ship, sprite 1 is the enemy. Both are multicolor (12 fat pixels per row, 2 bits each: transparent, own colour, plus orange and yellow shared by both sprites via `$d025`/`$d026`) and have two animation frames. Shapes: ship A `$2000` (pointer 128), enemy A `$2040` (129), ship B `$2080` (130), enemy B `$20c0` (131). The frame switches every 8 frames by bit 3 of `frame_count`. The shapes are drawn as ASCII art in the comments next to each row (`.` transparent, `a` orange, `b` own colour, `c` yellow).
- The main loop waits for raster line `$fb` once per frame, then picks the animation frame, scrolls the stars, plays the next music note if it is time, reads the joystick, moves the enemy, checks the hardware sprite collision register (`$d01e`) and updates the score. All of that takes about 7% of a PAL frame.
- Sprite X positions are 9 bits wide: the low 8 bits are in `$d000` (ship) and `$d002` (enemy), bit 8 is in `$d010` (bit 0 = ship, bit 1 = enemy). The visible area is X 24 to 343, so the ship moves between `MIN_X` = 24 and `MAX_X` = 320 (a 24 pixel wide sprite just fits). `ship_left`, `ship_right`, `enemy_left`, `enemy_right` and `home_enemy` do the 9-bit arithmetic: when the low byte wraps, they set or clear bit 8.
- Random numbers come from SID voice 3 set to noise (`$d41b`). It is muted so it stays silent. The enemy spawns at X = 24 + random column x 8 + 0 to 7 (`spawn_enemy`).
- The score is three separate digit bytes (hundreds, tens, ones) in zero page `$04`-`$06`, printed by adding `$30` to each digit.

### Memory map

| Address | Use |
|---------|-----|
| `$0400`-`$07e7` | screen memory (`$07f8`/`$07f9` hold the sprite pointers) |
| `$0801` | BASIC stub, `10 SYS 2064` |
| `$0810` | the code, data tables and music (ends around `$0c71`) |
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
| `$0a` | `music_timer` | frames left until the next music note |
| `$0b` | `music_step` | which of the 32 notes plays next |
| `$fb`-`$fe` | `star_ptr`, `star_cptr` | pointers to a star's screen and colour RAM cell |
| `$fd`-`$fe` | `xlo`, `xhi` | scratch for building the enemy's 9-bit spawn X (shares the bytes of `star_cptr`, never used at the same time) |

### Starfield

12 stars scroll down behind everything, in three speeds (1, 2, 3 pixels per frame) and three greys, so the slow dark ones look far away. The ROM letters and digits (screen codes 0-63) are copied to RAM at `$2800` and `$d018` points the VIC at that copy. Screen codes 64-71 are 8 star shapes, each a dot in a different pixel row. A star moves down by switching to the next shape, and by one character row when it passes the bottom of its cell. Stars never touch row 0, which holds the score. Random columns come from `random_column`: the SID noise byte mixed with the frame counter and reduced to 0-39 by subtracting 40 repeatedly. Re-reading the noise register a few cycles after a rejected value gave strongly related values, which bunched all the stars into the left quarter of the screen. `setup_charset`, `setup_stars` and `update_stars` do the work.

### Sound

- Voice 1: sound effects, a short triangle blip for each dodge and a noise explosion on a hit. Each one sets its own pitch and envelope, then retriggers the voice by switching the gate off and on.
- Voice 2: the music, a 32 note A minor, F, C, G arpeggio on a plucked square wave. `update_music` plays a new note every `MUSIC_FRAMES` frames from the `music_lo` and `music_hi` tables (PAL SID frequency values).
- Voice 3: the muted random number generator.

### Joystick and the keyboard

Joystick port 2 is read from `$dc00`, the same CIA chip pins the keyboard matrix uses. When the joystick is mapped to keys in an emulator (arrow keys also count as C64 cursor keys), a held key combination can pull those pins low and show up as a phantom button: in VICE, arrow Up+Left reads as fire as well. At startup the game sets both CIA 1 ports to inputs with their latches high (`$dc00`-`$dc03`), which stops that. `SHOW_JOY = 1` at the top of `src/main.asm` prints the five raw bits (up, down, left, right, fire; 0 = pressed) on the top row for testing.

### High score

The high score is three digit bytes at `$c000`-`$c002`, with a signature byte `$a5` at `$c003`. `$c000` is free RAM outside the program and the zero page, so nothing clears it: it survives hits, a restart with `RUN` and a reload of the program. Power-off wipes it. At startup `init_hiscore` checks the signature: if it is missing the high score is set to 000 and signed, otherwise the old value is kept. `update_hiscore` runs after every dodge and copies the score over when it is higher. It is drawn at the top right (`hi 000`).

### Tuning

These constants at the top of `src/main.asm` change the difficulty without touching the logic:

- `ENEMY_SPEED`: starting fall speed in pixels per frame.
- `MAX_SPEED`: the fastest the enemy gets.
- `DODGES_PER_LEVEL`: dodges needed per speed-up.
- `HIT_FRAMES`: how long the border flashes after a hit.
- `MUSIC_FRAMES`: frames per music note, higher is slower.
- `STARS`: number of stars (the speed and colour tables repeat every 3).
- Homing rate: the `and #%00000001` before the homing code. Use `#%00000011` for slower homing.

## Notes on ACME

- `.local` labels belong to a `!zone`, not to the nearest normal label. Give each subroutine its own `!zone` if they share a local label name such as `.done`.
- `+` and `-` are anonymous labels: a branch to `+` goes to the next `+` below, a branch to `-` to the previous `-` above.
- `!scr "text"` converts to C64 screen codes. Lowercase in the source shows as capitals on screen in the default character set.
- `!for k, 0, 7 { ... }` repeats a block at assembly time, which is how the 8 star shapes are written.
- VS64 passes `-DDEBUG=1` to ACME for its debug build, so never name your own symbol `DEBUG`: the build fails with "Symbol already defined". Test that build with `acme -DDEBUG=1 -f cbm --cpu 6510 -o /dev/null src/main.asm`.

## Ideas for later

- Save the high score to disk once there is a game-over or title screen.
- Title screen and game-over state.
- More enemies at once (sprites 2-7 are free).
- A second music voice (bass or drums) and a title tune.
