        ;; Copyright 2020, Sjors van Gelderen

        ;; iNES header
        
        .inesprg 1              ; 1 bank of 16KB PRG-ROM
        .ineschr 1              ; 1 bank of 8KB CHR-ROM
        .inesmap 0              ; Mapper 0
        .inesmir 1              ; Background mirroring

        ;; PRG-ROM bank

        .bank 0
        .org $C000
        
Reset:
        SEI                     ; Disable IRQs
        CLD                     ; Disable decimal mode
        LDX #$40
        STX $4017               ; Disable APU frame IRQ
        LDX #$FF
        TXS                     ; Set up stack
        INX
        STA $2000               ; Disable NMI
        STX $2001               ; Disable rendering
        STX $4010               ; Disable DMC IRQs

        JMP AwaitVerticalBlankDone
AwaitVerticalBlank:     
        BIT $2002               ; PPUSTATUS check for vertical blank
        BPL AwaitVerticalBlank
        RTS
AwaitVerticalBlankDone: 

        JSR AwaitVerticalBlank  ; First wait

ClearMemory:                    
        LDA #$00                
        STA $0000,X             
        STA $0100,X
        STA $0300,X
        STA $0500,X
        STA $0600,X
        STA $0700,X
        LDA #$FE
        STA $0200,X             ; Move all sprites off screen
        INX
        BNE ClearMemory
        JSR AwaitVerticalBlank  ; Second wait, PPU is ready after this

LoadPalettes:
        LDA $2002               ; Reset high/low latch on PPU
        LDA #$3F
        STA $2006               ; Write high byte of $3F00
        LDA #$00
        STA $2006               ; Write low byte of $3F00
        LDX #$00
LoadPalettesLoop:
        LDA palettes,X
        STA $2007               ; Write to PPU
        INX
        CPX #$20
        BNE LoadPalettesLoop

LoadSprites:
        LDX #$00
LoadSpritesLoop:
        LDA sprites,X
        STA $0200,X
        INX
        CPX #$10
        BNE LoadSpritesLoop
        
LoadBackground:        
        LDA $2002               ; Reset high/low latch on PPU
        LDA #$20                ; Set the address to $2000, nametable 0
        STA $2006
        LDA #$00
        STA $2006

        ;; $0000 - background progress
        ;; $0001 - metatile to load
        ;; $0002 - line progress
        ;; $0003 - even or odd line
        
        LDA #$FF
        STA $0000
        STA $0002
        LDA #$00
        STA $0003
LoadBackgroundLoop:
        INC $0000               ; Update background progress
        LDX $0000               ; Retrieve background progress
        CPX #$F0                ; Check if the background is complete
        BEQ LoadBackgroundDone
        LDA background,X        ; Get the metatile number
        STA $0001               ; Store it in memory
        
        LDA #$FC
        LDX #$FF
FindOffsetLoop:
        CLC
        ADC #$04
        INX
        CPX $0001               ; Check if metatile offset has been reached
        BNE FindOffsetLoop
        TAX                     ; Remember offset in X register

        LDY $0003               ; Retrieve even or odd line status
        CPY #$01
        BNE SkipOddLineOffset
        INX                     ; Add offset for bottom tiles of metatile
        INX
SkipOddLineOffset:
        LDA metatiles,X         ; Retrieve the metatile data
        STA $2007               ; Upload it to PPU
        INX
        LDA metatiles,X
        STA $2007

        INC $0002               ; Update line progress
        LDX $0002
        CPX #$0F                ; Check for end of line
        BNE LoadBackgroundLoop
        
        LDA #$FF                ; Reset line progress counter
        STA $0002
        
        LDX $0003               ; Check if this is the first pass
        CPX #$00
        BNE SkipLineReset
        INC $0003               ; Update even or odd line status

        LDA $0000               ; Move to beginning of line for second pass
        CLC
        SBC #$0F
        STA $0000
        JSR LoadBackgroundLoop

SkipLineReset:
        LDA #$00
        STA $0003
        JSR LoadBackgroundLoop
        
LoadBackgroundDone:

;; LoadAttributes:
;;         LDA $2002
;;         LDA #$23
;;         STA $2006
;;         LDA #$C0
;;         STA $2006
;;         LDX #$00
;; LoadAttributesLoop:
;;         LDA attributes,X
;;         STA $2007
;;         INX
;;         CPX #$08
;;         BNE LoadAttributesLoop

        LDA #%10010000          ; Enable NMI, sprites from pattern table 0
        STA $2000               ; Background from pattern table 1
        LDA #%00011110          ; Enable sprites, background
        STA $2001
        
Forever:                        ; Main loop, interrupted by NMI
        JMP Forever

NMI:
        LDA #$00
        STA $2003               ; Set the low byte of the RAM address
        LDA #$02
        STA $4014               ; Set the high byte of the RAM address and start the transfer

        ;; PPU cleanup
        LDA #%10010000          
        STA $2000
        LDA #%00011110
        STA $2001
        LDA #$00
        STA $2005               ; Inform PPU there is no background scrolling
        STA $2005
        
        RTI

        .bank 1
        .org $E000

metatiles:
        .incbin "one.mt"

background:
        .incbin "one.nt"
        
palettes:
        .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F
        .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F
        ;; .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C

sprites:
        .db $80,$32,$00,$80
        .db $80,$33,$00,$88
        .db $88,$34,$00,$80
        .db $88,$35,$00,$88
        
        ;; .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
        ;; .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24

        ;; .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24
        ;; .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24

        ;; .db $24,$24,$24,$24,$45,$45,$24,$24,$45,$45,$45,$45,$45,$45,$24,$24
        ;; .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$53,$54,$24,$24

        ;; .db $24,$24,$24,$24,$47,$47,$24,$24,$47,$47,$47,$47,$47,$47,$24,$24
        ;; .db $24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$24,$55,$56,$24,$24

;; attributes:
;;         .db %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000, %00000000

;;         .db $24,$24,$24,$24, $47,$47,$24,$24 ,$47,$47,$47,$47, $47,$47,$24,$24 ,$24,$24,$24,$24 ,$24,$24,$24,$24, $24,$24,$24,$24, $55,$56,$24,$24
        
        .org $FFFA              ; IRQ vectors defined here
        .dw NMI
        .dw Reset
        .dw 0

        ;; CHR-ROM bank

        .bank 2
        .org $0000
        .incbin "one.chr"
