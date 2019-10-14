; ====================================================================
; ----------------------------------------------------------------
; Z80 Code
; 
; Maximum size: 2000h-stack
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
		ld	ix,zym_ctrl_1
		ld	a,2Bh
		ld	(ix),a
		ld	a,80h
		ld	(ix+1),a
; 		ei

; --------------------------------------------------------
; Sample playback LOOP
; --------------------------------------------------------

.loop:
		ld	a,(buffSChn1_Flag)
		or	a
		jp	z,.loop
		jp	p,.request
		ld	a,b
		or	c
		jp	z,.exit
		ld	hl,(buffSChn1_Read+1)
		ld	a,(hl)
		ld	(ix+1),a
	; 0000XX.XX
		ld	a,c
		add 	a,d
		ld	c,a
		ld	hl,(buffSChn1_Read)
		add 	hl,de
		ld	(buffSChn1_Read),hl
		jp	nc,.loop
	; 00XX00.00
		dec	b
		ld	a,(buffSChn1_Read+2)
		inc 	a
		jp	m,.midl
	; XX8000.00
		ld	e,a
		ld	a,(buffSChn1_Read+3)
		inc	a			; next rom bank
		ld	h,a
		ld	(buffSChn1_Read+3),a
		rst	8
		ld	bc,-1			; full size
		ld	a,(buffSChn1_End+2)
		cp	h
		jp	nz,.noend
		ld	bc,(buffSChn1_End)
		res	7,b
.noend:
		ld	a,80h
.midl:
		ld	(buffSChn1_Read+2),a
		ld	a,2Ah			; just in case
		ld	(ix),a
		jr	.loop

; ------------------------------------------------
; WAV Exit
; ------------------------------------------------

.exit:
		ld	a,(buffSChn1_Flag)
		bit 	6,a
		jp	nz,.canloop
		ld	a,2Bh
		ld	(ix),a
		xor	a
		ld	(ix+1),a
		ld	(buffSChn1_Flag),a
		jp	.loop

.canloop:
		ld	hl,(buffSChn1_Loop)
		ld	a,(buffSChn1_Loop+2)
		ld	b,a
		rst	8
		ld	a,b
		ld	(buffSChn1_Read+1),hl
		ld	(buffSChn1_Read+3),a
		xor	a
		ld	(buffSChn1_Read),a
		
		ld	bc,-1			; full size
		ld	a,(buffSChn1_Read+3)
		ld	h,a
		ld	a,(buffSChn1_End+2)
		cp	h
		jp	nz,.loop
		ld	bc,(buffSChn1_End)
		res	7,b
		jp	.loop

; ------------------------------------------------
; WAV Request
; ------------------------------------------------

.request:
		bit 	2,a
		jp	nz,.pitch
		ld	a,2Ah
		ld	(ix),a
		ld	bc,-1
		ld	a,(buffSChn1_Flag)
		bit 	1,a
		jp	z,.nlpfl
		or	01000000b
.nlpfl:
		or	10000000b
		and 	11110000b
		ld	(buffSChn1_Flag),a
		ld	de,(buffSChn1_Spd)
		ld	hl,(buffSChn1_Start)
		ld	a,(buffSChn1_Start+2)
		ld	(buffSChn1_Read+1),hl
		ld	(buffSChn1_Read+3),a
		rst 	8

		ld	bc,-1			; full size
		ld	a,(buffSChn1_Start+2)
		ld	h,a
		ld	a,(buffSChn1_End+2)
		cp	h
		jp	nz,.loop
		ld	bc,(buffSChn1_End)
		res	7,b
		jp	.loop
.pitch:
		ld	de,(buffSChn1_Spd)
	
		ld	a,(buffSChn1_Flag)
		or	80h
		ld	(buffSChn1_Flag),a
		jp	.loop
		
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

		org 1000h
buffSChn1_Flag	db 00000011b			; Request
buffSChn1_Read	db 0				; Read
		dw (WavSample2&7FFFh)|8000h	
		db WavSample2>>15
buffSChn1_Start	dw (WavSample2&7FFFh)|8000h	; Start
		db WavSample2>>15
buffSChn1_End	dw (WavSample2_e&7FFFh)|8000h	; End
		db WavSample2_e>>15
buffSChn1_Loop	dw (WavSample2&7FFFh)|8000h	; Loop
		db WavSample2>>15
buffSChn1_Spd	dw 100h
