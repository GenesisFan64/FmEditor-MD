; ====================================================================
; ----------------------------------------------------------------
; MACROS
; ----------------------------------------------------------------

playWave	macro
		ld	a,(hl)
		ld	(de),a
		inc 	l
		endm

writeWave	macro	THISCHNL,type
		ld	hl,(THISCHNL_Read+1)
		ld	a,(hl)
		srl	a
		ld	c,a
	if type=0
		ld	a,80h			; base	
	else
		ld	a,(de)
	endif
		add 	a,c
		ld	(de),a
		inc	e
		ld	hl,(THISCHNL_Read)
		ld	bc,(THISCHNL_Pitch)
		add 	hl,bc
		jp	nc,.nomid1
		ld	a,(THISCHNL_Read+2)
		inc 	a
		or	80h
		ld	(THISCHNL_Read+2),a
.nomid1:
		ld	(THISCHNL_Read),hl
		endm
		
; ====================================================================
; ----------------------------------------------------------------
; Structs
; ----------------------------------------------------------------

; ====================================================================
; ----------------------------------------------------------------
; CODE
; ----------------------------------------------------------------

		di				; Disable interrputs
		im	1			; Interrput mode 1 (standard)
		ld	sp,2000h		; Set stack at the end of Z80, goes backwards
		jr	z80_init		; Jump to z80_init

; --------------------------------------------------------
; RST 0008h
; 
; Set ROM Bank
; a - 0xxx xxxx x0000 0000
; --------------------------------------------------------

		org 0008h
		push	hl
		ld	hl,zbank
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		rrca
		ld	(hl),a
		xor	a
		ld	(hl),a
		pop	hl
		ret

; --------------------------------------------------------
; Z80 Interrupt at 0038h
; 
; VBlank only
; --------------------------------------------------------

		org 0038h			; Align to 0038h
		jp	z80_Vint
		
; --------------------------------------------------------
; Z80 Init
; --------------------------------------------------------

z80_init:
		ld	a,2Bh
		ld	(zym_ctrl_1),a
		ld	a,80h
		ld	(zym_data_1),a

		ld	a,2Ah
		ld	(zym_ctrl_1),a
		ld	hl,(currRead)
		ld	de,zym_data_1
		exx
		ld	hl,waveWrite
		ld	de,waveWrite+1
		ld	bc,300h-1
		ld	a,80h
		ld	(hl),a
		ldir
		
; --------------------------------------------------------
; Sample playback LOOP
; --------------------------------------------------------

drvLoop:

; ------------------------------------------------
; Channel 1
; ------------------------------------------------

		ld	a,(wave1_Read+3)
		rst	8
		ld	de,(currWrite)
		ld	b,256/2
.rdchnl1:
		exx
		playWave
		exx
		push	bc	
		writeWave wave1,0
		writeWave wave1,0
		pop	bc
		djnz	.rdchnl1
		
; ------------------------------------------------
; Channel 2
; ------------------------------------------------

		ld	a,(wave2_Read+3)
		rst	8
		ld	de,(currWrite)
		ld	b,256/2
.rdchnl2:
		exx
		playWave
		exx
		push	bc	
		writeWave wave2,1
		writeWave wave2,1
		pop	bc
		djnz	.rdchnl2

; ------------------------------------------------
; WAVE switch
; ------------------------------------------------

		ld	hl,(currRead)
		ld	de,(currWrite)
		ld	(currRead),de
		ld	(currWrite),hl
		exx
		ld	a,2Ah
		ld	(zym_ctrl_1),a
		ld	hl,(currRead)
		exx
		jp	drvLoop
		
; ====================================================================
; ----------------------------------------------------------------
; Z80 VBlank
; ----------------------------------------------------------------

z80_Vint:
		di
		push	af
		push	ix
		push	iy
		push	bc
		push	de
		push	hl
		exx
		push	bc
		push	de
		push	hl
; ----------------------------------------------------

	; stuff goes here

; ----------------------------------------------------
		pop	hl
		pop	de
		pop	bc
		exx
		pop	hl
		pop	de
		pop	bc
		pop	iy
		pop	ix
		pop	af
		ei				; Re-enable interrupts before exiting
		ret				; Return

; ====================================================================
; ----------------------------------------------------------------
; Z80 RAM
; ----------------------------------------------------------------

		org 0FFCh
currWrite	dw waveWrite
currRead	dw waveRead
waveWrite	ds 256
waveRead	ds 256
waveOff		ds 256

; Channel 1
wave1_Flags	db 00000000b			; Request
wave1_Read	db 0			; Read
		dw (WavSample&7FFFh)|8000h	
		db WavSample>>15
wave1_Start	dw (WavSample&7FFFh)|8000h	; Start
		db WavSample>>15
wave1_End	dw (WavSample_e&7FFFh)|8000h	; End
		db WavSample_e>>15
wave1_Loop	dw (WavSample&7FFFh)|8000h	; Loop
		db WavSample>>15
wave1_Pitch	dw 100h

wave2_Flags	db 00000000b			; Request
wave2_Read	db 0			; Read
		dw (WavSample&7FFFh)|8000h	
		db WavSample>>15
wave2_Start	dw (WavSample&7FFFh)|8000h	; Start
		db WavSample>>15
wave2_End	dw (WavSample_e&7FFFh)|8000h	; End
		db WavSample_e>>15
wave2_Loop	dw (WavSample&7FFFh)|8000h	; Loop
		db WavSample>>15
wave2_Pitch	dw 100h

