#!/bin/sh
# Make docs/screenshots/title.png and social-preview.png from the build, with VICE (make screenshots).
# Always the same settings: a 6569 (the 8565 of the C64C shows grey dots where the bars change the colour), a fixed
# palette, a fixed moment. CYCLES=... picks another moment. Pillow goes into build/venv the first time.
set -e
[ -x build/venv/bin/python ] || python3 -m venv build/venv
build/venv/bin/python -c 'import PIL' 2>/dev/null || build/venv/bin/pip -q --disable-pip-version-check install pillow
rm -f build/title.png
# VICE ends with an error code at the cycle limit, so only the picture counts
x64sc -default -VICIImodel 6569 -VICIIfilter 0 -VICIIextpal -VICIIpalette pepto-pal -warp -sounddev dummy \
  -autostartprgmode 1 -limitcycles "${CYCLES:-16160000}" -exitscreenshot build/title.png \
  -autostart build/raster-rumble.prg >/dev/null 2>&1 || true
[ -s build/title.png ] || { echo "screenshots: VICE made no picture" >&2; exit 1; }
build/venv/bin/python - <<'PY'
from PIL import Image
title = Image.open('build/title.png').convert('RGB').crop((0, 1, 384, 271)).resize((1152, 810), 0)
title.save('docs/screenshots/title.png', optimize=True)
social = Image.new('RGB', (1280, 640))
social.paste(title.resize((910, 640), 0), (185, 0))
social.save('docs/screenshots/social-preview.png', optimize=True)
PY
echo "screenshots: look at docs/screenshots/title.png and social-preview.png before you commit them"
