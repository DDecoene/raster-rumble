; version.asm - the version of the game, shown on the title screen
;
; This is the one place where the version lives. The release workflow in .github/workflows reads the number from the
; line below, so keep that line exactly in this form: !scr "v" followed by MAJOR.MINOR.PATCH, nothing else on it.
; Every pull request to main must raise it (the workflow checks that).

version_text
        !scr "v0.0.4"               ; the version as screen codes (the 'v' is part of the text)
VERSION_LEN = * - version_text      ; letters in the version text, '*' is the address where the assembler is now
