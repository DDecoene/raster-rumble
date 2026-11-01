# sandbox

My own C64 experiments in 6502 assembly. Branched from raster-rumble, stripped down to the tooling.

- `src/main.asm`: the program (starts empty)
- `src/hardware.asm`: names for the chip registers (include it with `!source "src/hardware.asm"` when you need it)
- `make` builds `build/sandbox.prg`, `make test` runs it in the browser emulator
