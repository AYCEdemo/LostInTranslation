; ======================
; Retroboyz GB/GBC shell
; ======================

; If set to 1, enable debugging features.
DebugMode	= 1

; Defines
include "Defines.asm"

; =============
; Reset vectors
; =============
section "Reset $00",rom0[$00]
ResetGame::		jp	EntryPoint
	
section	"Reset $08",rom0[$08]
FillRAM::		jp	_FillRAM
	
section	"Reset $10",rom0[$10]
WaitVBlank::	jp	_WaitVBlank

section	"Reset $18",rom0[$18]
WaitTimer::		jp	_WaitTimer

section	"Reset $20",rom0[$20]
WaitLCDC::		jp	_WaitLCDC
	
section	"Reset $30",rom0[$30]
DoOAMDMA::		jp	$ff80

section	"Reset $38",rom0[$38]
Trap::			jr	Trap
	
	
; ==================
; Interrupt handlers
; ==================

section	"VBlank IRQ",rom0[$40]
IRQ_VBlank::	jp	DoVBlank

section	"STAT IRQ",rom0[$48]
IRQ_Stat::	jp	DoStat

section	"Timer IRQ",rom0[$50]
IRQ_Timer::	jp	DoTimer

section	"Serial IRQ",rom0[$58]
IRQ_Serial::	reti

section	"Joypad IRQ",rom0[$60]
IRQ_Joypad::	reti

; ===============
; System routines
; ===============

include	"SystemRoutines.asm"

; ==========
; ROM header
; ==========

section	"ROM header",rom0[$100]

EntryPoint::
	nop
	jp	ProgramStart
NintendoLogo:	; DO NOT MODIFY OR ROM WILL NOT BOOT!!!
	db	$ce,$ed,$66,$66,$cc,$0d,$00,$0b,$03,$73,$00,$83,$00,$0c,$00,$0d
	db	$00,$08,$11,$1f,$88,$89,$00,$0e,$dc,$cc,$6e,$e6,$dd,$dd,$d9,$99
	db	$bb,$bb,$67,$63,$6e,$0e,$ec,$cc,$dd,$dc,$99,$9f,$bb,$b9,$33,$3e
ROMTitle:		romTitle	"LOST INTRO"	; ROM title (15 bytes)
GBCSupport:		db	$00							; GBC support (0 = DMG only, $80 = DMG/GBC, $C0 = GBC only)
NewLicenseCode:	db	"AC"						; new license code (2 bytes)
SGBSupport:		db	0							; SGB support
CartType:		db	$0							; Cart type, see hardware.inc for a list of values
ROMSize:		db								; ROM size (handled by post-linking tool)
RAMSize:		db	0							; RAM size
DestCode:		db	1							; Destination code (0 = Japan, 1 = All others)
OldLicenseCode:	db	$33							; Old license code (if $33, check new license code)
ROMVersion:		db	0							; ROM version
HeaderChecksum:	db								; Header checksum (handled by post-linking tool)
ROMChecksum:	dw								; ROM checksum (2 bytes) (handled by post-linking tool)

; =====================
; Start of program code
; =====================

ProgramStart::
	di
	ld	sp,$e000
	push	bc
	push	af
	
; init memory
	ld	hl,$c000	; start of WRAM
	ld	bc,$1ffa	; don't clear stack
	xor	a
	rst	$08
		
	ld	bc,$7f80
	xor	a
.loop
	ld	[c],a
	inc	c
	dec	b
	jr	nz,.loop
	call	CopyDMARoutine
	call	$ff80	; clear OAM
	
; check GB type
; sets sys_GBType to 0 if DMG/SGB/GBP/GBL/SGB2, 1 if GBC, 2 if GBA/GBA SP/GB Player
; TODO: Improve checks to allow for GBP/SGB/SGB2 to be detected separately
	pop	af
	pop	bc
	cp	$11
	jr	nz,.dmg
.gbc
	and	1		; a = 1
	add	b		; b = 1 if on GBA
	ld	[sys_GBType],a
	jr	.continue
