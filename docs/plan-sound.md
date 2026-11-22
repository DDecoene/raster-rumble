# All sound through the WebSidTracker player: plan

**Goal:** raster-rumble plays its tune and effects with the WebSidTracker player and writes nothing to the SID itself.

**Spec:** [design-sound.md](design-sound.md)

## Constraints

- ACME, every line commented, English code and docs, small commits on `feature/websidtracker-sound`, no push.
- The game frame must still end before line 54 (the wait in `game_bars` is "equal", a later frame waits a whole frame).
- The player files in `src/sound/` stay exactly as WebSidTracker exports them (MIT); the game only calls them.

## Review focus

1. A frame where the music and an effect start together must not make the game miss line 54 (measure in VICE).
2. The title, game over and chapter screens keep their music without a gap when they change.
3. The kick pump fires once per kick, not on every frame of it.
4. A hit plays both effects; a dodge right after a hit replaces the rumble on voice 3 but not the thump on voice 1.
5. The game still builds with the old free zero page bytes unused, and nothing else writes `$D400`-`$D418`.

### Task 1: the tracker project and the exported files

Build `music/raster-rumble.json` from the old tables (a one-off script with the WebSidTracker model: it checks the project with `validate` and writes the files with the exporters), and put `music.asm`, `instruments.asm`, `sfx.asm`, `song_raster_rumble.asm` and `LICENSE` in `src/sound/`. Check: the project validates and lints clean; the old note tables and the new song give the same pitches and frame positions.

### Task 2: the game uses the player

Include `src/sound/*` after the code with a guard below `$2000`; `music_init` at start; `update_music` becomes `music_play` plus the kick pump; remove `music_tick` from `raster_show` and `game_bars`; the three moments call `sfx_play`; remove the old routines, tables, variables, constants and SID writes. Check: `make` builds, `git grep` finds no SID register write outside `src/sound/`.

### Task 3: measure and listen

In VICE (x64sc): the highest raster line the game frame reaches before `game_bars` (a temporary debug byte, read with the monitor), a WAV of the title and the game with the effects, and their analysis. Remove the debug byte.

### Task 4: docs

README (sound section, memory map, zero page table, how to change the music), the comments in `main.asm`, and the status of the design.
