; ================================================================
; XM2GB replay routine
; ================================================================

; NOTE: For best results, place player code in ROM0.

; ===========
; Player code
; ===========

section	"GBMod",rom0
GBMod:

GBM_LoadModule:		jp	GBMod_LoadModule
GBM_Update:			jp	GBMod_Update
GBM_Stop:			jp	GBMod_Stop
;	db	"XM2GB by DevEd | email: deved8@gmail.com"

; ================================

GBMod_LoadModule:
	push	af
	push	bc
	push	hl
	di
	ld	[GBM_SongID],a
	xor	a
	ld	hl,GBM_RAM_Start+1
	ld	b,(GBM_RAM_End-GBM_RAM_Start+1)-2
.clearloop
	ld	[hl+],a
	dec	b
	jr	nz,.clearloop	
	inc	a
	ld	[GBM_ModuleTimer],a
	ld	[GBM_TickTimer],a
	
	ldh	[rNR52],a	; disable sound (clears all sound registers)
	or	$80
	ldh	[rNR52],a	; enable sound
	or	$7f
	ldh	[rNR51],a	; all channels to SO1+SO2
	xor	%10001000
	ldh	[rNR50],a	; master volume 7

	ld	a,[GBM_SongID]
	inc	a
	ld	[rROMB0],a
	ld	hl,$4000
	
	ld	a,[hl+]
	ld	[GBM_PatternCount],a
	ld	a,[hl+]
	ld	[GBM_PatTableSize],a
	ld	a,[hl+]
	ld	[GBM_ModuleSpeed],a
	ld	a,[hl+]
	ld	[GBM_TickSpeed],a
	ld	a,[hl+]
	ld	[GBM_SongDataOffset],a
	ld	a,[hl]
	ld	[GBM_SongDataOffset+1],a
	
	ld	a,$ff
	ld	[GBM_LastWave],a
	ld	a,1
	ld	[GBM_DoPlay],a
	ld	[GBM_CmdTick1],a
	ld	[GBM_CmdTick2],a
	ld	[GBM_CmdTick3],a
	ld	[GBM_CmdTick4],a
	sub	2
	ld	[GBM_PanFlags],a
	pop	hl
	pop	bc
	pop	af
	reti

; ================================

GBMod_Stop:
	xor	a
	ld	hl,GBM_RAM_Start
	ld	b,GBM_RAM_End-GBM_RAM_Start
.clearloop
	ld	[hl+],a
	dec	b
	jr	nz,.clearloop
	
	ldh	[rNR52],a	; disable sound (clears all sound registers)
	or	$80
	ldh	[rNR52],a	; enable sound
	or	$7f
	ldh	[rNR51],a	; all channels to SO1+SO2
	xor	%10001000
	ldh	[rNR50],a	; master volume 7
	ret
	
; ================================

GBMod_Update:
	ld	a,[GBM_DoPlay]
	and	a
	ret	z
	
	; anything that needs to be updated on a per-frame basis should be put here
	ld	e,0
	call	GBMod_DoVib	; pulse 1 vibrato
	inc	e
	call	GBMod_DoVib	; pulse 2 vibrato
	inc	e
	call	GBMod_DoVib	; pulse 3 vibrato
	; sample playback
	ld	a,[GBM_SamplePlaying]
	and	a
	call	nz,GBMod_UpdateSample
	
	ld	a,[GBM_TickTimer]
	dec	a
	ld	[GBM_TickTimer],a
	ret	nz
	ld	a,[GBM_TickSpeed]
	ld	[GBM_TickTimer],a
	ld	a,[GBM_ModuleTimer]
	dec	a
	ld	[GBM_ModuleTimer],a
	jp	nz,GBMod_UpdateCommands
	xor	a
	ld	[GBM_SpeedChanged],a
	ld	a,[GBM_ModuleSpeed]
	ld	[GBM_ModuleTimer],a
	ld	a,[GBM_SongID]
	inc	a
	ld	[rROMB0],a
	ld	hl,GBM_SongDataOffset
	ld	a,[hl+]
	ld	b,a
	ld	a,[hl]
	add	$40
	ld	h,a
	ld	l,b
	
	
	; get pattern offset
	ld	a,[GBM_CurrentPattern]
	and	a
	jr	z,.getRow
	
	add	a
	add	a
	add	h
	ld	h,a
.getRow
	ld	a,[GBM_CurrentRow]
	and	a
	jr	z,.readPatternData
	
	ld	b,a
	swap	a
	and	$f0
	ld	e,a
	ld	a,b
	swap	a
	and	$0f
	ld	d,a
	add	hl,de
	
.readPatternData
	; ch1 note
	ld	a,[hl+]
	push	af
	cp	$ff
	jr	z,.skip1
	cp	$fe
	jr	nz,.nocut1
	xor	a
	ld	[GBM_Vol1],a
.nocut1
	inc	hl
	ld	a,[hl]
	dec	hl
	cp	1
	jr	z,.noreset1
	cp	2
	jr	z,.noreset1
	call	GBM_ResetFreqOffset1
.noreset1
	pop	af
.freq1
	ld	[GBM_Note1],a
	ld	e,0
	call	GBMod_GetFreq2
	; ch1 volume
	ld	a,[GBM_SkipCH1]
	and	a
	jr	nz,.skipvol1
	ld	a,[GBM_Command1]
	cp	$a
	jr	z,.skipvol1
	ld	a,[hl]
	swap	a
	and	$f
	jr	z,.skipvol1
	ld	b,a
	rla
	rla
	rla
	ld	[GBM_Vol1],a
	ld	a,b
	swap	a
	ldh	[rNR12],a
	set	7,e
.skipvol1
	; ch1 pulse
	ld	a,[hl+]
	ld	b,a
	ld	a,[GBM_SkipCH1]
	and	a
	jr	nz,.skippulse1
	ld	a,b
	and	$f
	jr	z,.skippulse1
	dec	a
	ld	[GBM_Pulse1],a
	swap	a
	rla
	rla
	ldh	[rNR11],a
.skippulse1
	; ch1 command
	ld	a,[hl+]
	ld	[GBM_Command1],a
	; ch1 param
	ld	a,[hl+]
	ld	[GBM_Param1],a
	; update freq
	ld	a,[GBM_SkipCH1]
	and	a
	jr	nz,.ch2
	ld	a,d
	ldh	[rNR13],a
	ld	a,e
	ldh	[rNR14],a
	jr	.ch2
.skip1
	pop	af
	ld	a,[GBM_Note1]
	jr	.freq1

.ch2
	; ch2 note
	ld	a,[hl+]
	push	af
	cp	$ff
	jr	z,.skip2
	cp	$fe
	jr	nz,.nocut2
	xor	a
	ld	[GBM_Vol2],a
.nocut2
	inc	hl
	ld	a,[hl]
	dec	hl
	cp	1
	jr	z,.noreset2
	cp	2
	jr	z,.noreset2
	call	GBM_ResetFreqOffset2
.noreset2
	pop	af
.freq2
	ld	[GBM_Note2],a
	ld	e,1
	call	GBMod_GetFreq2
	; ch2 volume
	ld	a,[GBM_SkipCH2]
	and	a
	jr	nz,.skipvol2
	ld	a,[GBM_Command2]
	cp	$a
	jr	z,.skipvol2
	ld	a,[hl]
	swap	a
	and	$f
	jr	z,.skipvol2
	ld	b,a
	rla
	rla
	rla
	ld	[GBM_Vol2],a
	ld	a,b
	swap	a
	ldh	[rNR22],a
	set	7,e
.skipvol2
	; ch2 pulse
	ld	a,[hl+]
	ld	b,a
	ld	a,[GBM_SkipCH2]
	and	a
	jr	nz,.skippulse2
	ld	a,b
	and	$f
	jr	z,.skippulse2
	dec	a
	ld	[GBM_Pulse2],a
	swap	a
	rla
	rla
	ldh	[rNR21],a
.skippulse2
	; ch2 command
	ld	a,[hl+]
	ld	[GBM_Command2],a
	; ch2 param
	ld	a,[hl+]
	ld	[GBM_Param2],a
	; update freq
	ld	a,[GBM_SkipCH2]
	and	a
	jr	nz,.ch3
	ld	a,d
	ldh	[rNR23],a
	ld	a,e
	ldh	[rNR24],a
	jr	.ch3
.skip2
	pop	af
	ld	a,[GBM_Note2]
	jr	.freq2
	
.ch3
	; ch3 note
	ld	a,[GBM_SamplePlaying]
	and	a
	jp	nz,.sample3
.note3
	ld	a,[hl+]
	push	af
	cp	$ff
	jr	z,.skip3
	cp	$fe
	jr	nz,.nocut3
	xor	a
	ld	[GBM_Vol3],a
.nocut3
	inc	hl
	ld	a,[hl]
	dec	hl
	cp	1
	jr	z,.noreset3
	cp	2
	jr	z,.noreset3
	call	GBM_ResetFreqOffset3
.noreset3
	pop	af
	cp	$80
	jr	z,.playsample3
.freq3
	ld	[GBM_Note3],a
	ld	e,2
	call	GBMod_GetFreq2
	; ch3 volume
	ld	a,[hl]
	swap	a
	and	$f
	jr	z,.skipvol3
	ld	[GBM_Vol3],a
	call	GBMod_GetVol3
	ld	b,a
	ld	a,[GBM_OldVol3]
	cp	b
	jr	z,.skipvol3
	ld	a,[GBM_SkipCH3]
	and	a
	jr	nz,.skipvol3
	ld	a,b
	ldh	[rNR32],a
	set	7,e
