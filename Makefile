NAME   = raster-rumble
SRC    = src/main.asm
OUT    = build/$(NAME).prg

.PHONY: all run clean

all: $(OUT)

$(OUT): $(SRC)
	@mkdir -p build
	acme -f cbm --cpu 6510 -l build/$(NAME).lbl -r build/$(NAME).rpt -o $@ $(SRC)

run: $(OUT)
	x64sc -autostart $(OUT)

clean:
	rm -rf build
