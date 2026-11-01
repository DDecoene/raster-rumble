NAME   = raster-rumble
SRC    = src/main.asm
OUT    = build/$(NAME).prg
D64    = build/$(NAME).d64
# the version, read from src/version.asm (that file is the one place it lives)
VERSION = $(shell tools/version.sh)

.PHONY: all clean emu serve test stop version d64 dist

all: $(OUT)

$(OUT): $(wildcard src/*.asm)
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
