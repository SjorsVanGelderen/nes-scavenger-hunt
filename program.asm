	;; Copyright 2020, Sjors van Gelderen

	.inesprg 1 		; 1 bank of 16KB PRG-ROM
	.ineschr 1		; 1 bank of 8KB CHR-ROM
	.inesmap 0		; Mapper 0
	.inesmir 1              ; Background mirroring

	;; PRG-ROM bank

	.bank 0
	.org $C000

Reset:	
	SEI 			; Disable IRQs
	CLD 			; Disable decimal mode
	LDX #$40
	STX $4017		; Disable APU frame IRQ
	LDX #$FF
	TXS			; Set up stack
	INX
	STA $2000		; Disable NMI
	STX $2001		; Disable rendering
	STX $4010		; Disable DMC IRQs

	JMP AwaitVerticalBlankDone
AwaitVerticalBlank:	
	BIT $2002		; PPUSTATUS check for vertical blank
	BPL AwaitVerticalBlank
	RTS
AwaitVerticalBlankDone:	

	JSR AwaitVerticalBlank 	; First wait

ClearMemory:			; This routine comes from Nerdy Nights
	LDA #$00		; But I'm not sure if this really clears 
	STA $0000,X		; everything properly
	STA $0100,X
	STA $0300,X
	STA $0500,X
	STA $0600,X
	STA $0700,X
	LDA #$FE
	STA $0200,X		; Move all sprites off screen
	INX
	BNE ClearMemory
	JSR AwaitVerticalBlank 	; Second wait, PPU is ready after this

LoadPalettes:
	LDA $2002		; Reset high/low latch on PPUSTATUS
	LDA #$3F
	STA $2006		; Write high byte of $3F00
	LDA #$00
	STA $2006		; Write low byte of $3F00
	LDX #$00
LoadPalettesLoop:
	LDA palette,X
	STA $2007		; Write to PPU
	INX
	CPX #$20
	BNE LoadPalettesLoop

	LDA #$80		; $80 is the center of the screen
	STA $0200
	STA $0203
	LDA #$00		; The tile number
	STA $0201
	STA $0202		; Color 0, no flipping

	LDA #%10000000		; Enable NMI, sprites from pattern table 0
	STA $2000

	LDA #%00010000		; Enable sprites
	STA $2001

LoadSprites:
	LDX #$00
LoadSpritesLoop:
	LDA sprites,X
	STA $0200,X
	INX
	CPX #$20
	BNE LoadSpritesLoop

	LDA #%10000000		; Enable NMI, sprites from pattern table 1
	STA $2000

	LDA #%00010000		; Enable sprites
	STA $2001
	
Forever:			; Main loop, interrupted by NMI
	JMP Forever

NMI:
	LDA #$00
	STA $2003		; Set the low byte of the RAM address
	LDA #$02
	STA $4014		; Set the high byte of the RAM address and start the transfer
	RTI

	.bank 1
	.org $E000

palette:
	.db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F
	.db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C

sprites:
	.db $80,$32,$00,$80
	.db $80,$33,$00,$88
	.db $88,$34,$00,$80
	.db $88,$35,$00,$88
	
	.org $FFFA		; IRQ vectors defined here
	.dw NMI
	.dw Reset
	.dw 0

	;; CHR-ROM bank

	.bank 2
	.org $0000
	.incbin "graphics.chr"