.dmg
	xor	a
	ld	[sys_GBType],a
.continue
	
	ld	a,IEF_VBLANK
	ldh	[rIE],a		; enable VBlank
	ld	a,%01000000
	ldh	[rSTAT],a	; enable LYC interrupt
	ld	a,32
	ld	[DemoTimer],a
	ei
	
	jr	IntroLoop1
	
FadeTable:	db	%00000000,%01010100,%10101000,%11111100

IntroLoop1:
	ld	a,[DemoTimer]
	dec	a
	ld	[DemoTimer],a
	push	af
	
	rra	; /2
	rra	; /4
	rra	; /8
	and	3
	ld	hl,FadeTable
	add	l
	ld	l,a
	ld	a,[hl+]
	ldh	[rBGP],a
	
	pop	af
	halt
	jr	nz,IntroLoop1

; Intro pic part
	xor a
	ldh [rLCDC],a
	ld	hl,IntroPicTiles
	ld	de,$8000
	call	DecodeWLE
	ld	hl,IntroPicMap1
	ld	de,$9840
	call	DecodeWLE
	ld	hl,IntroPicMap2
	ld	de,$9c40
	call	DecodeWLE
	SetDMGPal	rBGP,0,1,2,3
	ld	a,IEF_VBLANK+IEF_LCDC
	ldh	[rIE],a		; enable VBlank + LYC interrupt

	xor	a
	ld [DemoTimer],a
	call	GBM_LoadModule

IntroLoop3:
	ld a,[sys_CurrentFrame]
	rrca
	ld a,%10010001
	jr	nc,.even
	ld a,%10001001
.even
	ldh	[rLCDC],a
	ld hl,.fadebgps
	ld a,[DemoTimer]
	cp 32
	jr nc,.nofadeout
	cpl
	add 33
	srl a
	jr .fade
.nofadeout
	sub 240
	jr c,.fadeindone
.fade
	srl a
	srl a
	ld [FadeLevel],a
	add l
	ld l,a
.fadeindone
	ld a,[hl]
	ldh [rBGP],a

	call GBM_Update

	ld	a,111
	ldh [rLYC],a
	ld a,[sys_CurrentFrame]
	cpl
	add a
	ld b,a
	; time for a fun part, since I don't want to touch DevEd's
	; LCDC interrupt routine so I will just do the dihalt trick
	xor a
	di
	halt
	ldh [rIF],a ; manually acknowledge the interrupt
	ei
	
	ld c,-7
.loop
	ldh a,[rSTAT]
	and STATF_LCD
	jr nz,.loop

	ldh a,[rLY]
	cp 135
	jr z, .done
	add a
	add a
	add b
	ld	h,high(LogoSineTable)
	ld	l,a
	ld a,c
	add [hl]
	ldh [rSCY],a
	ldh a,[rLY]
	add low(.fadelevels)-111
	ld h,high(.fadelevels)
	ld l,a
	ld a,[FadeLevel]
	add [hl]
	add low(.fadebgps)
	ld l,a
	ld a,[hl]
	ldh [rBGP],a

	dec c
	dec c
.loop2
	ldh a,[rSTAT]
	and STATF_LCD
	jr z,.loop2
	jr .loop

.fadelevels	db 1, 1, 1, 1, 1, 1, 2, 1, 2, 1, 2, 1, 2, 2, 2, 2, 2, 2, 3, 2, 3, 2, 3, 2
.fadebgps	db %11100100, %10010000, %01000000, 0, 0, 0, 0

