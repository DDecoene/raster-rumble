#!/bin/sh
# Print the version (like 0.0.1) from the !scr "vX.Y.Z" line of a version.asm file. Default: src/version.asm
# Used by the Makefile and by the workflows in .github/workflows.
sed -n 's/.*!scr "v\([0-9][0-9.]*\)".*/\1/p' "${1:-src/version.asm}"
