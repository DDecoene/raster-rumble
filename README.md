# raster-rumble

A Commodore 64 game written in 6502 assembly. Built for fun, nostalgia and, one day, real hardware.

## Tools

    brew install acme vice

Editor: VS Code with the VS64 extension (`code --install-extension rosc.vs64`). It builds with ACME and debugs in VICE: press F5.

## Build and run

    make        # assembles build/raster-rumble.prg
    make run    # launches it in VICE (x64sc)
    make clean

To run on a real C64, copy `build/raster-rumble.prg` to an SD card for a Kung Fu Flash, Ultimate 64 or similar.
