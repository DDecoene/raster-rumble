# Landing page and a play link that is always the newest version

## Why

The "Play it now" link (vc64web with the `.prg` on raw.githubusercontent.com) shows an old version to anyone who opened it before. vc64web's service worker keeps every file it fetched in the browser and never asks again ("cache first"). We cannot change that, so the address of the game file has to change with every release, while the link we share stays the same.

At the same time the game gets a home page for people who do not know it yet: random retro computing nerds. In a few seconds they should see that it is a real C64 game in assembly, and play it with one click. Below that come the story and the nerdy details.

## Goals

- One fixed address for people who know the game: `https://ddecoene.github.io/raster-rumble/play/`. It always starts the newest release in vc64web. "Start it again, X changed" never needs a new link.
- A landing page at `https://ddecoene.github.io/raster-rumble/`: play button, gameplay, story, how it is made, downloads.
- Nothing to do by hand at a release: the version comes from `src/version.asm`, as everywhere else.

Not goals: our own copy of the emulator, a blog or news page, analytics or cookies.

Anti-goals: a page that shows another version than the one it plays; a version number that has to be typed in a second place.

## Approaches

- **A. Build the site in the release workflow and publish it with GitHub Pages (chosen).** The page source is in `site/`; at a release `tools/site.sh` puts the pages, the screenshots and the game as `raster-rumble-vX.Y.Z.prg` in `build/site`, with the version filled in, and the workflow publishes that folder. GitHub Pages sends `access-control-allow-origin: *`, so vc64web can load the game straight from the site.
- B. Serve Pages from the `play` branch, which the workflow already rewrites. Works too, but the page would live on a branch that is replaced by force at every release, out of sight of the history.
- C. A `docs/` folder on `main`. Every release would need a second commit with the version, which is what A avoids.

## How it works

- `site/index.html` and `site/style.css`: the landing page. `site/play/index.html`: a page that forwards to vc64web at once (with a link as fallback).
- The text `@VERSION@` in those files is replaced by the version. The game is in the site as `raster-rumble-v@VERSION@.prg`, so every release has a new address and the emulator's cache can never serve an old build.
- `make site` builds `build/site` locally; `make site-serve` serves it on http://127.0.0.1:8001 to look at.
- `.github/workflows/release.yml` gets a second job after the release: build the site, upload it, deploy it to Pages.
- The `play` branch and the old link stay as they are, so links that are already out there keep working (with the cache problem for people who opened them before).
- One-time setting: Pages with source "GitHub Actions". The site appears with the first release after this is merged.
