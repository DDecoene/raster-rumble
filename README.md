# raster-rumble

A Commodore 64 game written in 6502 assembly. Built for fun, nostalgia and, one day, real hardware.

You fly a ship along the bottom of the screen and dodge a falling enemy. Every dodge scores a point. The enemy gets faster as your score climbs and drifts toward you while it falls. A hit flashes the border, plays an explosion and resets your score.

## Tools

    brew install acme vice

- **ACME** is the assembler (no Java needed).
- **VICE** (`x64sc`) is the emulator.
- Editor: VS Code with the VS64 extension (`code --install-extension rosc.vs64`). It builds with ACME and debugs in VICE: press F5. VS64 only supports ACME and Kick Assembler, which is why this project uses ACME.

## Build and run

    make        # assembles build/raster-rumble.prg
    make run    # launches it in VICE (x64sc)
    make clean

Controls: joystick in port 2. In VICE, map a keyset or gamepad under Settings > Input > Joystick.

To run on a real C64, copy `build/raster-rumble.prg` to an SD card for a Kung Fu Flash, Ultimate 64 or similar.

## Project layout

    src/main.asm          the whole game, every line commented
    project-config.json   VS64 project settings (toolkit: acme)
    .vscode/              build task, launch config, VICE path
    Makefile              command-line build

## How it works

- The program loads at `$0801` with a BASIC stub (`10 SYS 2064`), and the code starts at `$0810`. A build-time check fails if `start` moves off 2064.
- Sprite 0 is the ship (shape at `$2000`, pointer 128). Sprite 1 is the enemy (shape at `$2040`, pointer 129).
- The main loop waits for raster line `$fb` once per frame, then reads the joystick, moves the enemy, checks the hardware sprite collision register (`$d01e`) and updates the score.
- Random enemy positions come from SID voice 3 set to noise (`$d41b`). It is muted so it stays silent.
- The explosion is a noise burst on SID voice 1, retriggered by switching its gate off and on.
- The score is three separate digit bytes (hundreds, tens, ones) in zero page `$04`-`$06`, printed by adding `$30` to each digit.

### Zero page

| Address | Name | Use |
|---------|------|-----|
| `$02` | `joy` | working copy of the joystick byte |
| `$03` | `hit_timer` | frames left of the red border flash |
| `$04`-`$06` | `score` | hundreds, tens, ones |
| `$07` | `enemy_speed` | pixels per frame the enemy falls |
| `$08` | `dodge_count` | dodges since the last speed-up |
| `$09` | `frame_count` | frame counter, slows the homing |

### Tuning

These constants at the top of `src/main.asm` change the difficulty without touching the logic:

- `ENEMY_SPEED`: starting fall speed in pixels per frame.
- `MAX_SPEED`: the fastest the enemy gets.
- `DODGES_PER_LEVEL`: dodges needed per speed-up.
- `HIT_FRAMES`: how long the border flashes after a hit.
- Homing rate: the `and #%00000001` before the homing code. Use `#%00000011` for slower homing.

## Notes on ACME

- `.local` labels belong to a `!zone`, not to the nearest normal label. Give each subroutine its own `!zone` if they share a local label name such as `.done`.
- `+` and `-` are anonymous labels: a branch to `+` goes to the next `+` below, a branch to `-` to the previous `-` above.
- `!scr "text"` converts to C64 screen codes. Lowercase in the source shows as capitals on screen in the default character set.

## Ideas for later

- High score: in RAM first, then saved to disk once there is a game-over or title screen.
- Title screen and game-over state.
- More enemies at once (sprites 2-7 are free).
- Music and more sound effects.
- Move horizontally past 255 using the X high bit in `$d010`.