.done
	xor a
	ldh [rSCY],a
	rst	$10
	ld a,[sys_CurrentFrame]
	rrca
	jp c,IntroLoop3
	ld a,[DemoTimer]
	dec a
	ld [DemoTimer],a
	jp nz,IntroLoop3
	
	xor	a
	ldh	[rLCDC],a
	ldh	[rWX],a
	; clear $9c00 for transition
	ld hl,$9c40
	ld bc,32*12
	call	FillRAM
	ld	hl,Font
	ld	de,$8000
	call	DecodeWLE
	ld	hl,AYCELogoTiles
	ld	de,$9000
	call	DecodeWLE
	ld	hl,AYCELogoMap
	ld	de,$9800
	call	DecodeWLE
	ld	a,8
	ld	[ScrollerOffset],a
	SetDMGPal	rBGP,0,1,2,3
	SetDMGPal	rOBP0,3,2,1,0
	ld	a,%11100011
	ldh	[rLCDC],a
	ld	a,20
	ldh	[rLYC],a
	ld	a,WindowScrollTable_End-WindowScrollTable
	ld	[DemoTimer],a
	
	jr	IntroLoop2
	
WindowScrollTable:
	db	1,3,6,10,15,21,28,36,45,55,65,75,85,95,105,115,125,135,145,155,160,168
	db	167,165,163,163,162,161,160,160,159,159
	db	159,159,160,160,161,162,162,163,165,167,168
WindowScrollTable_End
	
IntroLoop2:
	ld	a,[DemoTimer]
	dec	a
	ld	[DemoTimer],a
	push	af
	ld	b,a
	ld	a,WindowScrollTable_End-WindowScrollTable-1
	sub	b
	ld	hl,WindowScrollTable
	add	l
	ld	l,a
	jr	nc,.nocarry
	inc	h
.nocarry
	ld	a,[hl+]
	ldh	[rWX],a
	pop	af
	rst	$10
	jr	nz,IntroLoop2
	
MainLoop::
	; do stuff
	call	DoScroller
	rst	$10
	jr MainLoop
	
ScrollText::
	db	"                    "
	incbin	"Scrolltext.txt"
ScrollText_End
	db	"                    "

ScrollTextSize	equ	(ScrollText_End-ScrollText)

; =================
; Scroller routines
; =================
	
DoScroller:
	ld	hl,ScrollerPos
	push	hl
	ld	a,[hl+]
	ld	h,[hl]
	ld	l,a
	ld	a,h
	cp	high(ScrollTextSize)
	jr	nz,.skip3
	ld	a,l
	cp	low(ScrollTextSize)
	jr	nz,.skip3
	xor	a
	ld	[ScrollerPos],a
	ld	[ScrollerPos+1],a
	; fall through
.skip3
	ld	a,[ScrollerOffset]
	dec	a
	jr	nz,.skip2
	pop	hl
	ld	a,[hl+]
	ld	b,[hl]
	ld	c,a
	inc	bc
	ld	a,b
	ld	h,b
	ld	[ScrollerPos+1],a
	ld	a,c
	ld	l,c
	ld	[ScrollerPos],a
	ld	a,8
	ld	[ScrollerOffset],a
	jr	.skip
.skip2
	ld	[ScrollerOffset],a
	pop	hl
	ld	a,[hl+]
	ld	h,[hl]
	ld	l,a
.skip
	ld	bc,ScrollText
	add	hl,bc
	ld	de,SpriteBuffer
	ld	b,21
.loop
	; sprite Y pos
	push	hl
	push	bc
	ld	a,b
	dec	a
	add	a
	add	a
	add	a
	ld	b,a
	ld	a,[ScrollerOffset]
	ld	c,a
	ld	a,[sys_CurrentFrame]
	sub	c
	add	b
	pop	bc
	ld	h,high(ScrollerSineTable)
	ld	l,a
	ld	a,[hl]
	add	16
	ld	[de],a
	inc	e
	; sprite x pos
	ld	a,21
	sub	b
	add	a	; x2
	add	a	; x4
	add	a	; x8
	ld	l,a
	ld	a,[ScrollerOffset]
	add	l
	dec	a
	ld	[de],a
	inc	e
	; tile number
	pop	hl
	ld	a,[hl+]
	sub	32
	ld	[de],a
	inc	e
	; attributes
	xor	a
	ld	[de],a
	inc	e
	dec	b
	jr	nz,.loop
	ret

; ==================
; Interrupt handlers
; ==================

