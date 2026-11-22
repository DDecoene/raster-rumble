# src/sound: the music player and the sound data

These files come from [WebSidTracker](https://github.com/DDecoene/WebSidTracker) and are used as they are:

| File | What |
|---|---|
| `music.asm` | the WebSidTracker player, release 0.2.0 (copied from its `src/music.asm`) |
| `instruments.asm`, `sfx.asm`, `song_raster_rumble.asm` | exported by the tracker from [`music/raster-rumble.json`](../../music/raster-rumble.json) |

**Licence.** Unlike the rest of raster-rumble (CC BY-NC-SA 4.0, see the root `LICENSE`), these files are under the MIT licence in [`LICENSE`](LICENSE) in this folder. The line "see ../LICENSE" at the top of `music.asm` refers to the WebSidTracker repository; here it is this folder's `LICENSE`.

**Changing the music or the effects.** Open `music/raster-rumble.json` in the tracker (Open), change it, Save the project back to `music/raster-rumble.json`, then Export and put `instruments.asm`, `sfx.asm` and `song_raster_rumble.asm` in this folder. `make` builds the game with them. The game uses the effects by their constants (`SFX_DODGE`, `SFX_CHAPTER`, `SFX_HIT`, `SFX_HIT_BODY`) and the kick instrument by its number (`SND_KICK` in `src/config.asm`): keep those names and that number, or change the game with them.
