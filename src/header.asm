; CONSTS/VARS
L_byte         = $0000
H_byte         = $0001
SpriteRAM = $0200
NumberOfSprites = $00
Pressing = $01
IsWalking = $02
WalkingFr = $03
WalkingCt = $04
IsJumping = $05
JumpingCt = $06
IsFalling = $07
IsStarted = $08

;NameTable = $FF


TotalSprites = 3
WalkCycleWaitAmount = 5   ; Waiting 3 frames before walk cycle change
ground = #$80


PlayerYPos EQU SpriteRAM+4
PlayerTile EQU SpriteRAM+5
PlayerAttr EQU SpriteRAM+6
PlayerXPos EQU SpriteRAM+7


;==============================iNES Header===========================

	.ORG $7ff0
Header:                        ; 16 byte .NES header (iNES format)	
	.DB "NES", $1a
	.DB $02                    ; 32Kb PRG (2x 16KB Banks)
	.DB $01                    ; 8KB CHR (1x 8KB banks)
	.DB $01                    ; mapper 0 NROM
	.DB $00                    ; mapper 0
	.DB $00
	.DB $00
	.DB $00
	.DB $00
	.DB $00
	.DB $00
	.DB $00
	.DB $00