DoVBlank::
	push	af
	ld	a,[sys_CurrentFrame]
	inc	a
	ld	[sys_CurrentFrame],a	; increment current frame
	ld	a,20
	ldh	[rLYC],a	; reset LYC to 20
	ld	a,1
	ld	[sys_VBlankFlag],a		; set VBlank flag
	rst	$30	; do OAM DMA
	xor	a
	ldh	[rSCX],a
;	call	GBM_Update
	pop	af
	reti
	
DoStat::
	push	af
	push	bc
	push	hl
	ld	a,[rLY]
	ld	b,a
	and	a
	jr	z,.skip2
	
	xor	a
	ld	[sys_VBlankFlag],a	; HACK
	inc	a
	ld	[sys_LCDCFlag],a
	
	ldh	a,[rLYC]
	inc	a
	cp	108
	jr	nc,.skip2
	
	ldh	[rLYC],a
	ld	a,[sys_CurrentFrame]
	add	b
	bit	0,a
	jr	nz,.noflip
	cpl
.noflip
	ld	l,a
	ld	h,high(LogoSineTable)
	ld	a,[hl]
	ldh	[rSCX],a
.skip
	pop	hl
	pop	bc
	pop	af
	reti
.skip2
	xor	a
	ldh	[rSCX],a
	call	GBM_Update
	jr	.skip
	
DoTimer::
	push	af
	ld	a,1
	ld	[sys_TimerFlag],a
	pop	af
	reti
	
; =======================
; Interrupt wait routines
; =======================

_WaitVBlank::
	push	af
	ldh	a,[rIE]
	bit	0,a
	jr	z,.done
.wait
	halt
	ld	a,[sys_VBlankFlag]
	and	a
	jr	z,.wait
	xor	a
	ld	[sys_VBlankFlag],a
.done
	pop	af
	ret

_WaitTimer::
	push	af
	ldh	a,[rIE]
	bit	2,a
	jr	z,.done
.wait
	halt
	ld	a,[sys_TimerFlag]
	and	a
	jr	z,.wait
	xor	a
	ld	[sys_VBlankFlag],a
.done
	pop	af
	ret

_WaitLCDC::
	ldh	a,[rIE]
	bit	1,a
	jr	z,.done
.wait
	halt
	ld	a,[sys_LCDCFlag]
	and	a
	jr	z,.wait
	xor	a
	ld	[sys_LCDCFlag],a
.done
	pop	af
	ret
	
; =================
; Graphics routines
; =================

_CopyTileset::						; WARNING: Do not use while LCD is on!
	ld	a,[hl+]						; get byte
	ld	[de],a						; write byte
	inc	de
	dec	bc
	ld	a,b							; check if bc = 0
	or	c
	jr	nz,_CopyTileset				; if bc != 0, loop
	ret
	
_CopyTilesetSafe::					; same as _CopyTileset, but waits for VRAM accessibility before writing data
	ldh	a,[rSTAT]
	and	2							; check if VRAM is accessible
	jr	nz,_CopyTilesetSafe			; if it isn't, loop until it is
	ld	a,[hl+]						; get byte
	ld	[de],a						; write byte
	inc	de
	dec	bc
	ld	a,b							; check if bc = 0
	or	c
	jr	nz,_CopyTilesetSafe			; if bc != 0, loop
	ret
	
_CopyTileset1BPP::					; WARNING: Do not use while LCD is on!
	ld	a,[hl+]						; get byte
	ld	[de],a						; write byte
	inc	de							; increment destination address
	ld	[de],a						; write byte again
	inc	de							; increment destination address again
	dec	bc
	dec	bc							; since we're copying two bytes, we need to dec bc twice
	ld	a,b							; check if bc = 0
	or	c
	jr	nz,_CopyTileset1BPP			; if bc != 0, loop
	ret

_CopyTileset1BPPSafe::				; same as _CopyTileset1BPP, but waits for VRAM accessibility before writing data
	ldh	a,[rSTAT]
	and	2							; check if VRAM is accessible
	jr	nz,_CopyTileset1BPPSafe		; if it isn't, loop until it is
	ld	a,[hl+]						; get byte
	ld	[de],a						; write byte
	inc	de							; increment destination address
	ld	[de],a						; write byte again
	inc	de							; increment destination address again
	dec	bc
	dec	bc							; since we're copying two bytes, we need to dec bc twice
	ld	a,b							; check if bc = 0
	or	c
	jr	nz,_CopyTileset1BPP			; if bc != 0, loop
	ret
	
