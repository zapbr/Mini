include "header.asm"

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


; LoadSprites:
;   LDX #$00              ; start at 0
; LoadSpritesLoop:
;   LDA Sprites, x        ; load data from address (sprites +  x)
;   STA $0200, x          ; store into RAM address ($0200 + x)
;   INX                   ; X = X + 1
;   CPX #$10              ; Compare X to hex $10, decimal 16
;   BNE LoadSpritesLoop   ; Branch to LoadSpritesLoop if compare was Not Equal to zero
;                         ; if compare was equal to 16, keep going down


LoadSprites: 
	LDA #TotalSprites    ;loading number of sprites
	ASL                  ; Multiply by four 
	ASL 
	STA NumberOfSprites
	LDX #$00             ; Init Index 
SpriteLoop:
	LDA Sprites, x
	STA SpriteRAM, x
	INX
	CPX NumberOfSprites
	BNE SpriteLoop

background_start: 		;Name table + Attribute
   LDA $2002
   LDA #$20
   STA $2006
   LDA #$00
   STA $2006
   LDA #<bg_start
   STA L_byte
   LDA #>bg_start
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
	BEQ CheckStart
	JSR MovePlayerLeft
CheckStart:
	LDA #%00001000
	AND Pressing 
	BEQ CheckShoot
	JSR StartGame	
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


StartGame:
	LDA IsStarted
	BNE exitStarted
	LDA #$00
	STA $2000
	STA $2001
	; unload bg
	LDA $2002
	LDA #$20
	STA $2006
	LDA #$00
	STA $2006
	LDA #<bg_stage
	STA L_byte
	LDA #>bg_stage
	STA H_byte
	LDX #$00
	LDY #$00
nambg_loop:
	LDA ($00), Y
	STA $2007
	INY
	CPY #$00
	BNE nambg_loop
	INC H_byte
	INX
	CPX #$04
	BNE nambg_loop
	; load new bg
	LDA #%10010000       ; Turning on NMI interupt / Setting Display Nametable 10001000
	STA $2000
	LDA #%00011110       ; Turning on the screen 00010000
	STA $2001
	LDA #$01
	STA IsStarted
exitStarted:		
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
	SBC #3+JumpingCt
	STA PlayerYPos
-
	INC JumpingCt
	RTS

Gravity:
	LDA PlayerYPos
    CMP #$80
	BCS great80
	CLC
	ADC #3
	STA PlayerYPos
	RTS
great80:
	LDA #$80
	STA PlayerYPos
	RTS

;   BCS +
; 	LDA PlayerYPos
; 	CLC
; 	ADC #3
; 	STA PlayerYPos
; +
; 	LDA PlayerYPos
;     CMP #$80
; 	BCS +	
; 	LDA #$80
; 	STA PlayerYPos
; +	
; 	RTS

;---------------------------Interupts----------------------

NMI:
	LDA IsStarted
	BEQ +
    JSR UpdateSprites    ; Update once a frame
	JSR WalkCycle
	JSR JumpCycle
	JSR Gravity
+
	JSR CheckController
	RTI

;------------------------RESOURCES-----------------
	.org $E000 ; RESOURCES

Palettes:
  .db $0f,$27,$17,$0F, $0f,$01,$21,$31, $0f,$06,$16,$26, $0f,$09,$19,$29   ;;background palette

  .db $0f,$05,$0D,$30, $0f,$10,$00,$30, $0f,$11,$0D,$30, $0f,$00,$0D,$30  ;;sprite palette


Sprites:;y  til att  x       FlipV FlipH Priority x x x pal pal
	.db $FE,$FE,$FE,$FE        ; ZeroSprite
	.db $80,$00,%00000000,$08  ; Player Sprite
	.db $80,$10,%01000001,$80  ; ENEMY Sprite

bg_start:
  .incbin "start.nam"

bg_stage:
  .incbin "backgroundmini.nam"

;-----------------------------VECTORS---------------------------

	.ORG $FFFA                      ; vectors
	.DW NMI
	.DW Reset
	.DW 0

;------------------------------CHR--------------------------

	.INCBIN "mini.chr"
