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
        BNE OddLineOffsetDone
        INX                     ; Add offset for bottom tiles of metatile
        INX
OddLineOffsetDone:
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
        BNE LineResetDone
        INC $0003               ; Update even or odd line status

        LDA $0000               ; Move to beginning of line for second pass
        CLC
        SBC #$0F
        STA $0000
        JMP LoadBackgroundLoop
        
LineResetDone:
        LDA #$00
        STA $0003
        JMP LoadBackgroundLoop
        
LoadBackgroundDone:
        
LoadAttributes:
        LDA $2002
        LDA #$23
        STA $2006
        LDA #$C0
        STA $2006
        LDX #$00
LoadAttributesLoop:
        LDA attributes,X
        STA $2007
        INX
        CPX #$40
        BNE LoadAttributesLoop

        JMP LoadSpriteDone
LoadSprite:
        LDX #$00
LoadSpriteLoop:
        LDA sprites,Y
        STA $0200,Y
        INY
        INX
        CPX #$10
        BNE LoadSpriteLoop
        RTS
LoadSpriteDone:

        JMP SwapSpriteDone
SwapSprite:
        ;; X - sprite data offset
        ;; Y - sprite on ppu offset
        LDA #$00
        STA $0000               ; Progress count
SwapSpriteLoop:
        INX
        INY
        LDA sprites,X
        STA $0200,Y
        INX
        INY
        LDA sprites,X
        STA $0200,Y
        INX
        INX
        INY
        INY
        INC $0000
        LDA $0000
        CMP #$04
        BNE SwapSpriteLoop
        RTS
SwapSpriteDone:

        LDY #$00                ; Character
        JSR LoadSprite
        LDY #$10                ; Arrow
        JSR LoadSprite
        
        LDA #$00
        STA $0010               ; Store player direction
        STA $0011               ; Store player movement delay
        STA $0013               ; Store player movement progress
        
        JMP PlayerMovementDone
PlayerMovement:
        LDA $0010
        CMP #$00
        BEQ MoveDone
        INC $0011
        LDA $0011
        CMP #$01
        BNE MoveDone

        LDA #$00
        STA $0011
        INC $0013
        LDA $0013
        CMP #$11
        BNE FinishMoveDone
        LDA #$00
        STA $0010
        STA $0013
        JMP MoveDone
FinishMoveDone:
        LDA $0010
        CMP #$01
        BNE MoveUpDone
        DEC $0210
        DEC $0214
        DEC $0218
        DEC $021C
        JMP MoveDone
MoveUpDone:
        CMP #$02
        BNE MoveDownDone
        INC $0210
        INC $0214
        INC $0218
        INC $021C
        JMP MoveDone
MoveDownDone:
        CMP #$03
        BNE MoveLeftDone
        DEC $0213
        DEC $0217
        DEC $021B
        DEC $021F
        JMP MoveDone
MoveLeftDone:
        CMP #$04
        BNE MoveDone
        INC $0213
        INC $0217
        INC $021B
        INC $021F
MoveDone:
        RTS
PlayerMovementDone:     

        LDA #%10010000          ; Enable NMI, sprites from pattern table 0
        STA $2000               ; Background from pattern table 1
        LDA #%00011110          ; Enable sprites, background
        STA $2001

        LDA #$00                
        STA $0040               ; Text delay counter
        STA $0041               ; Text PPU address
        STA $0044               ; Text tile number
        
Forever:
        ;; Wait for NMI
        JMP Forever

TextRoutine:
        LDA $2002               ; Prepare PPU
        LDA #$20
        STA $2006
        LDA $0041
        STA $2006
        
        LDA $0040
        CMP #$05
        BNE TextRoutineDone
        LDA #$FF
        STA $0040
        
        LDX $0044
        LDA text,X
        BEQ TextRoutineDone     ; Check for EOF
        CMP #$02
        BNE TextWhitespaceDone
        LDA #$27                ; Whitespace character
        JMP TextLineEndDone
TextWhitespaceDone:     
        CMP #$01
        BNE TextLineEndDone
        LDA $0041
        CLC
        ADC #$20
        AND #$F0
        STA $0041
        INC $0044
        RTS