.skipvol3
	ld	[GBM_OldVol3],a
	; ch3 wave
	ld	a,[hl+]
	dec	a
	and	$f
	cp	15
	jr	z,.continue3
	ld	b,a
	ld	a,[GBM_LastWave]
	cp	b
	jr	z,.continue3
	ld	a,b
	ld	[GBM_Wave3],a
	ld	[GBM_LastWave],a
	push	hl
	call	GBM_LoadWave
	set	7,e
	pop	hl
.continue3
	; ch3 command
	ld	a,[hl+]
	ld	[GBM_Command3],a
	; ch3 param
	ld	a,[hl+]
	ld	[GBM_Param3],a
	; update freq	
	ld	a,[GBM_SkipCH3]
	and	a
	jr	nz,.ch4
	ld	a,d
	ldh	[rNR33],a
	ld	a,e
	ldh	[rNR34],a
	jr	.ch4
.skip3
	pop	af
	ld	a,[GBM_Note3]
	jr	.freq3
.playsample3
	ld	a,[hl+]
	call	GBMod_PlaySample
	jr	.continue3
.sample3
	ld	a,[hl]
	cp	$ff
	jr	z,.nostopsample3
	xor	a
	ld	[GBM_SamplePlaying],a
	jp	.note3
.nostopsample3
	ld	a,l
	add	4
	ld	l,a
	jr	nc,.ch4
	inc	h
	
.ch4
	; ch4 note
	ld	a,[hl+]
	cp	$ff
	jr	z,.skip4
	cp	$fe
	jr	nz,.freq4
	xor	a
	ld	[GBM_Vol4],a
	
.freq4
	ld	[GBM_Note4],a
	push	hl
	ld	hl,NoiseTable
	add	l
	ld	l,a
	jr	nc,.nocarry
	inc	h
.nocarry
	ld	a,[hl+]
	ld	d,a
	pop	hl
	; ch4 volume
	ld	a,[GBM_SkipCH4]
	and	a
	jr	nz,.skipvol4
	inc	hl
	ld	a,[hl]
	dec	hl
	cp	$a
	jr	nz,.disablecmd4
.dovol4
	ld	a,[hl]
	swap	a
	and	$f
	ld	b,a
	rla
	rla
	rla
	ld	[GBM_Vol4],a
	ld	a,b
	swap	a
	ldh	[rNR42],a
	jr	.skipvol4
.disablecmd4
	xor	a
	ld	[GBM_Command4],a
	jr	.dovol4
.skipvol4
	; ch4 mode
	ld	a,[hl+]
	and	a
	jr	z,.nomode
	dec	a
	and	1
	ld	[GBM_Mode4],a
	and	a
	jr	z,.nomode
	set	3,d
.nomode
	; ch4 command
	ld	a,[hl+]
	ld	[GBM_Command4],a
	; ch4 param
	ld	a,[hl+]
	ld	[GBM_Param4],a
	; set freq
	ld	a,[GBM_SkipCH4]
	and	a
	jr	nz,.updateRow
	ld	a,d
	ldh	[rNR43],a
	ld	a,$80
	ldh	[rNR44],a
	jr	.updateRow
.skip4
	ld	a,[GBM_Note4]
	jr	.freq4
	
.updateRow
	call	GBM_ResetCommandTick
	ld	a,[GBM_CurrentRow]
	inc	a
	cp	64
	jr	z,.nextPattern
	ld	[GBM_CurrentRow],a
	jr	.done
.nextPattern
	xor	a
	ld	[GBM_CurrentRow],a
	ld	a,[GBM_PatTablePos]
	inc	a
	ld	b,a
	ld	a,[GBM_PatTableSize]
	cp	b
	jr	z,.loopSong
	ld	a,b
	ld	[GBM_PatTablePos],a
	jr	.setPattern
.loopSong
	xor	a
	ld	[GBM_PatTablePos],a
.setPattern
	ld	hl,$40f0
	add	l
	ld	l,a
	ld	a,[hl+]
	ld	[GBM_CurrentPattern],a
	
.done
	
GBMod_UpdateCommands:
	ld	a,$ff
	ld	[GBM_PanFlags],a
	; ch1
	ld	a,[GBM_Command1]
	ld	hl,.commandTable1
	add	a
	add	l
	ld	l,a
	jr	nc,.nocarry1
	inc	h
.nocarry1
	ld	a,[hl+]
	ld	h,[hl]
	ld	l,a
	jp	hl
	
