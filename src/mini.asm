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

;NameTable = $FF


TotalSprites = 1
WalkCycleWaitAmount = 5   ; Waiting 3 frames before walk cycle change
ground = #$80


PlayerTile EQU SpriteRAM+1
PlayerAttr EQU SpriteRAM+2
PlayerXPos EQU SpriteRAM+3
PlayerYPos EQU SpriteRAM

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

;--------------------------------------------------------------------
	.org $C000            ; Start of code

Reset:
	SEI          ; disable IRQs
	CLD          ; disable decimal mode
	LDX #$40
	STX $4017    ; disable APU frame IRQ
	LDX #$FF
	TXS          ; Set up stack
	INX          ; now X = 0
	STX $2000    ; disable NMI
	STX $2001    ; disable rendering
	STX $4010    ; disable DMC IRQs

vblankwait1:       ; First wait for vblank to make sure PPU is ready
	BIT $2002
	BPL vblankwait1

ClearRAM:
	LDA #$00
	STA $0000, x
	STA $0100, x
	STA $0200, x
	STA $0300, x
	STA $0400, x
	STA $0500, x
	STA $0600, x
	STA $0700, x
	LDA #$FE
	; STA SpriteRAM, x                ; Moving sprites off the screen
	INX
	BNE ClearRAM

vblankwait2:
  bit $2002
  bpl vblankwait2

;-------------------------- Setup ---------------------------
; LoadPallets:
; 	LDA $2002             ; read PPU status to reset the high/low latch
; 	LDA #$3F             ; Telling the ppu we want to write to $3F00
; 	STA $2006            ; $3F00 is where the paletteles live
; 	LDX #$00
; 	STX $2006
; 	LDX #$00              ; start out at 0
; PalLoop:
; 	LDA Palettes, x       ; Loading colors
; 	STA $2007             ; Storing them to $3F00 through port $2007
; 	INX                   ; Incremnt X counter
; 	CPX #$20              ; Write 32 times
; 	BNE PalLoop
; 	LDX #$00

; LoadSprites:
; 	LDA #TotalSprites    ;loading number of sprites
; 	ASL                  ; Multiply by four
; 	ASL
; 	STA NumberOfSprites
; 	LDX #$00             ; Init Index

; SpriteLoop:
; 	LDA Sprites, x
; 	STA SpriteRAM, x
; 	INX
; 	; CPX NumberOfSprites
; 	CPX #$10
; 	BNE SpriteLoop


LoadPalettes:
  LDA $2002             ; read PPU status to reset the high/low latch
  LDA #$3F
  STA $2006             ; write the high byte of $3F00 address
  LDA #$00
  STA $2006             ; write the low byte of $3F00 address
  LDX #$00              ; start out at 0
LoadPalettesLoop:
  LDA Palettes, x        ; load data from address (palette + the value in x)
                          ; 1st time through loop it will load palette+0
                          ; 2nd time through loop it will load palette+1
                          ; 3rd time through loop it will load palette+2
                          ; etc
  STA $2007             ; write to PPU
  INX                   ; X = X + 1
  CPX #$20              ; Compare X to hex $10, decimal 16 - copying 16 bytes = 4 sprites
  BNE LoadPalettesLoop  ; Branch to LoadPalettesLoop if compare was Not Equal to zero
                        ; if compare was equal to 32, keep going down


LoadSprites:
  LDX #$00              ; start at 0
LoadSpritesLoop:
  LDA Sprites, x        ; load data from address (sprites +  x)
  STA $0200, x          ; store into RAM address ($0200 + x)
  INX                   ; X = X + 1
  CPX #$10              ; Compare X to hex $10, decimal 16
  BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
                        ; if compare was equal to 16, keep going down


;Name table + Attribute
   LDA $2002
   LDA #$20
   STA $2006
   LDA #$00
   STA $2006
   LDA #<bg_nam
   STA L_byte
   LDA #>bg_nam
   STA H_byte
   LDX #$00
   LDY #$00
nam_loop:
   LDA ($00), Y
   STA $2007
   INY
   CPY #$00
   BNE nam_loop
   INC H_byte
   INX
   CPX #$04
   BNE nam_loop

;Background color setup
   LDA $2002
   LDA #$3F
   STA $2006
   LDA #$00
   STA $2006
   LDX #$00

; ----- START VIDEO
	LDA #%10010000       ; Turning on NMI interupt / Setting Display Nametable 10001000
	;ORA NameTable
	STA $2000
	LDA #%00011110       ; Turning on the screen 00010000
	STA $2001
	LDA #$00
  	STA $2005
  	STA $2005
	
Forever:
	JMP Forever          ; Forever loop

