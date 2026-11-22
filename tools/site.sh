#!/bin/sh
# Build the web site (the landing page and the play page) into build/site, for GitHub Pages.
# Usage: tools/site.sh [address of the site]   (default https://ddecoene.github.io/raster-rumble)
#
# The pages in site/ contain @VERSION@, which becomes the version from src/version.asm, and @SITE@, which becomes
# the address of the site. The game goes into the site as raster-rumble-vX.Y.Z.prg: a new name for every release,
# because the vc64web emulator keeps every file it ever loaded and would otherwise keep playing an old build.
# The screenshots come from docs/screenshots, so they live in one place only.
set -e
site_url=${1:-https://ddecoene.github.io/raster-rumble}
version=$(tools/version.sh)
if [ -z "$version" ]; then echo "no version found in src/version.asm" >&2; exit 1; fi
if [ ! -f build/raster-rumble.prg ]; then echo "build/raster-rumble.prg is missing, run make first" >&2; exit 1; fi

rm -rf build/site
mkdir -p build/site/img
cp -R site/. build/site/
for page in $(find build/site -name '*.html'); do
  sed -e "s|@VERSION@|$version|g" -e "s|@SITE@|$site_url|g" "$page" > "$page.tmp"
  mv "$page.tmp" "$page"
done
cp docs/screenshots/gameplay.gif docs/screenshots/title.png docs/screenshots/chapter.png \
   docs/screenshots/glitch.png docs/screenshots/border.png docs/screenshots/social-preview.png build/site/img/
cp build/raster-rumble.prg "build/site/raster-rumble-v$version.prg"
# GitHub Pages: serve the files as they are (no Jekyll)
touch build/site/.nojekyll
echo "site for v$version in build/site ($site_url)"
