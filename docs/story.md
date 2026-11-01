# The Night of the Raster Beam

The story behind Raster Rumble. Chapters are built one at a time; see "Build order" below for where we are.

## The story

It is 1986. A kid goes to bed and forgets to switch off the Commodore 64. The machine stays on and the monitor glows in the dark.

Inside it lives **Pixel**, a small ship, a sprite that has hung in the same spot for years. Tonight something happens: the **Raster Beam**, the beam of light that draws the screen from top to bottom 50 times a second, starts to stutter. If it stops, the world falls apart. Everything that lives in memory disappears, Pixel included.

Pixel has until morning. Around 07:00 someone comes into the room and pulls the plug. To still exist after that, Pixel has to write its name to the **floppy disk**, the only place that survives the power cut.

The journey goes through the machine, from the top of the screen to the deepest layers of memory. Every hour of the night is a chapter.

## The chapters

| Time | Chapter | What happens in the story | What it means in the game |
|---|---|---|---|
| 23:00 | **Boot** | Pixel notices something is wrong. The first *bugs* fall out of the screen. | What the game is now: one enemy, learning to steer. After 10 dodged enemies a "ting ting" sounds: the first real glitch. |
| 01:00 | **The Glitch** | A new kind of fault. It looks slow and harmless, until it suddenly shoots. | The second enemy from chapter 2: it falls slowly, speeds up after a fixed time, with no warning. Different model. |
| 03:00 | **The Border** | Pixel flies to the edge of the screen, where the border colours begin. The world is thin there. | Enemies come in diagonally or from the side. Border and background flicker with the fault. New colours and a different bass line. |
| 04:30 | **The Memory** | Pixel sinks through the memory banks. Old programs sleep there and wake up. | Two enemies at once. Parallax bands scroll at different speeds. The explosion reuses sprites of destroyed enemies. |
| 06:00 | **The Raster Beam** | The beam itself has become the danger. It sweeps across the screen. | Boss: a horizontal bar that sinks from top to bottom with one or two gaps. Pixel has to be in the gap. The bar fits the name of the game and our raster effects. |
| 07:00 | **The Disk** | Footsteps in the hallway. The door opens. Pixel writes its name and the screen goes black. | End screen where you enter your initials and the high score is saved to disk. The scroller tells the ending. |

## How it is told

No long texts. The story comes through things we already have or can build easily:

- **Title screen scroller**: the running text tells the setup ("It is 1986. Someone forgot the plug...").
- **Interlude screen per chapter**: black screen, the time big, one sentence that appears letter by letter. One key sentence per chapter.
- **Game over per chapter**: a different sentence depending on where you fell. For example in The Memory: "Pixel was forgotten."
- **Lives** are Pixel's memories. Losing a life is losing a memory.
- **Music and colour** change per chapter, so you can hear and see that you have moved on.

## How progress works

- Each chapter lasts a fixed number of dodged enemies (for example 25) and ends with the interlude screen.
- After game over you start again at chapter 1. The highest chapter you reached stays shown next to the score. A checkpoint rule is a later choice.
- One new thing to learn per chapter, never two at once.

## What this needs from the code

| What | Idea |
|---|---|
| Chapter counter | One byte `chapter` in `config.asm`, set to 0 in `reset_difficulty`. |
| Tables per chapter | Colours, speed, number of enemies, music part, dodges to reach: one row per chapter in `data.asm`. |
| Interlude screen | Reuse the text routines and raster effects from `title.asm` and `demo.asm`. |
| Clock | `draw_clock` in `chapter.asm` prints the time of the chapter on the top row. *(done)* |
| More enemies | The table refactor from `docs/chapter2.md`, then the sprite budget. |
| Boss | Raster interrupt for the bar; collision on a Y range instead of sprite collision. |
| Saving to disk | KERNAL SAVE/LOAD, already on the list. |

## Build order

1. **Chapter counter and interlude screen** with only what exists now. The story is visible straight away. *(done)*
2. **The Glitch** (the notes are in `docs/chapter2.md`). *(done)*
3. **The Border**: sideways drifting enemies that bounce off the edges *(done)*, the clock on the top row *(done)*, border and background flicker, new colours per chapter and a different bass line *(still to do)*.
4. **The Memory**: multiple enemies.
5. **The Raster Beam**: boss.
6. **The Disk**: ending and saving.

Every step can be played and tested on its own.

## Open points

- Do the name Pixel and the night of 1986 fit? If not, what instead?
- Six chapters, or fewer?
- On-screen text is in English, because it is a C64 game that strangers have to be able to read.