; ============
; Sprite stuff
; ============

CopyDMARoutine::
	ld	bc,$80 + ((_OAM_DMA_End-_OAM_DMA) << 8)
	ld	hl,_OAM_DMA
.loop
	ld	a,[hl+]
	ld	[c],a
	inc	c
	dec	b
	jr	nz,.loop
	ret
	
_OAM_DMA::
	ld	a,high(SpriteBuffer)
	ldh	[rDMA],a
	ld	a,$28
.wait
	dec	a
	jr	nz,.wait
	ret
_OAM_DMA_End

; =============
; Misc routines
; =============
	
; Fill RAM with a value.
; INPUT:  a = value
;        hl = address
;        bc = size
_FillRAM::
	ld	e,a
.loop
	ld	[hl],e
	inc	hl
	dec	bc
	ld	a,b
	or	c
	jr	nz,.loop
	ret
	
; Fill up to 256 bytes of RAM with a value.
; INPUT:  a = value
;        hl = address
;         b = size
_FillRAMSmall::
	ld	e,a
.loop
	ld	[hl],e
	inc	hl
	dec	b
	jr	nz,.loop
	ret
	
; Copy up to 65536 bytes to RAM.
; INPUT: hl = source
;        de = destination
;        bc = size
_CopyRAM::
	ld	a,[hl+]
	ld	[de],a
	inc	de
	dec	bc
	ld	a,b
	or	c
	jr	nz,_CopyRAM
	ret
	
; Copy up to 256 bytes to RAM.
; INPUT: hl = source
;        de = destination
;         b = size
_CopyRAMSmall::
	ld	a,[hl+]
	ld	[de],a
	inc	de
	dec	b
	jr	nz,_CopyRAMSmall
	ret

DecodeWLE:
; Walle Length Encoding decoder
	ld	c,0
DecodeWLELoop:
	ld	a,[hl+]
	ld	b,a
	and	$c0
	jr	z,.literal
	cp	$40
	jr	z,.repeat
	cp	$80
	jr	z,.increment

.copy
	ld	a,b
	inc	b
	ret	z

	and	$3f
	inc	a
	ld	b,a
	ld	a,[hl+]
	push	hl
	ld	l,a
	ld	a,e
	scf
	sbc	l
	ld	l,a
	ld	a,d
	sbc	0
	ld	h,a
	call	_CopyRAMSmall
	pop	hl
	jr	DecodeWLELoop

.literal
	ld	a,b
	and	$1f
	bit	5,b
	ld	b,a
	jr	nz,.longl
	inc	b
	call	_CopyRAMSmall
	jr	DecodeWLELoop

.longl
	push	bc
	ld	a,[hl+]
	ld	c,a
	inc	bc
	call	_CopyRAM
	pop	bc
	jr	DecodeWLELoop

.repeat
	call	.repeatIncrementCommon
.loopr
	ld	[de],a
	inc	de
	dec	b
	jr	nz,.loopr
	jr	DecodeWLELoop

.increment
	call	.repeatIncrementCommon
.loopi
	ld	[de],a
	inc	de
	inc	a
	dec	b
	jr	nz,.loopi
	ld	c,a
	jr	DecodeWLELoop

.repeatIncrementCommon
	bit	5,b
	jr	z,.nonewr
	ld	c,[hl]
	inc	hl
.nonewr
	ld	a,b
	and	$1f
	inc	a
	ld	b,a
	ld	a,c
	ret

	
; =============
; Graphics data
; =============

Font::				incbin	"GFX/Font.bin.wle"

IntroPicTiles:		incbin	"GFX/IntroPic.bin.wle"
IntroPicMap1:		incbin	"GFX/IntroPic1.map.wle"
IntroPicMap2:		incbin	"GFX/IntroPic2.map.wle"

