NAME   = raster-rumble
SRC    = src/main.asm
OUT    = build/$(NAME).prg

.PHONY: all clean emu serve test

all: $(OUT)

$(OUT): $(wildcard src/*.asm)
	@mkdir -p build
	acme -f cbm --cpu 6510 -l build/$(NAME).lbl -r build/$(NAME).rpt -o $@ $(SRC)

# the vc64web browser emulator, fetched once into tools/vc64web (about 26 MB, not part of the repo)
tools/vc64web:
	git clone --depth 1 https://github.com/vc64web/vc64web.github.io $@

emu: tools/vc64web

# serve the emulator and the build on http://127.0.0.1:8000 (stop with Ctrl-C)
serve: $(OUT) tools/vc64web
	python3 tools/serve.py 8000

# build, start the server if it is not running yet, open the game in the browser emulator
test: $(OUT) tools/vc64web
	@curl -s -o /dev/null http://127.0.0.1:8000/ || (python3 tools/serve.py 8000 > /dev/null 2>&1 &)
	@sleep 1
	open "http://127.0.0.1:8000/#openROMS=true#port2=true"

clean:
	rm -rf build
