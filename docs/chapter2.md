# Chapter 2: the second enemy

Notes from the brainstorm. Goal: you write the code, Claude explains and reviews.

## What we want

- On the **tenth dodged enemy** a special "ting ting" sounds instead of the normal dodge sound.
- From then on a **second enemy type** appears with a **different model**.
- Type 2 first falls **slowly**, then after a **fixed time** it suddenly speeds up. The moment is the same every time and there is **no warning**.
- Type 1 stays as it is now. Hits, lives and game over stay as they are too.
- Later (idea): more enemies per life, for example 2x type 1 and 1x type 2, then 2 of each.

## How it works now

| Part | Where |
|---|---|
| Counting dodges and speeding up every 10 dodges | `count_dodge` in `src/actors.asm`, called from `main.asm` |
| Dodge sound (SID voice 3) | `main.asm`, in the block that runs when the enemy reaches the bottom |
| Spawning with 9-bit X | `spawn_enemy` in `src/actors.asm` |
| Collision | `SPR_COLL` ($d01e), only bits 0 and 1 are tested |
| Explosion particles | `src/effects.asm`, they use sprites 2 to 6 |
| Settings | `src/config.asm` (`DODGES_PER_LEVEL`, `ENEMY_SPEED`, `MAX_SPEED`) |

Note: the enemy already gets faster every 10 dodges. Decide whether the new enemy appears **once** (at the first ten, recommended) or at **every ten**.

## The sprite problem

The C64 has 8 hardware sprites: 0 is the ship, 1 the enemy, 2 to 7 are currently for the explosion. A new enemy therefore needs a sprite (for example sprite 7) and the explosion has to be adjusted.

- The **shape** (64 bytes) can be shared by several sprites: the pointers `$07f8-$07ff` may all point to the same block.
- A **hardware sprite** has only one X, Y and colour. More copies on screen is only possible with **sprite multiplexing** (a raster interrupt that changes Y halfway down the screen). That only works well if the copies sit in different height bands. An idea for chapter 3.

## Step plan for one extra enemy

1. Variable `enemy2_active` (0/1) in `config.asm`, set to 0 in `reset_difficulty`.
2. Draw a second shape in `sprites.asm` (a new block of 64 bytes), pointer in `$07ff`.
3. On the tenth dodge (in `count_dodge`): activate it, set the bit in `SPR_ENABLE` ($d015), spawn it.
4. Movement with a phase timer: `e2_timer` counts up; below the threshold it falls 1 pixel per frame, above it 5.
5. At the bottom (`MAX_Y`) spawn again and reset the timer.
6. Collision: test `SPR_COLL` on bit 0 and the bit of the new sprite.
7. "Ting ting": two notes shortly after each other on voice 3, with a small counter for the second note.

Points to watch: the 9th X bit lives in `$d010` (`SPR_XHI`), one bit per sprite. On game over everything has to be reset.

## For later: multiple enemies (data driven)

Turn the separate enemy variables into **tables** with the enemy number as index X: type, X low, X high, Y, timer, active. One loop does the work for all enemies. Sprite n sits at `$d000 + 2n` (X and Y), the bit for the 9th X bit is in `bit_tab` (`data.asm`). Behaviour per type through `cmp type` or a jump table.

**Sprite budget**

- Ship + 2 + 2 enemies = 5 sprites, so 3 left for the explosion.
- Ship + 3 + 3 = 7 sprites, so nothing left for the explosion.

Options: the explosion reuses the sprites of enemies that are gone, the explosion gets smaller, or multiplexing.

**Recommended order:** first refactor to a table with one row (everything still works the same), then row 2, then type 2. Every step is testable.

## Open questions

- Maximum number of enemies in chapter 2?
- New enemy once or at every tenth dodge?
- Which sprites does the explosion use exactly? (look in `effects.asm`)
