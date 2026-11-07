# sandbox

My own C64 experiments in 6502 assembly. Branched from raster-rumble, stripped down to the tooling.

- `src/main.asm`: the program (starts empty)
- `src/hardware.asm`: names for the chip registers (include it with `!source "src/hardware.asm"` when you need it)
- `make` builds `build/sandbox.prg`, `make test` runs it in the browser emulator

## Finished experiments (they stay in the git history)

- SUBLEQ virtual machine: commit `58491a4`
- Conway's Game of Life: [run it in your browser](https://vc64web.github.io/#openROMS=true#https://raw.githubusercontent.com/DDecoene/raster-rumble/ee0f13b/life.prg), source at commit `67a46b1`

## References

- [6502 instruction set](https://www.masswerk.at/6502/6502_instruction_set.html) (mass:werk): the opcode matrix, flags and cycle counts per instruction and addressing mode, a primer on ADC/SBC, the undocumented opcodes and the 6510 pinout. Handy for counting cycles by hand.
