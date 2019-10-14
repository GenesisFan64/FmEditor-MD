; ====================================================================
; ----------------------------------------------------------------
; Sound
; ----------------------------------------------------------------

; --------------------------------------------------------
; Init Sound
; 
; Uses:
; a0-a1,d0-d1
; --------------------------------------------------------

Sound_Init:

	; --------------------------------
	; Send our Z80 code to that CPU
		move.w	#0,(z80_reset).l		; $0000 - Request Z80 Reset
		move.w	#$100,(z80_bus).l		; $0100 - Stop Z80, request Z80 Bus
		move.w	#$100,(z80_reset).l		; $0100 - Cancel Z80 Reset
		lea	(z80_cpu).l,a0			; a0 - Z80 RAM output
		moveq	#0,d0				; d0 - Zero
		move.w	#$2000-1,d1			; d1 - length, minus 1
.wait:
		btst	#0,(z80_bus).l			; Z80 stopped?
		bne.s	.wait				; If not, keep waiting
.clear:
		move.b	d0,(a0)+			; Write zero (BYTE) from d0 to output, increment by 1
		dbf	d1,.clear			; Loop until d1 == 0
		lea	Z80_CODE(pc),a0			; a0 - Z80 code input
		lea	(z80_cpu).l,a1			; a1 - Z80 RAM output
		move.w	#(Z80_CODE_END-Z80_CODE)-1,d0	; d0 - Z80 code size, minus 1
.copy:
		move.b	(a0)+,(a1)+			; Write BYTE from input to output, increment both
		dbf	d0,.copy			; Loop until d0 == 0

		move.w	#0,(z80_reset).l		; $0000 - Request Z80 Reset
		nop					; Wait a little
		nop
		nop
		move.w	#$100,(z80_reset).l		; $0100 - Reset cancel
		move.w	#0,(z80_bus).l			; $0000 - Start Z80
		
	; --------------------------------
	; Silence PSG Sound
		move.b	#$9F,(psg_ctrl).l		; Set PSG1 Volume to OFF
		move.b	#$BF,(psg_ctrl).l		; Set PSG2 Volume to OFF
		move.b	#$DF,(psg_ctrl).l		; Set PSG3 Volume to OFF
		move.b	#$FF,(psg_ctrl).l		; Set NOISE Volume to OFF
		rts
		
; ====================================================================
; ----------------------------------------------------------------
; Subroutines
; ----------------------------------------------------------------

; ====================================================================
; ----------------------------------------------------------------
; Z80 Code
; 
; Maximum size: 2000h-stack
; ----------------------------------------------------------------

Z80_CODE:
		cpu Z80				; [AS] Set to Z80
		phase 0				; [AS] Reset PC to zero, for this section
		
; ====================================================================
; Z80 goes here

		include "game/sound/z80.asm"
		
; ====================================================================

		cpu 68000
		padding off
		phase Z80_CODE+*
Z80_CODE_END:
		align 2

; ====================================================================
; ----------------------------------------------------------------
; Sound data goes here
; ----------------------------------------------------------------