; ====================
; GBMod music routines
; ====================

include	"GBMod_Player.asm"

; =========
; Misc data
; =========

section "Sine tables",rom0,align[8]	; alignment used to speed up processing
ScrollerSineTable:	; used for scrolltext
	db	$44,$46,$47,$49,$4b,$4c,$4e,$50,$51,$53,$55,$56,$58,$59,$5b,$5c
	db	$5e,$60,$61,$63,$64,$66,$67,$68,$6a,$6b,$6d,$6e,$6f,$70,$72,$73
	db	$74,$75,$76,$77,$79,$7a,$7b,$7c,$7d,$7d,$7e,$7f,$80,$81,$81,$82
	db	$83,$83,$84,$85,$85,$86,$86,$86,$87,$87,$87,$87,$88,$88,$88,$88
	db	$88,$88,$88,$88,$88,$87,$87,$87,$87,$86,$86,$86,$85,$85,$84,$83
	db	$83,$82,$81,$81,$80,$7f,$7e,$7d,$7d,$7c,$7b,$7a,$79,$77,$76,$75
	db	$74,$73,$72,$70,$6f,$6e,$6d,$6b,$6a,$68,$67,$66,$64,$63,$61,$60
	db	$5e,$5c,$5b,$59,$58,$56,$55,$53,$51,$50,$4e,$4c,$4b,$49,$47,$46
	db	$44,$42,$41,$3f,$3d,$3c,$3a,$38,$37,$35,$33,$32,$30,$2f,$2d,$2c
	db	$2a,$28,$27,$25,$24,$22,$21,$20,$1e,$1d,$1b,$1a,$19,$18,$16,$15
	db	$14,$13,$12,$11,$0f,$0e,$0d,$0c,$0b,$0b,$0a,$09,$08,$07,$07,$06
	db	$05,$05,$04,$03,$03,$02,$02,$02,$01,$01,$01,$01,$00,$00,$00,$00
	db	$00,$00,$00,$00,$00,$01,$01,$01,$01,$02,$02,$02,$03,$03,$04,$05
	db	$05,$06,$07,$07,$08,$09,$0a,$0b,$0b,$0c,$0d,$0e,$0f,$11,$12,$13
	db	$14,$15,$16,$18,$19,$1a,$1b,$1d,$1e,$20,$21,$22,$24,$25,$27,$28
	db	$2a,$2c,$2d,$2f,$30,$32,$33,$35,$37,$38,$3a,$3c,$3d,$3f,$41,$42
	
LogoSineTable:
	db	 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5
	db	 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0
	db	-1,-1,-1,-1,-2,-2,-2,-2,-3,-3,-3,-3,-4,-4,-4,-4,-4,-4,-4,-5,-5,-5,-5,-5,-5,-6,-6,-6,-6,-6,-6,-6
	db	-6,-6,-6,-6,-6,-6,-6,-5,-5,-5,-5,-5,-5,-4,-4,-4,-4,-4,-4,-4,-3,-3,-3,-3,-2,-2,-2,-2,-1,-1,-1,-1
	db	 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 5, 5, 5, 5, 5, 5, 5
	db	 5, 5, 5, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 3, 3, 3, 3, 3, 3, 3, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0
	db	-1,-1,-1,-1,-2,-2,-2,-2,-3,-3,-3,-3,-4,-4,-4,-4,-4,-4,-4,-5,-5,-5,-5,-5,-5,-6,-6,-6,-6,-6,-6,-6
	db	-6,-6,-6,-6,-6,-6,-6,-5,-5,-5,-5,-5,-5,-4,-4,-4,-4,-4,-4,-4,-3,-3,-3,-3,-2,-2,-2,-2,-1,-1,-1,-1
	
; ==========
; Music data
; ==========

section	"Music data",romx[$4000]
incbin	"Demotune.bin"

section	"Graphics Data 2",romx
AYCELogoTiles::		incbin	"GFX/AyceLogo.bin.wle"
AYCELogoMap:		incbin	"GFX/AyceLogo.map.wle"