.commandTable1
	dw	.arp1			; 0xy - arp
	dw	.slideup1		; 1xy - note slide up
	dw	.slidedown1		; 2xy - note slide down
	dw	.ch2			; 3xy - portamento (NYI)
	dw	.ch2			; 4xy - vibrato	(handled elsewhere)
	dw	.ch2			; 5xy - portamento + volume slide (NYI)
	dw	.ch2			; 6xy - vibrato + volume slide (NYI)
	dw	.ch2			; 7xy - tremolo (NYI)
	dw	.pan1			; 8xy - panning
	dw	.ch2			; 9xy - sample offset (won't be implemented)
	dw	.volslide1		; Axy - volume slide
	dw	.patjump1		; Bxy - pattern jump
	dw	.ch2			; Cxy - set volume (won't be implemented)
	dw	.patbreak1		; Dxy - pattern break
	dw	.ch2			; Exy - extended commands (NYI)
	dw	.speed1			; Fxy - set module speed
.arp1
	ld	a,[GBM_Param1]
	and	a
	jp	z,.ch2
	ld	a,[GBM_ArpTick1]
	inc	a
	cp	4
	jr	nz,.noresetarp1
	ld	a,1
.noresetarp1
	ld	[GBM_ArpTick1],a
	ld	a,[GBM_Param1]
	ld	b,a
	ld	a,[GBM_Note1]
	ld	c,a
	ld	a,[GBM_ArpTick1]
	dec	a
	call	GBMod_DoArp
	ld	a,[GBM_SkipCH1]
	and	a
	jp	nz,.ch2
	ld	a,d
	ldh	[rNR13],a
	ld	a,e
	ldh	[rNR14],a
	jp	.ch2
.slideup1
	ld	a,[GBM_Param1]
	ld	b,a
	ld	e,0
	call	GBMod_DoPitchSlide
	ld	a,[GBM_Note1]
	call	GBMod_GetFreq2
	jp	.dosetfreq1
.slidedown1
	; read tick speed
	ld	a,[GBM_Param1]
	ld	b,a
	ld	e,0
	call	GBMod_DoPitchSlide
	ld	a,[GBM_Note1]
	call	GBMod_GetFreq2
	jp	.dosetfreq1
.pan1
	ld	a,[GBM_Param1]
	cpl
	and	$11
	ld	b,a
	ld	a,[GBM_PanFlags]
	xor	b
	ld	[GBM_PanFlags],a
	jp	.ch2
.patbreak1
	ld	a,[GBM_Param1]
	ld	[GBM_CurrentRow],a
	ld	a,[GBM_PatTablePos]
	inc	a
	ld	[GBM_PatTablePos],a
	ld	hl,$40f0
	add	l
	ld	l,a
	ld	a,[hl]
	ld	[GBM_CurrentPattern],a
	xor	a
	ld	[GBM_Command1],a
	ld	[GBM_Param1],a
	jp	.done
.patjump1
	xor	a
	ld	[GBM_CurrentRow],a
	ld	a,[GBM_Param1]
	ld	[GBM_PatTablePos],a
	ld	hl,$40f0
	add	l
	ld	l,a
	ld	a,[hl]
	ld	[GBM_CurrentPattern],a
	xor	a
	ld	[GBM_Command1],a
	ld	[GBM_Param1],a
	jp	.done
.volslide1
	ld	a,[GBM_ModuleSpeed]
	ld	b,a
	ld	a,[GBM_ModuleTimer]
	cp	b
	jr	z,.ch2	; skip first tick
	
	ld	a,[GBM_Param1]
	cp	$10
	jr	c,.volslide1_dec
.volslide1_inc
	swap	a
	and	$f
	ld	b,a
	ld	a,[GBM_Vol1]
	add	b
	jr	.volslide1_nocarry
.volslide1_dec
	ld	b,a
	ld	a,[GBM_Vol1]
	sub	b
	jr	nc,.volslide1_nocarry
	xor	a
.volslide1_nocarry
	ld	[GBM_Vol1],a
	rra
	rra
	rra
	and	$f
	ld	b,a
	ld	a,[GBM_SkipCH1]
	and	a
	jr	nz,.ch2
	ld	a,b
	swap	a
	ld	[rNR12],a
	ld	a,[GBM_Note1]
	call	GBMod_GetFreq
	ld	a,[GBM_SkipCH1]
	and	a
	jr	nz,.ch2
	ld	a,d
	ldh	[rNR13],a
	ld	a,e
	or	$80
	ldh	[rNR14],a
	jr	.ch2
.dosetfreq1
	ld	a,[GBM_SkipCH1]
	and	a
	jr	nz,.ch2
	ld	a,d
	ldh	[rNR13],a
	ld	a,e
	ldh	[rNR14],a
	jr	.ch2
.speed1
	ld	a,[GBM_SpeedChanged]
	and	a
	jr	nz,.ch2
	ld	a,[GBM_Param1]
	ld	[GBM_ModuleSpeed],a
	ld	[GBM_ModuleTimer],a
	ld	a,1
	ld	[GBM_SpeedChanged],a
	
.ch2
	ld	a,[GBM_Command1]
	cp	4
	jr	nz,.novib1
	ld	a,[GBM_Note1]
	call	GBMod_GetFreq
	ld	h,d
	ld	l,e
	ld	a,[GBM_FreqOffset1]
	add	h
	ld	h,a
	jr	nc,.continue1
	inc	l
.continue1
	ld	a,[GBM_SkipCH1]
	and	a
	jr	nz,.novib1
	ld	a,h
	ldh	[rNR13],a
	ld	a,l
	ldh	[rNR14],a
.novib1
	
	ld	a,[GBM_Command2]
	ld	hl,.commandTable2
	add	a
	add	l
	ld	l,a
	jr	nc,.nocarry2
	inc	h
.nocarry2
	ld	a,[hl+]
	ld	h,[hl]
	ld	l,a
	jp	hl
	
.commandTable2
	dw	.arp2			; 0xy - arp
	dw	.slideup2		; 1xy - note slide up
	dw	.slidedown2		; 2xy - note slide down
	dw	.ch3			; 3xy - portamento (NYI)
	dw	.ch3			; 4xy - vibrato	(handled elsewhere)
	dw	.ch3			; 5xy - portamento + volume slide (NYI)
	dw	.ch3			; 6xy - vibrato + volume slide (NYI)
	dw	.ch3			; 7xy - tremolo (NYI)
	dw	.pan2			; 8xy - panning
	dw	.ch3			; 9xy - sample offset (won't be implemented)
	dw	.volslide2		; Axy - volume slide
	dw	.patjump2		; Bxy - pattern jump
	dw	.ch3			; Cxy - set volume (won't be implemented)
	dw	.patbreak2		; Dxy - pattern break
	dw	.ch3			; Exy - extended commands (NYI)
	dw	.speed2			; Fxy - set module speed
.arp2
	ld	a,[GBM_Param2]
	and	a
	jp	z,.ch3
	ld	a,[GBM_ArpTick2]
	inc	a
	cp	4
	jr	nz,.noresetarp2
	ld	a,1
.noresetarp2
	ld	[GBM_ArpTick2],a
	ld	a,[GBM_Param2]
	ld	b,a
	ld	a,[GBM_Note2]
	ld	c,a
	ld	a,[GBM_ArpTick2]
	dec	a
	call	GBMod_DoArp
	ld	a,[GBM_SkipCH2]
	and	a
	jp	nz,.ch3
	ld	a,d
	ldh	[rNR23],a
	ld	a,e
	ldh	[rNR24],a
	jp	.ch3
.slideup2
	ld	a,[GBM_Param2]
	ld	b,a
	ld	e,1
	call	GBMod_DoPitchSlide
	ld	a,[GBM_Note2]
	call	GBMod_GetFreq2
	jp	.dosetfreq2
.slidedown2
	; read tick speed
	ld	a,[GBM_Param2]
	ld	b,a
	ld	e,1
	call	GBMod_DoPitchSlide
	ld	a,[GBM_Note2]
	call	GBMod_GetFreq2
	jp	.dosetfreq2
.pan2
	ld	a,[GBM_Param2]
	cpl
	and	$11
	rla
	ld	b,a
	ld	a,[GBM_PanFlags]
	xor	b
	ld	[GBM_PanFlags],a
	jp	.ch3
.patbreak2
	ld	a,[GBM_Param2]
	ld	[GBM_CurrentRow],a
	ld	a,[GBM_PatTablePos]
	inc	a
	ld	[GBM_PatTablePos],a
	ld	hl,$40f0
	add	l
	ld	l,a
	ld	a,[hl]
	ld	[GBM_CurrentPattern],a
	xor	a
	ld	[GBM_Command2],a
	ld	[GBM_Param2],a
	jp	.done
.patjump2
	xor	a
	ld	[GBM_CurrentRow],a
	ld	a,[GBM_Param2]
	ld	[GBM_PatTablePos],a
	ld	hl,$40f0
	add	l
	ld	l,a
	ld	a,[hl]
	ld	[GBM_CurrentPattern],a
	xor	a
	ld	[GBM_Command2],a
	ld	[GBM_Param2],a
	jp	.done
.volslide2
	ld	a,[GBM_ModuleSpeed]
	ld	b,a
	ld	a,[GBM_ModuleTimer]
	cp	b
	jr	z,.ch3	; skip first tick

	ld	a,[GBM_Param2]
	cp	$10
	jr	c,.volslide2_dec
.volslide2_inc
	swap	a
	and	$f
	ld	b,a
	ld	a,[GBM_Vol2]
	add	b
	jr	.volslide2_nocarry
.volslide2_dec
	ld	b,a
	ld	a,[GBM_Vol2]
	sub	b
	jr	nc,.volslide2_nocarry
	xor	a
.volslide2_nocarry
	ld	[GBM_Vol2],a
	rra
	rra
	rra
	and	$f
	ld	b,a
	ld	a,[GBM_SkipCH2]
	and	a
	jr	nz,.ch3
	ld	a,b
	swap	a
	ld	[rNR22],a
	ld	a,[GBM_Note2]
	call	GBMod_GetFreq
	ld	a,[GBM_SkipCH2]
	and	a
	jr	nz,.ch3
	ld	a,d
	ldh	[rNR23],a
	ld	a,e
	or	$80
	ldh	[rNR24],a
	jr	.ch3
.dosetfreq2
	ld	a,[GBM_SkipCH2]
	and	a
	jr	nz,.ch3
	ld	a,d
	ldh	[rNR23],a
	ld	a,e
	ldh	[rNR24],a
	jr	.ch3
.speed2
	ld	a,[GBM_SpeedChanged]
	and	a
	jr	nz,.ch3
	ld	a,[GBM_Param2]
	ld	[GBM_ModuleSpeed],a
	ld	[GBM_ModuleTimer],a
	ld	a,1
	ld	[GBM_SpeedChanged],a
	
.ch3
	ld	a,[GBM_Command2]
	cp	4
	jr	nz,.novib2
	ld	a,[GBM_Note2]
	call	GBMod_GetFreq
	ld	h,d
	ld	l,e
	ld	a,[GBM_FreqOffset2]
	add	h
	ld	h,a
	jr	nc,.continue2
	inc	l
.continue2
	ld	a,[GBM_SkipCH2]
	and	a
	jr	nz,.novib2
	ld	a,h
	ldh	[rNR23],a
	ld	a,l
	ldh	[rNR24],a
.novib2

	ld	a,[GBM_Command3]
	ld	hl,.commandTable3
	add	a
	add	l
	ld	l,a
	jr	nc,.nocarry3
	inc	h
.nocarry3
	ld	a,[hl+]
	ld	h,[hl]
	ld	l,a
	jp	hl
	
.commandTable3
	dw	.arp3			; 0xy - arp
	dw	.slideup3		; 1xy - note slide up
	dw	.slidedown3		; 2xy - note slide down
	dw	.ch4			; 3xy - portamento (NYI)
	dw	.ch4			; 4xy - vibrato (handled elsewhere)
	dw	.ch4			; 5xy - portamento + volume slide (NYI)
	dw	.ch4			; 6xy - vibrato + volume slide (NYI)
	dw	.ch4			; 7xy - tremolo (doesn't apply for CH3)
	dw	.pan3			; 8xy - panning
	dw	.ch4			; 9xy - sample offset (won't be implemented)
	dw	.ch4			; Axy - volume slide (doesn't apply for CH3)
	dw	.patjump3		; Bxy - pattern jump
	dw	.ch4			; Cxy - set volume (won't be implemented)
	dw	.patbreak3		; Dxy - pattern break
	dw	.ch4			; Exy - extended commands (NYI)
	dw	.speed3			; Fxy - set module speed
	
.arp3
	ld	a,[GBM_Param3]
	and	a
	jp	z,.ch4
	ld	a,[GBM_ArpTick3]
	inc	a
	cp	4
	jr	nz,.noresetarp3
	ld	a,1
.noresetarp3
	ld	[GBM_ArpTick3],a
	ld	a,[GBM_Param3]
	ld	b,a
	ld	a,[GBM_Note3]
	ld	c,a
	ld	a,[GBM_ArpTick3]
	dec	a
	call	GBMod_DoArp
	ld	a,[GBM_SkipCH3]
	and	a
	jp	nz,.ch4
	ld	a,d
	ldh	[rNR33],a
	ld	a,e
	ldh	[rNR34],a
	jp	.ch4
.slideup3
	ld	a,[GBM_Param3]
	ld	b,a
	ld	e,2
	call	GBMod_DoPitchSlide
	ld	a,[GBM_Note3]
	call	GBMod_GetFreq2
	jp	.dosetfreq3
.slidedown3
	; read tick speed
	ld	a,[GBM_Param3]
	ld	b,a
	ld	e,2
	call	GBMod_DoPitchSlide
	ld	a,[GBM_Note3]
	call	GBMod_GetFreq2
	jp	.dosetfreq3
.pan3
	ld	a,[GBM_Param3]
	cpl
	and	$11
	rla
	ld	b,a
	ld	a,[GBM_PanFlags]
	xor	b
	ld	[GBM_PanFlags],a
	jp	.ch4
.patbreak3
	ld	a,[GBM_Param3]
	ld	[GBM_CurrentRow],a
	ld	a,[GBM_PatTablePos]
	inc	a
	ld	[GBM_PatTablePos],a
	ld	hl,$40f0
	add	l
	ld	l,a
	ld	a,[hl]
	ld	[GBM_CurrentPattern],a
	xor	a
	ld	[GBM_Command3],a
	ld	[GBM_Param3],a
	jp	.done
.patjump3
	xor	a
	ld	[GBM_CurrentRow],a
	ld	a,[GBM_Param3]
	ld	[GBM_PatTablePos],a
	ld	hl,$40f0
	add	l
	ld	l,a
	ld	a,[hl]
	ld	[GBM_CurrentPattern],a
	xor	a
	ld	[GBM_Command3],a
	ld	[GBM_Param3],a
	jp	.done
.dosetfreq3
	ld	a,[GBM_SkipCH3]
	and	a
	jr	nz,.ch4
	ld	a,d
	ldh	[rNR33],a
	ld	a,e
	ldh	[rNR34],a
	jr	.ch4
.speed3
	ld	a,[GBM_SpeedChanged]
	and	a
	jr	nz,.ch4
	ld	a,[GBM_Param3]
	ld	[GBM_ModuleSpeed],a
	ld	[GBM_ModuleTimer],a
	ld	a,1
	ld	[GBM_SpeedChanged],a

.ch4
	ld	a,[GBM_Command3]
	cp	4
	jr	nz,.novib3
	ld	a,[GBM_SkipCH3]
	and	a
	jp	nz,.novib3
	ld	a,[GBM_Note3]
	call	GBMod_GetFreq
	ld	h,d
	ld	l,e
	ld	a,[GBM_FreqOffset3]
	add	h
	ld	h,a
	jr	nc,.continue3
	inc	l
.continue3
	ld	a,h
	ldh	[rNR33],a
	ld	a,l
	ldh	[rNR34],a
.novib3


	ld	a,[GBM_Command4]
	ld	hl,.commandTable4
	add	a
	add	l
	ld	l,a
	jr	nc,.nocarry4
	inc	h
.nocarry4
	ld	a,[hl+]
	ld	h,[hl]
	ld	l,a
	jp	hl
	
.commandTable4
	dw	.arp4			; 0xy - arp
	dw	.done			; 1xy - note slide up (doesn't apply for CH4)
	dw	.done			; 2xy - note slide down (doesn't apply for CH4)
	dw	.done			; 3xy - portamento (doesn't apply for CH4)
	dw	.done			; 4xy - vibrato (doesn't apply for CH4)
	dw	.done			; 5xy - portamento + volume slide (doesn't apply for CH4)
	dw	.done			; 6xy - vibrato + volume slide (doesn't apply for CH4)
	dw	.done			; 7xy - tremolo (NYI)
	dw	.pan4			; 8xy - panning
	dw	.done			; 9xy - sample offset (won't be implemented)
	dw	.volslide4		; Axy - volume slide
	dw	.patjump4		; Bxy - pattern jump
	dw	.done			; Cxy - set volume (won't be implemented)
	dw	.patbreak4		; Dxy - pattern break
	dw	.done			; Exy - extended commands (NYI)
	dw	.speed4			; Fxy - set module speed
.arp4
	ld	a,[GBM_Param4]
	and	a
	jp	z,.done
	ld	a,[GBM_ArpTick4]
	inc	a
	cp	4
	jr	nz,.noresetarp4
	ld	a,1
.noresetarp4
	ld	[GBM_ArpTick4],a
	ld	a,[GBM_Param4]
	ld	b,a
	ld	a,[GBM_Note4]
	ld	c,a
	ld	a,[GBM_ArpTick4]
	dec	a
	call	GBMod_DoArp4
	ld	hl,NoiseTable
	add	l
	ld	l,a
	jr	nc,.nocarry5
	inc	h
.nocarry5
	ld	a,[hl]
	ldh	[rNR43],a
	jp	.done
.pan4
	ld	a,[GBM_Param4]
	cpl
	and	$11
	ld	b,a
	ld	a,[GBM_PanFlags]
	xor	b
	ld	[GBM_PanFlags],a
	jp	.done
.patbreak4
	ld	a,[GBM_Param4]
	ld	[GBM_CurrentRow],a
	ld	a,[GBM_PatTablePos]
	inc	a
	ld	[GBM_PatTablePos],a
	ld	hl,$40f0
	add	l
	ld	l,a
	ld	a,[hl+]
	ld	[GBM_CurrentPattern],a
	xor	a
	ld	[GBM_Command4],a
	ld	[GBM_Param4],a
	jr	.done
.patjump4
	xor	a
	ld	[GBM_CurrentRow],a
	ld	a,[GBM_Param4]
	ld	[GBM_PatTablePos],a
	ld	hl,$40f0
	add	l
	ld	l,a
	ld	a,[hl]
	ld	[GBM_CurrentPattern],a
	xor	a
	ld	[GBM_Command4],a
	ld	[GBM_Param4],a
	jr	.done
.volslide4
	ld	a,[GBM_ModuleSpeed]
	ld	b,a
	ld	a,[GBM_ModuleTimer]
	cp	b
	jr	z,.done	; skip first tick

	ld	a,[GBM_Param4]
	cp	$10
	jr	c,.volslide4_dec
.volslide4_inc
	swap	a
	and	$f
	ld	b,a
	ld	a,[GBM_Vol4]
	add	b
	jr	.volslide4_nocarry
.volslide4_dec
	ld	b,a
	ld	a,[GBM_Vol4]
	sub	b
	jr	nc,.volslide4_nocarry
	xor	a
.volslide4_nocarry
	ld	[GBM_Vol4],a
	rra
	rra
	rra
	and	$f
	ld	b,a
	ld	a,[GBM_SkipCH4]
	and	a
	jr	nz,.done
	ld	a,b
	swap	a
	ld	[rNR42],a
	ld	a,[GBM_Note4]
	call	GBMod_GetFreq
	ld	a,[GBM_SkipCH4]
	and	a
	jr	nz,.done
	or	$80
	ldh	[rNR44],a
	jr	.done	
.speed4
	ld	a,[GBM_SpeedChanged]
	and	a
	jr	nz,.done
	ld	a,[GBM_Param4]
	ld	[GBM_ModuleSpeed],a
	ld	[GBM_ModuleTimer],a
	ld	a,1
	ld	[GBM_SpeedChanged],a
	
.done
	ld	a,[GBM_PanFlags]
	ldh	[rNR51],a

	ld	a,1
	ld	[rROMB0],a
	ret
	
GBMod_DoArp:
	call	GBMod_DoArp4
	jp	GBMod_GetFreq
	ret

GBMod_DoArp4:
	and	a
	jr	z,.arp0
	dec	a
	jr	z,.arp1
	dec	a
	jr	z,.arp2
	ret	; default case
.arp0
	xor	a
	ld	b,a
	jr	.getNote
.arp1
	ld	a,b
	swap	a
	and	$f
	ld	b,a
	jr	.getNote
.arp2
	ld	a,b
	and	$f
	ld	b,a
.getNote
	ld	a,c
	add	b
	ret
	
; Input: e = current channel
GBMod_DoVib:
	ld	hl,GBM_Command1
	call	GBM_AddChannelID
	ld	a,[hl]
	cp	4
	ret	nz	; return if vibrato is disabled
	; get vibrato tick
	ld	hl,GBM_Param1
	call	GBM_AddChannelID
	ld	a,[hl]
	push	af
	swap	a
	cpl
	and	$f
	ld	b,a
	ld	hl,GBM_CmdTick1
	call	GBM_AddChannelID
	ld	a,[hl]
	and	a
	jr	z,.noexit
	pop	af
	dec	[hl]
	ret
.noexit
	ld	[hl],b
	; get vibrato depth
	pop	af
	and	$f
	ld	d,a
	ld	hl,GBM_ArpTick1
	call	GBM_AddChannelID
	ld	a,[hl]
	xor	1
	ld	[hl],a
	and	a
	jr	nz,.noreset2
	ld	hl,GBM_FreqOffset1
	call	GBM_AddChannelID16
	ld	[hl],0
	ret
.noreset2
	ld	hl,GBM_FreqOffset1
	call	GBM_AddChannelID16
	ld	a,d
	rr	d
	add	d
	ld	[hl],a
	ret

; INPUT: e=channel ID
GBMod_DoPitchSlide:
	push	bc
	push	de
	ld	hl,GBM_Command1
	call	GBM_AddChannelID
	ld	a,[hl]
	cp	1
	jr	z,.slideup
	cp	2
	jr	nz,.done
.slidedown
	call	.getparam
	xor	a
	sub	c
	ld	c,a
	ld	a,0
	sbc	b
	ld	b,a
	jr	.setoffset
.slideup
	call	.getparam
.setoffset
	add	hl,bc
	add	hl,bc
	add	hl,bc
	ld	b,h
	ld	c,l
	ld	hl,GBM_FreqOffset1
	call	GBM_AddChannelID16
	ld	a,c
	ld	[hl+],a
	ld	a,b
	ld	[hl],a
	call	.getparam
	jr	.done
.getparam
	ld	hl,GBM_Param1
	call	GBM_AddChannelID
	ld	a,[hl]
	ld	c,a
	ld	b,0
	ld	hl,GBM_FreqOffset1
	call	GBM_AddChannelID16
	ld	a,[hl+]
	ld	h,[hl]
	ld	l,a
	ret
.done
	pop	de
	pop	bc
	ret
	
GBM_AddChannelID:
	ld	a,e
GBM_AddChannelID_skip:
	add	l
	ld	l,a
	ret	nc
	inc	h
	ret
	
GBM_AddChannelID16:
	ld	a,e
	add	a
	jr	GBM_AddChannelID_skip
	
GBM_ResetCommandTick:
.ch1
	ld	a,[GBM_Command1]
	cp	4
	jr	z,.ch2
	xor	a
	ld	[GBM_CmdTick1],a
.ch2
	ld	a,[GBM_Command2]
	cp	4
	jr	z,.ch3
	xor	a
	ld	[GBM_CmdTick2],a
.ch3
	ld	a,[GBM_Command3]
	cp	4
	jr	z,.ch4
	xor	a
	ld	[GBM_CmdTick3],a
.ch4
	xor	a
	ld	[GBM_CmdTick4],a
	ret
	
	
; input:  a = note id
;		  b = channel ID
; output: de = frequency
GBMod_GetFreq:
	push	af
	push	bc
	push	hl
	ld	de,0
	ld	l,a
	ld	h,0
	jr	GBMod_DoGetFreq
GBMod_GetFreq2:
	push	af
	push	bc
	push	hl
	ld	c,a
	ld	hl,GBM_FreqOffset1
	call	GBM_AddChannelID16
	ld	a,[hl+]
	ld	d,[hl]
	ld	e,a
	ld	l,c
	ld	h,0
GBMod_DoGetFreq:
	add	hl,hl	; x1
	add	hl,hl	; x2
	add	hl,hl	; x4
	add	hl,hl	; x8
	add	hl,hl	; x16
	add	hl,hl	; x32
	ld	b,h
	ld	c,l
	ld	hl,FreqTable
	add	hl,bc
	add	hl,de
	ld	a,[hl+]
	ld	d,a
	ld	a,[hl]
	ld	e,a
	pop	hl
	pop	bc
	pop	af
	ret
	
GBM_ResetFreqOffset1:
	push	af
	push	hl
	xor	a
	ld	[GBM_Command1],a
	ld	[GBM_Param1],a
	ld	hl,GBM_FreqOffset1
	jr	GBM_DoResetFreqOffset
GBM_ResetFreqOffset2:
	push	af
	push	hl
	xor	a
	ld	[GBM_Command2],a
	ld	[GBM_Param2],a
	ld	hl,GBM_FreqOffset2
	jr	GBM_DoResetFreqOffset
GBM_ResetFreqOffset3:
	push	af
	push	hl
	xor	a
	ld	[GBM_Command3],a
	ld	[GBM_Param3],a
	ld	hl,GBM_FreqOffset3
GBM_DoResetFreqOffset:
	ld	[hl+],a
	ld	[hl],a
	pop	hl
	pop	af
	ret
	
GBMod_GetVol3:
	push	hl
	ld	hl,WaveVolTable
	add	l
	ld	l,a
	jr	nc,.nocarry
	inc	h
.nocarry
	ld	a,[hl]
	pop	hl
	ret

; INPUT: a = wave ID
GBM_LoadWave:
	and	$f
	add	a
	ld	hl,GBM_PulseWaves
	add	l
	ld	l,a
	jr	nc,.nocarry2
	inc	h
.nocarry2
	ld	a,[hl+]
	ld	h,[hl]
	ld	l,a
GBM_CopyWave:
	ldh	a,[rNR51]
	push	af
	and	%10111011
	ldh	[rNR51],a	; prevent spike on GBA
	xor	a
	ldh	[rNR30],a
	ld	bc,$1030
.loop
	ld	a,[hl+]
	ld	[c],a
	inc	c
	dec	b
	jr	nz,.loop
	ld	a,%10000000
	ldh	[rNR30],a
	pop	af
	ldh	[rNR51],a
	ret

; INPUT: a = sample ID
GBMod_PlaySample:
	ld	[GBM_SampleID],a
	push	hl
	ld	c,a
	ld	b,0
	ld	hl,GBM_SampleTable
	add	hl,bc
	add	hl,bc
	ld	a,[hl+]
	ld	h,[hl]
	ld	l,a
	; bank
	ld	a,[hl+]
	ld	[GBM_SampleBank],a
	; pointer
	ld	a,[hl+]
	ld	[GBM_SamplePointer],a
	ld	a,[hl+]
	ld	[GBM_SamplePointer+1],a
	; counter
	ld	a,[hl+]
	ld	[GBM_SampleCounter],a
	ld	a,[hl]
	ld	[GBM_SampleCounter+1],a
	ld	a,1
	ld	[GBM_SamplePlaying],a
	jr	GBMod_UpdateSample2
	
GBMod_UpdateSample:
	push	hl
GBMod_UpdateSample2:
	ld	a,[GBM_SamplePlaying]
	and	a
	ret	z	; return if sample not playing
	ld	a,[GBM_SampleBank]
	ld	[rROMB0],a
	ld	hl,GBM_SamplePointer
	ld	a,[hl+]
	ld	h,[hl]
	ld	l,a
	call	GBM_CopyWave
	ld	a,%00100000
	ldh	[rNR32],a
	ld	a,$d4
	ldh	[rNR33],a
	ld	a,$83
	ldh	[rNR34],a
	ld	a,[GBM_SampleCounter]
	sub	16
	ld	[GBM_SampleCounter],a
	jr	nc,.skiphigh
	ld	a,[GBM_SampleCounter+1]
	dec	a
	ld	[GBM_SampleCounter+1],a
.skiphigh
	ld	b,a
	ld	a,l
	ld	[GBM_SamplePointer],a
	ld	a,h
	ld	[GBM_SamplePointer+1],a
	ld	a,[GBM_SampleCounter+1]
	ld	b,a
	ld	a,[GBM_SampleCounter]
	or	b
	jr	nz,.done
	xor	a
	ld	[GBM_SamplePlaying],a
	ld	a,[GBM_SongID]
	inc	a
	ld	[rROMB0],a
	ld	a,[GBM_Wave3]
	call	GBM_LoadWave
	pop	hl
	ret
.done
	ld	a,[GBM_SongID]
	inc	a
	ld	[rROMB0],a
	pop	hl
	ret

GBM_PulseWaves:
	dw	wave_Pulse125,wave_Pulse25,wave_Pulse50,wave_Pulse75
	dw	$4030,$4040,$4050,$4060
	dw	$4070,$4080,$4090,$40a0
	dw	$40b0,$40c0,$40d0,$40e0
	
; evil optimization hax for pulse wave data
; should result in the following:
; wave_Pulse75:  $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00
; wave_Pulse50:  $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00
; wave_Pulse25:  $ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; wave_Pulse125: $ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
wave_Pulse75:	db	$ff,$ff,$ff,$ff
wave_Pulse50:	db	$ff,$ff,$ff,$ff
wave_Pulse25:	db	$ff,$ff
wave_Pulse125:	db	$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; last four bytes read from WaveVolumeTable
	
WaveVolTable:	
	db	$00,$00,$00,$00,$60,$60,$60,$60,$40,$40,$40,$40,$20,$20,$20,$20

; ================================

FreqTable:
	dw $0022,$0026,$002a,$002d,$0031,$0034,$0038,$003c
	dw $003f,$0043,$0046,$004a,$004e,$0051,$0055,$0058
	dw $005c,$005f,$0063,$0066,$006a,$006d,$0071,$0074
	dw $0078,$007b,$007f,$0082,$0086,$0089,$008d,$0090
	dw $0093,$0097,$009a,$009e,$00a1,$00a4,$00a8,$00ab
	dw $00af,$00b2,$00b5,$00b9,$00bc,$00bf,$00c3,$00c6
	dw $00ca,$00cd,$00d0,$00d3,$00d7,$00da,$00dd,$00e1
	dw $00e4,$00e7,$00eb,$00ee,$00f1,$00f4,$00f8,$00fb
	dw $00fe,$0101,$0105,$0108,$010b,$010e,$0111,$0115
	dw $0118,$011b,$011e,$0121,$0125,$0128,$012b,$012e
	dw $0131,$0134,$0137,$013b,$013e,$0141,$0144,$0147
	dw $014a,$014d,$0150,$0153,$0157,$015a,$015d,$0160
	dw $0163,$0166,$0169,$016c,$016f,$0172,$0175,$0178
	dw $017b,$017e,$0181,$0184,$0187,$018a,$018d,$0190
	dw $0193,$0196,$0199,$019c,$019f,$01a2,$01a5,$01a8
	dw $01ab,$01ad,$01b0,$01b3,$01b6,$01b9,$01bc,$01bf
	dw $01c2,$01c5,$01c8,$01ca,$01cd,$01d0,$01d3,$01d6
	dw $01d9,$01dc,$01de,$01e1,$01e4,$01e7,$01ea,$01ed
	dw $01ef,$01f2,$01f5,$01f8,$01fa,$01fd,$0200,$0203
	dw $0206,$0208,$020b,$020e,$0211,$0213,$0216,$0219
	dw $021c,$021e,$0221,$0224,$0226,$0229,$022c,$022e
	dw $0231,$0234,$0236,$0239,$023c,$023e,$0241,$0244
	dw $0246,$0249,$024c,$024e,$0251,$0254,$0256,$0259
	dw $025b,$025e,$0261,$0263,$0266,$0268,$026b,$026e
	dw $0270,$0273,$0275,$0278,$027a,$027d,$0280,$0282
	dw $0285,$0287,$028a,$028c,$028f,$0291,$0294,$0296
	dw $0299,$029b,$029e,$02a0,$02a3,$02a5,$02a8,$02aa
	dw $02ad,$02af,$02b1,$02b4,$02b6,$02b9,$02bb,$02be
	dw $02c0,$02c3,$02c5,$02c7,$02ca,$02cc,$02cf,$02d1
	dw $02d3,$02d6,$02d8,$02db,$02dd,$02df,$02e2,$02e4
	dw $02e6,$02e9,$02eb,$02ed,$02f0,$02f2,$02f4,$02f7
	dw $02f9,$02fb,$02fe,$0300,$0302,$0305,$0307,$0309
	dw $030c,$030e,$0310,$0312,$0315,$0317,$0319,$031b
	dw $031e,$0320,$0322,$0324,$0327,$0329,$032b,$032d
	dw $0330,$0332,$0334,$0336,$0338,$033b,$033d,$033f
	dw $0341,$0343,$0346,$0348,$034a,$034c,$034e,$0351
	dw $0353,$0355,$0357,$0359,$035b,$035d,$0360,$0362
	dw $0364,$0366,$0368,$036a,$036c,$036e,$0371,$0373
	dw $0375,$0377,$0379,$037b,$037d,$037f,$0381,$0383
	dw $0385,$0388,$038a,$038c,$038e,$0390,$0392,$0394
	dw $0396,$0398,$039a,$039c,$039e,$03a0,$03a2,$03a4
	dw $03a6,$03a8,$03aa,$03ac,$03ae,$03b0,$03b2,$03b4
	dw $03b6,$03b8,$03ba,$03bc,$03be,$03c0,$03c2,$03c4
	dw $03c6,$03c8,$03ca,$03cc,$03ce,$03d0,$03d1,$03d3
	dw $03d5,$03d7,$03d9,$03db,$03dd,$03df,$03e1,$03e3
	dw $03e5,$03e7,$03e8,$03ea,$03ec,$03ee,$03f0,$03f2
	dw $03f4,$03f6,$03f7,$03f9,$03fb,$03fd,$03ff,$0401
	dw $0403,$0404,$0406,$0408,$040a,$040c,$040e,$040f
	dw $0411,$0413,$0415,$0417,$0418,$041a,$041c,$041e
	dw $0420,$0421,$0423,$0425,$0427,$0429,$042a,$042c
	dw $042e,$0430,$0431,$0433,$0435,$0437,$0438,$043a
	dw $043c,$043e,$043f,$0441,$0443,$0445,$0446,$0448
	dw $044a,$044b,$044d,$044f,$0451,$0452,$0454,$0456
	dw $0457,$0459,$045b,$045c,$045e,$0460,$0461,$0463
	dw $0465,$0466,$0468,$046a,$046b,$046d,$046f,$0470
	dw $0472,$0474,$0475,$0477,$0479,$047a,$047c,$047d
	dw $047f,$0481,$0482,$0484,$0485,$0487,$0489,$048a
	dw $048c,$048d,$048f,$0491,$0492,$0494,$0495,$0497
	dw $0499,$049a,$049c,$049d,$049f,$04a0,$04a2,$04a4
	dw $04a5,$04a7,$04a8,$04aa,$04ab,$04ad,$04ae,$04b0
	dw $04b1,$04b3,$04b4,$04b6,$04b7,$04b9,$04bb,$04bc
	dw $04be,$04bf,$04c1,$04c2,$04c4,$04c5,$04c7,$04c8
	dw $04c9,$04cb,$04cc,$04ce,$04cf,$04d1,$04d2,$04d4
	dw $04d5,$04d7,$04d8,$04da,$04db,$04dd,$04de,$04df
	dw $04e1,$04e2,$04e4,$04e5,$04e7,$04e8,$04ea,$04eb
	dw $04ec,$04ee,$04ef,$04f1,$04f2,$04f3,$04f5,$04f6
	dw $04f8,$04f9,$04fa,$04fc,$04fd,$04ff,$0500,$0501
	dw $0503,$0504,$0506,$0507,$0508,$050a,$050b,$050c
	dw $050e,$050f,$0510,$0512,$0513,$0515,$0516,$0517
	dw $0519,$051a,$051b,$051d,$051e,$051f,$0521,$0522
	dw $0523,$0525,$0526,$0527,$0528,$052a,$052b,$052c
	dw $052e,$052f,$0530,$0532,$0533,$0534,$0536,$0537
	dw $0538,$0539,$053b,$053c,$053d,$053e,$0540,$0541
	dw $0542,$0544,$0545,$0546,$0547,$0549,$054a,$054b
	dw $054c,$054e,$054f,$0550,$0551,$0553,$0554,$0555
	dw $0556,$0557,$0559,$055a,$055b,$055c,$055e,$055f
	dw $0560,$0561,$0562,$0564,$0565,$0566,$0567,$0568
	dw $056a,$056b,$056c,$056d,$056e,$0570,$0571,$0572
	dw $0573,$0574,$0576,$0577,$0578,$0579,$057a,$057b
	dw $057d,$057e,$057f,$0580,$0581,$0582,$0583,$0585
	dw $0586,$0587,$0588,$0589,$058a,$058b,$058d,$058e
	dw $058f,$0590,$0591,$0592,$0593,$0594,$0596,$0597
	dw $0598,$0599,$059a,$059b,$059c,$059d,$059e,$05a0
	dw $05a1,$05a2,$05a3,$05a4,$05a5,$05a6,$05a7,$05a8
	dw $05a9,$05aa,$05ac,$05ad,$05ae,$05af,$05b0,$05b1
	dw $05b2,$05b3,$05b4,$05b5,$05b6,$05b7,$05b8,$05b9
	dw $05ba,$05bb,$05bc,$05be,$05bf,$05c0,$05c1,$05c2
	dw $05c3,$05c4,$05c5,$05c6,$05c7,$05c8,$05c9,$05ca
	dw $05cb,$05cc,$05cd,$05ce,$05cf,$05d0,$05d1,$05d2
	dw $05d3,$05d4,$05d5,$05d6,$05d7,$05d8,$05d9,$05da
	dw $05db,$05dc,$05dd,$05de,$05df,$05e0,$05e1,$05e2
	dw $05e3,$05e4,$05e5,$05e6,$05e7,$05e8,$05e9,$05ea
	dw $05eb,$05ec,$05ed,$05ee,$05ef,$05ef,$05f0,$05f1
	dw $05f2,$05f3,$05f4,$05f5,$05f6,$05f7,$05f8,$05f9
	dw $05fa,$05fb,$05fc,$05fd,$05fe,$05ff,$05ff,$0600
	dw $0601,$0602,$0603,$0604,$0605,$0606,$0607,$0608
	dw $0609,$060a,$060a,$060b,$060c,$060d,$060e,$060f
	dw $0610,$0611,$0612,$0612,$0613,$0614,$0615,$0616
	dw $0617,$0618,$0619,$061a,$061a,$061b,$061c,$061d
	dw $061e,$061f,$0620,$0621,$0621,$0622,$0623,$0624
	dw $0625,$0626,$0627,$0627,$0628,$0629,$062a,$062b
	dw $062c,$062d,$062d,$062e,$062f,$0630,$0631,$0632
	dw $0632,$0633,$0634,$0635,$0636,$0637,$0637,$0638
	dw $0639,$063a,$063b,$063b,$063c,$063d,$063e,$063f
	dw $0640,$0640,$0641,$0642,$0643,$0644,$0644,$0645
	dw $0646,$0647,$0648,$0648,$0649,$064a,$064b,$064c
	dw $064c,$064d,$064e,$064f,$064f,$0650,$0651,$0652
	dw $0653,$0653,$0654,$0655,$0656,$0656,$0657,$0658
	dw $0659,$0659,$065a,$065b,$065c,$065c,$065d,$065e
	dw $065f,$0660,$0660,$0661,$0662,$0663,$0663,$0664
	dw $0665,$0665,$0666,$0667,$0668,$0668,$0669,$066a
	dw $066b,$066b,$066c,$066d,$066e,$066e,$066f,$0670
	dw $0670,$0671,$0672,$0673,$0673,$0674,$0675,$0675
	dw $0676,$0677,$0678,$0678,$0679,$067a,$067a,$067b
	dw $067c,$067d,$067d,$067e,$067f,$067f,$0680,$0681
	dw $0681,$0682,$0683,$0683,$0684,$0685,$0686,$0686
	dw $0687,$0688,$0688,$0689,$068a,$068a,$068b,$068c
	dw $068c,$068d,$068e,$068e,$068f,$0690,$0690,$0691
	dw $0692,$0692,$0693,$0694,$0694,$0695,$0696,$0696
	dw $0697,$0698,$0698,$0699,$0699,$069a,$069b,$069b
	dw $069c,$069d,$069d,$069e,$069f,$069f,$06a0,$06a1
	dw $06a1,$06a2,$06a2,$06a3,$06a4,$06a4,$06a5,$06a6
	dw $06a6,$06a7,$06a7,$06a8,$06a9,$06a9,$06aa,$06ab
	dw $06ab,$06ac,$06ac,$06ad,$06ae,$06ae,$06af,$06af
	dw $06b0,$06b1,$06b1,$06b2,$06b2,$06b3,$06b4,$06b4
	dw $06b5,$06b5,$06b6,$06b7,$06b7,$06b8,$06b8,$06b9
	dw $06ba,$06ba,$06bb,$06bb,$06bc,$06bd,$06bd,$06be
	dw $06be,$06bf,$06bf,$06c0,$06c1,$06c1,$06c2,$06c2
	dw $06c3,$06c3,$06c4,$06c5,$06c5,$06c6,$06c6,$06c7
	dw $06c7,$06c8,$06c9,$06c9,$06ca,$06ca,$06cb,$06cb
	dw $06cc,$06cc,$06cd,$06ce,$06ce,$06cf,$06cf,$06d0
	dw $06d0,$06d1,$06d1,$06d2,$06d3,$06d3,$06d4,$06d4
	dw $06d5,$06d5,$06d6,$06d6,$06d7,$06d7,$06d8,$06d8
	dw $06d9,$06da,$06da,$06db,$06db,$06dc,$06dc,$06dd
	dw $06dd,$06de,$06de,$06df,$06df,$06e0,$06e0,$06e1
	dw $06e1,$06e2,$06e2,$06e3,$06e3,$06e4,$06e4,$06e5
	dw $06e5,$06e6,$06e6,$06e7,$06e8,$06e8,$06e9,$06e9
	dw $06ea,$06ea,$06eb,$06eb,$06ec,$06ec,$06ed,$06ed
	dw $06ee,$06ee,$06ef,$06ef,$06ef,$06f0,$06f0,$06f1
	dw $06f1,$06f2,$06f2,$06f3,$06f3,$06f4,$06f4,$06f5
	dw $06f5,$06f6,$06f6,$06f7,$06f7,$06f8,$06f8,$06f9
	dw $06f9,$06fa,$06fa,$06fb,$06fb,$06fc,$06fc,$06fc
	dw $06fd,$06fd,$06fe,$06fe,$06ff,$06ff,$0700,$0700
	dw $0701,$0701,$0702,$0702,$0702,$0703,$0703,$0704
	dw $0704,$0705,$0705,$0706,$0706,$0707,$0707,$0707
	dw $0708,$0708,$0709,$0709,$070a,$070a,$070b,$070b
	dw $070b,$070c,$070c,$070d,$070d,$070e,$070e,$070f
	dw $070f,$070f,$0710,$0710,$0711,$0711,$0712,$0712
	dw $0712,$0713,$0713,$0714,$0714,$0715,$0715,$0715
	dw $0716,$0716,$0717,$0717,$0718,$0718,$0718,$0719
	dw $0719,$071a,$071a,$071a,$071b,$071b,$071c,$071c
	dw $071c,$071d,$071d,$071e,$071e,$071f,$071f,$071f
	dw $0720,$0720,$0721,$0721,$0721,$0722,$0722,$0723
	dw $0723,$0723,$0724,$0724,$0725,$0725,$0725,$0726
	dw $0726,$0727,$0727,$0727,$0728,$0728,$0728,$0729
	dw $0729,$072a,$072a,$072a,$072b,$072b,$072c,$072c
	dw $072c,$072d,$072d,$072d,$072e,$072e,$072f,$072f
	dw $072f,$0730,$0730,$0731,$0731,$0731,$0732,$0732
	dw $0732,$0733,$0733,$0733,$0734,$0734,$0735,$0735
	dw $0735,$0736,$0736,$0736,$0737,$0737,$0738,$0738
	dw $0738,$0739,$0739,$0739,$073a,$073a,$073a,$073b
	dw $073b,$073b,$073c,$073c,$073d,$073d,$073d,$073e
	dw $073e,$073e,$073f,$073f,$073f,$0740,$0740,$0740
	dw $0741,$0741,$0741,$0742,$0742,$0742,$0743,$0743
	dw $0743,$0744,$0744,$0744,$0745,$0745,$0745,$0746
	dw $0746,$0746,$0747,$0747,$0747,$0748,$0748,$0748
	dw $0749,$0749,$0749,$074a,$074a,$074a,$074b,$074b
	dw $074b,$074c,$074c,$074c,$074d,$074d,$074d,$074e
	dw $074e,$074e,$074f,$074f,$074f,$0750,$0750,$0750
	dw $0751,$0751,$0751,$0752,$0752,$0752,$0752,$0753
	dw $0753,$0753,$0754,$0754,$0754,$0755,$0755,$0755
	dw $0756,$0756,$0756,$0756,$0757,$0757,$0757,$0758
	dw $0758,$0758,$0759,$0759,$0759,$075a,$075a,$075a
	dw $075a,$075b,$075b,$075b,$075c,$075c,$075c,$075c
	dw $075d,$075d,$075d,$075e,$075e,$075e,$075f,$075f
	dw $075f,$075f,$0760,$0760,$0760,$0761,$0761,$0761
	dw $0761,$0762,$0762,$0762,$0763,$0763,$0763,$0763
	dw $0764,$0764,$0764,$0765,$0765,$0765,$0765,$0766
	dw $0766,$0766,$0767,$0767,$0767,$0767,$0768,$0768
	dw $0768,$0768,$0769,$0769,$0769,$076a,$076a,$076a
	dw $076a,$076b,$076b,$076b,$076b,$076c,$076c,$076c
	dw $076c,$076d,$076d,$076d,$076e,$076e,$076e,$076e
	dw $076f,$076f,$076f,$076f,$0770,$0770,$0770,$0770
	dw $0771,$0771,$0771,$0771,$0772,$0772,$0772,$0772
	dw $0773,$0773,$0773,$0774,$0774,$0774,$0774,$0775
	dw $0775,$0775,$0775,$0776,$0776,$0776,$0776,$0777
	dw $0777,$0777,$0777,$0778,$0778,$0778,$0778,$0778
	dw $0779,$0779,$0779,$0779,$077a,$077a,$077a,$077a
	dw $077b,$077b,$077b,$077b,$077c,$077c,$077c,$077c
	dw $077d,$077d,$077d,$077d,$077e,$077e,$077e,$077e
	dw $077e,$077f,$077f,$077f,$077f,$0780,$0780,$0780
	dw $0780,$0781,$0781,$0781,$0781,$0781,$0782,$0782
	dw $0782,$0782,$0783,$0783,$0783,$0783,$0784,$0784
	dw $0784,$0784,$0784,$0785,$0785,$0785,$0785,$0786
	dw $0786,$0786,$0786,$0786,$0787,$0787,$0787,$0787
	dw $0787,$0788,$0788,$0788,$0788,$0789,$0789,$0789
	dw $0789,$0789,$078a,$078a,$078a,$078a,$078a,$078b
	dw $078b,$078b,$078b,$078c,$078c,$078c,$078c,$078c
	dw $078d,$078d,$078d,$078d,$078d,$078e,$078e,$078e
	dw $078e,$078e,$078f,$078f,$078f,$078f,$078f,$0790
	dw $0790,$0790,$0790,$0790,$0791,$0791,$0791,$0791
	dw $0791,$0792,$0792,$0792,$0792,$0792,$0793,$0793
	dw $0793,$0793,$0793,$0794,$0794,$0794,$0794,$0794
	dw $0795,$0795,$0795,$0795,$0795,$0796,$0796,$0796
	dw $0796,$0796,$0797,$0797,$0797,$0797,$0797,$0798
	dw $0798,$0798,$0798,$0798,$0798,$0799,$0799,$0799
	dw $0799,$0799,$079a,$079a,$079a,$079a,$079a,$079a
	dw $079b,$079b,$079b,$079b,$079b,$079c,$079c,$079c
	dw $079c,$079c,$079c,$079d,$079d,$079d,$079d,$079d
	dw $079e,$079e,$079e,$079e,$079e,$079e,$079f,$079f
	dw $079f,$079f,$079f,$079f,$07a0,$07a0,$07a0,$07a0
	dw $07a0,$07a1,$07a1,$07a1,$07a1,$07a1,$07a1,$07a2
	dw $07a2,$07a2,$07a2,$07a2,$07a2,$07a3,$07a3,$07a3
	dw $07a3,$07a3,$07a3,$07a4,$07a4,$07a4,$07a4,$07a4
	dw $07a4,$07a5,$07a5,$07a5,$07a5,$07a5,$07a5,$07a6
	dw $07a6,$07a6,$07a6,$07a6,$07a6,$07a7,$07a7,$07a7
	dw $07a7,$07a7,$07a7,$07a7,$07a8,$07a8,$07a8,$07a8
	dw $07a8,$07a8,$07a9,$07a9,$07a9,$07a9,$07a9,$07a9
	dw $07aa,$07aa,$07aa,$07aa,$07aa,$07aa,$07aa,$07ab
	dw $07ab,$07ab,$07ab,$07ab,$07ab,$07ac,$07ac,$07ac
	dw $07ac,$07ac,$07ac,$07ac,$07ad,$07ad,$07ad,$07ad
	dw $07ad,$07ad,$07ae,$07ae,$07ae,$07ae,$07ae,$07ae
	dw $07ae,$07af,$07af,$07af,$07af,$07af,$07af,$07af
	dw $07b0,$07b0,$07b0,$07b0,$07b0,$07b0,$07b0,$07b1
	dw $07b1,$07b1,$07b1,$07b1,$07b1,$07b1,$07b2,$07b2
	dw $07b2,$07b2,$07b2,$07b2,$07b2,$07b3,$07b3,$07b3
	dw $07b3,$07b3,$07b3,$07b3,$07b4,$07b4,$07b4,$07b4
	dw $07b4,$07b4,$07b4,$07b4,$07b5,$07b5,$07b5,$07b5
	dw $07b5,$07b5,$07b5,$07b6,$07b6,$07b6,$07b6,$07b6
	dw $07b6,$07b6,$07b7,$07b7,$07b7,$07b7,$07b7,$07b7
	dw $07b7,$07b7,$07b8,$07b8,$07b8,$07b8,$07b8,$07b8
	dw $07b8,$07b8,$07b9,$07b9,$07b9,$07b9,$07b9,$07b9
	dw $07b9,$07b9,$07ba,$07ba,$07ba,$07ba,$07ba,$07ba
	dw $07ba,$07bb,$07bb,$07bb,$07bb,$07bb,$07bb,$07bb
	dw $07bb,$07bc,$07bc,$07bc,$07bc,$07bc,$07bc,$07bc
	dw $07bc,$07bc,$07bd,$07bd,$07bd,$07bd,$07bd,$07bd
	dw $07bd,$07bd,$07be,$07be,$07be,$07be,$07be,$07be
	dw $07be,$07be,$07bf,$07bf,$07bf,$07bf,$07bf,$07bf
	dw $07bf,$07bf,$07bf,$07c0,$07c0,$07c0,$07c0,$07c0
	dw $07c0,$07c0,$07c0,$07c1,$07c1,$07c1,$07c1,$07c1
	dw $07c1,$07c1,$07c1,$07c1,$07c2,$07c2,$07c2,$07c2
	dw $07c2,$07c2,$07c2,$07c2,$07c2,$07c3,$07c3,$07c3
	dw $07c3,$07c3,$07c3,$07c3,$07c3,$07c3,$07c4,$07c4
	dw $07c4,$07c4,$07c4,$07c4,$07c4,$07c4,$07c4,$07c4
	dw $07c5,$07c5,$07c5,$07c5,$07c5,$07c5,$07c5,$07c5
	dw $07c5,$07c6,$07c6,$07c6,$07c6,$07c6,$07c6,$07c6
	dw $07c6,$07c6,$07c7,$07c7,$07c7,$07c7,$07c7,$07c7
	dw $07c7,$07c7,$07c7,$07c7,$07c8,$07c8,$07c8,$07c8
	dw $07c8,$07c8,$07c8,$07c8,$07c8,$07c8,$07c9,$07c9
	dw $07c9,$07c9,$07c9,$07c9,$07c9,$07c9,$07c9,$07c9
	dw $07ca,$07ca,$07ca,$07ca,$07ca,$07ca,$07ca,$07ca
	dw $07ca,$07ca,$07cb,$07cb,$07cb,$07cb,$07cb,$07cb
	dw $07cb,$07cb,$07cb,$07cb,$07cb,$07cc,$07cc,$07cc
	dw $07cc,$07cc,$07cc,$07cc,$07cc,$07cc,$07cc,$07cd
	dw $07cd,$07cd,$07cd,$07cd,$07cd,$07cd,$07cd,$07cd
	dw $07cd,$07cd,$07ce,$07ce,$07ce,$07ce,$07ce,$07ce
	dw $07ce,$07ce,$07ce,$07ce,$07ce,$07cf,$07cf,$07cf
	dw $07cf,$07cf,$07cf,$07cf,$07cf,$07cf,$07cf,$07cf
	dw $07cf,$07d0,$07d0,$07d0,$07d0,$07d0,$07d0,$07d0
	dw $07d0,$07d0,$07d0,$07d0,$07d1,$07d1,$07d1,$07d1
	dw $07d1,$07d1,$07d1,$07d1,$07d1,$07d1,$07d1,$07d1
	dw $07d2,$07d2,$07d2,$07d2,$07d2,$07d2,$07d2,$07d2
	dw $07d2,$07d2,$07d2,$07d2,$07d3,$07d3,$07d3,$07d3
	dw $07d3,$07d3,$07d3,$07d3,$07d3,$07d3,$07d3,$07d3
	dw $07d4,$07d4,$07d4,$07d4,$07d4,$07d4,$07d4,$07d4
	dw $07d4,$07d4,$07d4,$07d4,$07d4,$07d5,$07d5,$07d5
	dw $07d5,$07d5,$07d5,$07d5,$07d5,$07d5,$07d5,$07d5
	dw $07d5,$07d5,$07d6,$07d6,$07d6,$07d6,$07d6,$07d6
	dw $07d6,$07d6,$07d6,$07d6,$07d6,$07d6,$07d6,$07d7
	dw $07d7,$07d7,$07d7,$07d7,$07d7,$07d7,$07d7,$07d7
	dw $07d7,$07d7,$07d7,$07d7,$07d7,$07d8,$07d8,$07d8
	dw $07d8,$07d8,$07d8,$07d8,$07d8,$07d8,$07d8,$07d8
	dw $07d8,$07d8,$07d9,$07d9,$07d9,$07d9,$07d9,$07d9
	dw $07d9,$07d9,$07d9,$07d9,$07d9,$07d9,$07d9,$07d9
	dw $07d9,$07da,$07da,$07da,$07da,$07da,$07da,$07da
	dw $07da,$07da,$07da,$07da,$07da,$07da,$07da,$07db
	dw $07db,$07db,$07db,$07db,$07db,$07db,$07db,$07db
	dw $07db,$07db,$07db,$07db,$07db,$07db,$07dc,$07dc
	dw $07dc,$07dc,$07dc,$07dc,$07dc,$07dc,$07dc,$07dc
	dw $07dc,$07dc,$07dc,$07dc,$07dc,$07dc,$07dd,$07dd
	dw $07dd,$07dd,$07dd,$07dd,$07dd,$07dd,$07dd,$07dd
	dw $07dd,$07dd,$07dd,$07dd,$07dd,$07de,$07de,$07de
	dw $07de,$07de,$07de,$07de,$07de,$07de,$07de,$07de
	dw $07de,$07de,$07de,$07de,$07de,$07de,$07df,$07df
	dw $07df,$07df,$07df,$07df,$07df,$07df,$07df,$07df
	dw $07df,$07df,$07df,$07df,$07df,$07df,$07df,$07e0
	dw $07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0
	dw $07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0
	
NoiseTable:	; taken from deflemask
	db	$a4	; 15 steps
	db	$97,$96,$95,$94,$87,$86,$85,$84,$77,$76,$75,$74,$67,$66,$65,$64
	db	$57,$56,$55,$54,$47,$46,$45,$44,$37,$36,$35,$34,$27,$26,$25,$24
	db	$17,$16,$15,$14,$07,$06,$05,$04,$03,$02,$01,$00
	
include	"GBMod_SampleData.asm"
	
; ================
; Player variables
; ================

section "GBMod vars",wram0
GBM_RAM_Start:

GBM_SongID:			ds	1
GBM_DoPlay:			ds	1
GBM_CurrentRow:		ds	1
GBM_CurrentPattern:	ds	1
GBM_ModuleSpeed:	ds	1
GBM_SpeedChanged:	ds	1
GBM_ModuleTimer:	ds	1
GBM_TickSpeed:		ds	1
GBM_TickTimer:		ds	1
GBM_PatternCount:	ds	1
GBM_PatTableSize:	ds	1
GBM_PatTablePos:	ds	1
GBM_SongDataOffset:	ds	2

GBM_PanFlags:		ds	1

GBM_ArpTick1:		ds	1
GBM_ArpTick2:		ds	1
GBM_ArpTick3:		ds	1
GBM_ArpTick4:		ds	1

GBM_CmdTick1:		ds	1
GBM_CmdTick2:		ds	1
GBM_CmdTick3:		ds	1
GBM_CmdTick4:		ds	1

GBM_Command1:		ds	1
GBM_Command2:		ds	1
GBM_Command3:		ds	1
GBM_Command4:		ds	1
GBM_Param1:			ds	1
GBM_Param2:			ds	1
GBM_Param3:			ds	1
GBM_Param4:			ds	1

GBM_Note1:			ds	1
GBM_Note2:			ds	1
GBM_Note3:			ds	1
GBM_Note4:			ds	1

GBM_FreqOffset1:	ds	2
GBM_FreqOffset2:	ds	2
GBM_FreqOffset3:	ds	2

GBM_Vol1:			ds	1
GBM_Vol2:			ds	1
GBM_Vol3:			ds	1
GBM_Vol4:			ds	1
GBM_OldVol1:		ds	1
GBM_OldVol2:		ds	1
GBM_OldVol3:		ds	1
GBM_OldVol4:		ds	1
GBM_Pulse1:			ds	1
GBM_Pulse2:			ds	1
GBM_Wave3:			ds	1
GBM_Mode4:			ds	1

GBM_SkipCH1:		ds	1
GBM_SkipCH2:		ds	1
GBM_SkipCH3:		ds	1
GBM_SkipCH4:		ds	1

GBM_LastWave:		ds	1
GBM_WaveBuffer:		ds	16

GBM_SamplePlaying:	ds	1
GBM_SampleID:		ds	1
GBM_SampleBank:		ds	1
GBM_SamplePointer:	ds	2
GBM_SampleCounter:	ds	2
GBM_RAM_End:

; Note values
C_2		equ	$00
C#2		equ	$01
D_2		equ	$02
D#2		equ	$03
E_2		equ	$04
F_2		equ	$05
F#2		equ	$06
G_2		equ	$07
G#2		equ	$08
A_2		equ	$09
A#2		equ	$0a
B_2		equ	$0b
C_3		equ	$0c
C#3		equ	$0d
D_3		equ	$0e
D#3		equ	$0f
E_3		equ	$10
F_3		equ	$11
F#3		equ	$12
G_3		equ	$13
G#3		equ	$14
A_3		equ	$15
A#3		equ	$16
B_3		equ	$17
C_4		equ	$18
C#4		equ	$19
D_4		equ	$1a
D#4		equ	$1b
E_4		equ	$1c
F_4		equ	$1d
F#4		equ	$1e
G_4		equ	$1f
G#4		equ	$20
A_4		equ	$21
A#4		equ	$22
B_4		equ	$23
C_5		equ	$24
C#5		equ	$25
D_5		equ	$26
D#5		equ	$27
E_5		equ	$28
F_5		equ	$29
F#5		equ	$2a
G_5		equ	$2b
G#5		equ	$2c
A_5		equ	$2d
A#5		equ	$2e
B_5		equ	$2f
C_6		equ	$30
C#6		equ	$31
D_6		equ	$32
D#6		equ	$33
E_6		equ	$34
F_6		equ	$35
F#6		equ	$36
G_6		equ	$37
G#6		equ	$38
A_6		equ	$39
A#6		equ	$3a
B_6		equ	$3b
C_7		equ	$3c
C#7		equ	$3d
D_7		equ	$3e
D#7		equ	$3f
E_7		equ	$40
F_7		equ	$41
F#7		equ	$42
G_7		equ	$43
G#7		equ	$44
A_7		equ	$45
A#7		equ	$46
B_7		equ	$47