TextLineEndDone:
        SEC
        SBC #$03
        STA $2007
        INC $0041
        INC $0044
TextRoutineDone:
        INC $0040
        RTS
        
NMI:        
        LDA #$00
        STA $2003               ; Set the low byte of the RAM address
        LDA #$02
        STA $4014               ; Set the high byte of the RAM address and start the transfer

        LDA $0042
        BEQ SkipTextRoutine
        LDA $0043
        BNE SkipTextRoutine
        JSR TextRoutine
SkipTextRoutine:

        LDA #%10010000          ; PPU cleanup
        STA $2000
        LDA #%00011110
        STA $2001
        LDA #$00
        STA $2005               ; Inform PPU there is no background scrolling
        STA $2005
        
LatchController:
        LDA #$01
        STA $4016
        LDA #$00
        STA $4016               ; Latch buttons on both controllers

ReadA:
        LDA $4016
        AND #%00000001
        BEQ ReadADone
        LDA $0042
        BNE ReadADone
        INC $0042
        JSR TextRoutine
ReadADone:

ReadB:
        LDA $4016
        AND #%00000001
        BEQ ReadBDone
        ;; Do something
ReadBDone:
        
ReadSelect:
        LDA $4016
        AND #%00000001
        BEQ ReadSelectDone
        ;; Do something
ReadSelectDone:

ReadStart:
        LDA $4016
        AND #%00000001
        BEQ ReadStartDone
        ;; Do something
ReadStartDone:

ReadUp:
        LDA $4016
        AND #%00000001
        BEQ ReadUpDone
        LDA $0010
        CMP #$00
        BNE ReadUpDone
        LDA #$01
        STA $0010
        LDX #$10
        LDY #$10
        JSR SwapSprite
ReadUpDone:
        
ReadDown:
        LDA $4016
        AND #%00000001
        BEQ ReadDownDone
        LDA $0010
        CMP #$00
        BNE ReadDownDone        
        LDA #$02
        STA $0010
        LDX #$20
        LDY #$10
        JSR SwapSprite
ReadDownDone:

ReadLeft:
        LDA $4016
        AND #%00000001
        BEQ ReadLeftDone
        LDA $0010
        CMP #$00
        BNE ReadLeftDone        
        LDA #$03
        STA $0010
        LDX #$30
        LDY #$10
        JSR SwapSprite
ReadLeftDone:

ReadRight:
        LDA $4016
        AND #%00000001
        BEQ ReadRightDone
        LDA $0010
        CMP #$00
        BNE ReadRightDone        
        LDA #$04
        STA $0010
        LDX #$40
        LDY #$10
        JSR SwapSprite
ReadRightDone:

        JSR PlayerMovement
        
        RTI

        .bank 1
        .org $E000

metatiles:
        .incbin "scavengerhunt.mt"

background:
        .incbin "scavengerhunt.nt"
        
palettes:
        .incbin "scavengerhunt.s"

sprites:
        .db $3F,$00,$00,$80
        .db $3F,$01,$00,$88
        .db $47,$10,$00,$80
        .db $47,$11,$00,$88

;; playerUp:  
        .db $7F,$02,$00,$80
        .db $7F,$03,$00,$88
        .db $87,$12,$00,$80
        .db $87,$13,$00,$88

;; playerDown: 
        .db $7F,$04,$00,$80
        .db $7F,$05,$00,$88
        .db $87,$14,$00,$80
        .db $87,$15,$00,$88

;; playerLeft:     
        .db $7F,$06,$00,$80
        .db $7F,$07,$00,$88
        .db $87,$16,$00,$80
        .db $87,$17,$00,$88

;; playerRight:
        .db $7F,$08,$00,$80
        .db $7F,$09,$00,$88
        .db $87,$18,$00,$80
        .db $87,$19,$00,$88

attributes:
        .incbin "scavengerhunt.at"

text:
        .incbin "text.txt"
        
        .org $FFFA              ; IRQ vectors defined here
        .dw NMI
        .dw Reset
        .dw 0

        ;; CHR-ROM bank

        .bank 2
        .org $0000
        .incbin "scavengerhunt.chr"
