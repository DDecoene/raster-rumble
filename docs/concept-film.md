# Concept: the game as an interactive film

> Notes from the brainstorm of 2026-11-23. The script that came out of it is in `docs/story.md` (first draft); where the two differ, the script counts.

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

## Decided later on 2026-11-23

- **What changes in the child:** by morning he feels he knows the C64 inside out, every nook and cranny of the VIC, CIA, SID and memory, and that he can make the best games and demos.
- **A power per chip:** every chapter teaches the fire button a power that belongs to its chip. This replaces the single light above.
- **The ending:** 07:00 is waking up. He sits down at the computer and starts to type.
- **The order:** the intro first, the game itself stays as it is. When the intro is good, chapter by chapter.
- **The branch:** all of this is made on `the-night`. A release is a finished whole.

## Proposed, not confirmed

- The night is a journey through the machine; every chip is a dream place, never a literal C64 screen.
- The shadow is what he does not understand yet. The Raster Beam is not beaten; he learns to steer it.
- This game could be the first game he makes.
- Pixel is the child in the dream.
- The Border joins the VIC at 06:00; its diagonal enemies stay at 03:00, which becomes the SID chapter.

| Time | Place | What he learns |
|---|---|---|
| 23:00 | the screen | moving |
| 01:00 | CIA, the clocks | slowing time |
| 03:00 | SID, sound | a sound wave that pushes things away |
| 04:30 | memory | remembering: using an old power again |
| 06:00 | VIC, the Raster Beam | steering the beam |
| 07:00 | the room | making something himself |

## Open questions

1. What is in the intro?
2. Which chapters make the first release a finished whole?

There are only 25 bytes left below the sprites at `$2000`, so the intro starts with making room.