;------------------------Subroutines-------------------

UpdateSprites:
	LDA #$00
	STA $2003
	;LDA #>SpriteRAM
	LDA #$02
	STA $4014
	RTS

CheckController: 
	LDA #$01 
	STA $4016             ; Strobing thew controller 
	LDX #$00
	STX $4016             ; Latching controller state 
ConLoop:
	LDA $4016  
	LSR 
	ROR Pressing          ; RLDUsSBA 
	INX
	CPX #$08
	BNE ConLoop
CheckRight:
	LDA #%10000000
	AND Pressing
	BEQ CheckLeft
	JSR MovePlayerRight 
CheckLeft:
	LDA #%01000000
	AND Pressing 
	BEQ CheckShoot
	JSR MovePlayerLeft
CheckShoot:
	LDA #%00000001
	AND Pressing 
	BEQ CheckJump
	JSR PlayerShoot
CheckJump:
	LDA #%00000010
	AND Pressing 
	BEQ EndController
	JSR PlayerJump
EndController:
	RTS 


MovePlayerRight:
	LDA #%00000000
	STA PlayerAttr
	INC PlayerXPos
	LDA #$01
	STA IsWalking
	RTS

MovePlayerLeft:
	LDA #%01000000
	STA PlayerAttr
	DEC PlayerXPos
	LDA #$01
	STA IsWalking
	RTS

WalkCycle:
	LDA IsWalking
	BEQ NotWalking
	DEC IsWalking 			; back to zero 
	INC WalkingCt
	LDA WalkingCt
	CMP #WalkCycleWaitAmount
	BNE +
	LDA #$00
	STA WalkingCt
Toggle:	
	LDX PlayerTile
	CPX #$00
	BEQ Fr2
	CPX #$01
	BEQ Fr3
	CPX #$02
	BEQ Fr1
+
	RTS	
Fr1:
	LDA #$00
	STA PlayerTile
	RTS
Fr2:
	LDA #$01
	STA PlayerTile
	RTS	
Fr3:
	LDA #$02
	STA PlayerTile
	RTS	

ResetWalking:
	LDA #$00	
	STA WalkingCt
	STA WalkingFr
	STA PlayerTile
	RTS

NotWalking:
	JSR ResetWalking
	LDA #$00
	STA IsWalking
	RTS

PlayerJump:
	LDA #$01
	STA IsJumping
	RTS

PlayerShoot:
	LDA PlayerAttr
	EOR #%00000010
	STA PlayerAttr
	RTS

JumpCycle:
	LDA IsJumping
	BEQ -
	LDX PlayerYPos
	CPX #$28
	BCS --
	LDA #$00
	STA IsJumping 	; stop jump
	LDA #$01
	RTS 			; exit
-- 
	LDA PlayerYPos 	; meanwhile do things
	SEC
	SBC #4+JumpingCt
	STA PlayerYPos
-
	INC JumpingCt
	RTS

Gravity:
	LDA PlayerYPos
    CMP #$80
    BCS +
	LDA PlayerYPos
	CLC
	ADC #3
	STA PlayerYPos
+
	RTS

;---------------------------Interupts----------------------

NMI:
    JSR UpdateSprites    ; Update once a frame
	JSR CheckController
	JSR WalkCycle
	JSR JumpCycle
	JSR Gravity
	RTI

;------------------------RESOURCES-----------------
	.org $E000 ; RESOURCES

Palettes:
  .db $22,$14,$1A,$0F, $22,$36,$17,$0F, $22,$1A,$3B,$0F, $22,$27,$17,$0F   ;;background palette

  .db $0f, $05, $0D, $30, $0f, $19, $0D, $30, $0f, $11, $0D, $30, $0f, $00, $0D, $30  ;;sprite palette
	; ; Background Palette
	; .byte $09, $13, $23, $33
	; .byte $09, $13, $23, $33
	; .byte $09, $13, $23, $33
	; .byte $09, $13, $23, $33

	; ; Sprite Palette
	; .byte $0f, $05, $0D, $30
	; .byte $0f, $19, $0D, $30
	; .byte $0f, $11, $0D, $30
	; .byte $0f, $00, $0D, $30


Sprites:;y  til att  x       FlipV FlipH Priority x x x pal pal
	; .db $FE,$FE,$FE,$FE        ; ZeroSprite
	.db $80,$00,%00000000,$08  ; Player Sprite

bg_nam:
  .incbin "backgroundmini.nam"

;-----------------------------VECTORS---------------------------

	.ORG $FFFA                      ; vectors
	.DW NMI
	.DW Reset
	.DW 0

;------------------------------CHR--------------------------

	.INCBIN "mini.chr"
