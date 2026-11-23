# Concept: the game as an interactive film

> Notes from a brainstorm on 2026-11-23, **not finished**. Nothing here is built, and `docs/story.md` still holds the story as it is in the game now.

## What we want

- Raster Rumble is a mix of loose ideas now. Make it one whole: beautiful and clear. The game screen is quite nice but can be better; the title screen (moving bars, plain letters) has to change.
- An **interactive film** with a dynamic background that supports the story. Not a literal C64 (a `READY.` screen, a hex dump): that is too realistic.
- The tone of the films of the eighties: Flight of the Navigator, Electric Dreams, Back to the Future, but more of a thriller, with a bit of Alien, The Shining and The Thing.
- It is the **nightmare of a small child**, but the child lives it as an **adventure**: scared at times, and pushing through. A coming of age story.
- An intro that explains the story and the clock: *It is 23:00. The computer is still on. Hold on until morning.* ("Stay alive" was too harsh.)
- Dodging cannot be the whole game.

## Ideas, not decided

- **07:00 is waking up**, the rescue. (In `docs/story.md` it is the moment the plug is pulled.)
- Pixel is the child in the dream: a warm light in a cold, dark world, and it grows stronger through the night. A palette per hour, towards dawn. Our own font.
- A shadow comes closer every chapter; the Raster Beam is its true form.
- The arc:

| Time | Feeling | On screen |
|---|---|---|
| 23:00 | wonder | a glowing, slow dream world |
| 01:00 | something is off | short faults in the picture |
| 03:00 | fear | the edges close in, colours fall away |
| 04:30 | alone | almost black, only Pixel gives light |
| 06:00 | courage | the shadow shows itself, and Pixel stays |
| 07:00 | awake | morning light, the alarm clock |

- Film means: letterbox bars, light and flicker that follow the danger, a shaking screen, title cards with the clock, music that follows the tension. Fire skips the intro; the chapter screens explain the clock again.
- Nobody dies: `LIVES` becomes `COURAGE`, `GAME OVER` becomes `THE NIGHT STARTS OVER`.
- **The light:** fire gives a pulse of light that drives back what is near. Near misses charge it: who dares to come close gets stronger. (Other ideas: shooting, or collecting lights.)

## Open questions

1. Is the light the right new way to play?
2. Is 07:00 waking up?

## Order, if we do it

Each part is a playable version of its own.

1. **The film:** intro, title screen, font, colours and background for the three chapters that exist. This one is designed first.
2. **The light.**
3. **The rest of the night:** 04:30, 06:00 and 07:00.

There are only 25 bytes left below the sprites at `$2000`, so part 1 starts with making room.
