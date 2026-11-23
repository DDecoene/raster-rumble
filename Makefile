NAME   = raster-rumble
SRC    = src/main.asm
OUT    = build/$(NAME).prg
D64    = build/$(NAME).d64
# the version, read from src/version.asm (that file is the one place it lives)
VERSION = $(shell tools/version.sh)

.PHONY: all intro intro-art sound screenshots release clean emu serve test stop version d64 dist vice site site-serve

all: $(OUT)

# src/sound/ too: after a new export from the tracker, make (and make vice) must build again
$(OUT): $(wildcard src/*.asm) $(wildcard src/sound/*.asm)
	@mkdir -p build
	acme -f cbm --cpu 6510 -l build/$(NAME).lbl -r build/$(NAME).rpt -o $@ $(SRC)

# print the version
version:
	@echo $(VERSION)

# a disk image with the game on it (needs c1541, it comes with VICE: brew install vice)
$(D64): $(OUT)
	c1541 -format "raster rumble,rr" d64 $@ -write $(OUT) "raster rumble"

d64: $(D64)

# the files of a release, with the version in their names, in build/dist
dist: $(OUT) $(D64)
	@mkdir -p build/dist
	cp $(OUT) build/dist/$(NAME)-v$(VERSION).prg
	cp $(D64) build/dist/$(NAME)-v$(VERSION).d64

# the web site (landing page and play page) in build/site, for GitHub Pages (see docs/design-landing-page.md)
site: $(OUT)
	tools/site.sh

# build the site for http://127.0.0.1:8001 and serve it there, to look at it before a release (stop with Ctrl-C)
site-serve: $(OUT)
	tools/site.sh http://127.0.0.1:8001
	python3 tools/site-serve.py 8001

# the vc64web browser emulator, fetched once into tools/vc64web (about 26 MB, not part of the repo)
tools/vc64web:
	git clone --depth 1 https://github.com/vc64web/vc64web.github.io $@

emu: tools/vc64web

# serve the emulator and the build on http://127.0.0.1:8000 (stop with Ctrl-C)
serve: $(OUT) tools/vc64web
	python3 tools/serve.py 8000

# build, (re)start the server so it always runs the current tools/serve.py, open the game in the browser emulator
test: $(OUT) tools/vc64web
	@pkill -f tools/serve.py || true
	@(nohup python3 tools/serve.py 8000 > /dev/null 2>&1 &)
	@for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do curl -s -o /dev/null http://127.0.0.1:8000/ && break; sleep 0.5; done; curl -s -o /dev/null http://127.0.0.1:8000/ || (echo "the server did not start"; exit 1)
	open "http://127.0.0.1:8000/#openROMS=true"

# stop the server that make test left running in the background
stop:
	@pkill -f tools/serve.py && echo "server stopped" || echo "no server running"

clean:
	rm -rf build

# build and run in VICE (x64sc, the accurate emulator: use it to judge the sound; brew install vice).
# tools/vice-joystick.rc puts joystick port 2 on the arrow keys and Space (VICE's default is the numeric keypad).
# -sidenginemodel 256 is reSID with the MOS 6581, the chip the music is composed for (whatever VICE's own setting is).
vice: $(OUT)
	x64sc -addconfig tools/vice-joystick.rc -sidenginemodel 256 -autostart $(OUT)

# export the tracker project in music/ to src/sound (WST is the folder of WebSidTracker; needs node)
WST ?= ../WebSidTracker
sound:
	node tools/sound.mjs "$(WST)"

# the title screenshot and the social preview, made with VICE. Only needed when the picture changes
screenshots: $(OUT)
	tools/screenshots.sh

# the whole release: make release M="what is new" (V=0.0.9 for another version, DRY=1 for only the checks)
release: export M := $(value M)
release: export V := $(V)
release: export DRY := $(DRY)
release:
	@tools/release.sh

# the intro of the film, a program of its own for now: build it and show it in VICE
build/intro.prg: src/intro/intro.asm $(wildcard src/intro/*.bin) src/hardware.asm
	@mkdir -p build
	acme -f cbm --cpu 6510 -l build/intro.lbl -o $@ src/intro/intro.asm

intro: build/intro.prg
	x64sc -addconfig tools/vice-joystick.rc -sidenginemodel 256 -autostartprgmode 1 -autostart build/intro.prg

# draw the picture of the intro again (only after a change in tools/intro-room.py)
intro-art:
	@mkdir -p build
	@[ -x build/venv/bin/python ] || python3 -m venv build/venv
	@build/venv/bin/python -c 'import PIL, numpy' 2>/dev/null || build/venv/bin/pip -q --disable-pip-version-check install pillow numpy
	build/venv/bin/python tools/intro-room.py
