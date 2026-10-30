; raster-rumble - first light: a raster rainbow in the border
; Assembler: 64tass

        * = $0801

; BASIC stub: 10 SYS 2064
        .word (+), 10
        .byte $9e
        .text format("%d", start)
        .byte 0
+       .word 0

        * = $0810

VIC_RASTER = $d012
VIC_BORDER = $d020
VIC_BG     = $d021

start
        sei
        lda #$00
        sta VIC_BG

loop
        lda VIC_RASTER      ; current raster line ...
        sta VIC_BORDER      ; ... used as border colour = rainbow bands
        jmp loop
