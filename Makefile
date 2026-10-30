NAME   = raster-rumble
SRC    = main.asm
OUT    = build/$(NAME).prg

.PHONY: all run clean

all: $(OUT)

$(OUT): $(SRC)
	@mkdir -p build
	64tass -C -a -B -l build/$(NAME).lbl -L build/$(NAME).lst $(SRC) -o $@

run: $(OUT)
	x64sc -autostart $(OUT)

clean:
	rm -rf build
