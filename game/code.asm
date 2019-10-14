; ================================================================
; ------------------------------------------------------------
; Your game code starts here
; 
; No restrictions unless porting to Sega CD or 32X
; ------------------------------------------------------------

		struct 0
fmstru_muldept	ds.b 4			; Deptune/Multiply              %0dddmmmm $30+
fmstru_tlevl	ds.b 4			; Total level                   %0ttttttt $40+
fmstru_rateatck	ds.b 4			; Rate scaling / Attack rate    %rr0aaaaa $50+
fmstru_am1stdec	ds.b 4			; AM enable / 1st decay rate    %a00ddddd $60+
fmstru_2nddec	ds.b 4			; 2nd decay rate "sustain rate" %000ddddd $70+
fmstru_relsust	ds.b 4			; Release rate / Sustain level  %ssssrrrr $80+
fmstru_ssgeg	ds.b 4			; SSG-EG                        %0000ssss $90+
fmstru_feedalg	ds.b 1			; Feedback/Algorithm            %00fffaaa $B0+
fmstru_fmsams	ds.b 1			; Panning/FMS/AMS		%lraa0fff $B4+
fmstru_chnmode	ds.b 1			; Channel 3 enable		%0C000000 $27
fmstru_key	ds.b 1			; Keys on/off                   %kkkk0000 $28
		finish

		struct RAM_Local
RAM_BtnEdit	ds.w 1
RAM_CurrSet	ds.w 1
RAM_CurrOpt	ds.w 1
RAM_LastOpt	ds.w 1
RAM_SetNote	ds.w 4
; RAM_Ch3Mode	ds.w 1
RAM_LFO		ds.w 1
		finish
		
		struct $FFFF0000
RAM_FM_Intr	ds.b $20
RAM_SetFreq	ds.w 4
		finish
		
; ====================================================================
; ----------------------------------------------------------------
; Init
; ----------------------------------------------------------------

		bsr	Video_Clear
		or.b	#%00000010,(RAM_VdpCache+$C).l
		bsr	Video_Update
		lea	(RAM_FM_Intr),a1
		lea	FmData_Default(pc),a0
		move.w	#$20-1,d1
.copy:
		move.b	(a0)+,(a1)+
		dbf	d1,.copy
		lea	(RAM_SetFreq),a0
		move.w	#$2A84,d0
		move.w	d0,(a0)+
		move.w	d0,(a0)+
		move.w	d0,(a0)+
		move.w	d0,(a0)+
		lea	(RAM_SetNote),a0
		move.w	#12*5,d0
		move.w	d0,(a0)+
		move.w	d0,(a0)+
		move.w	d0,(a0)+
		move.w	d0,(a0)+

	; Title and OPs
		lea	Map_BgYmEd(pc),a0
		move.l	#locate(1,19,2),d0
		move.l	#mapsize(160,120),d1
		move.w	#$2100,d2
		bsr	Video_LoadMap
		moveq	#0,d1
		lea	Asc_Title(pc),a0
		move.l	#locate(0,1,1),d0
		bsr	AscPrint_custom
		lea	Asc_OpNames(pc),a0
		move.l	#locate(0,20,3),d0
		bsr	AscPrint_custom
		bsr	FmEdit_DrawMenu

		move.l	#Art_PrintFont,d0
		move.w	#(Art_PrintFont_e-Art_PrintFont),d1
		move.w	#$20,d2
		bsr	Video_LoadArt
		move.l	#Art_BgYmEd,d0
		move.w	#(Art_BgYmEd_e-Art_BgYmEd),d1
		move.w	#$100,d2
		bsr	Video_LoadArt
		move.l	#Art_Algor,d0
		move.w	#(Art_Algor_e-Art_Algor),d1
		move.w	#$140,d2
		bsr	Video_LoadArt
		lea	Pal_FmScreen(pc),a0
		moveq	#0,d0
		move.w	#63,d1
		bsr	Video_LoadPal
		
; ====================================================================
; ----------------------------------------------------------------
; Loop
; ----------------------------------------------------------------

FmEd_Loop:
		move.w	(vdp_ctrl),d4
		btst	#bitVBlnk,d4
		beq.s	FmEd_Loop
		bsr	System_Input
		bsr	FmEdit_DrawMenu
.wait:		move.w	(vdp_ctrl),d4
		btst	#bitVBlnk,d4
		bne.s	.wait

; ------------------------------------------------
; PLAY INSTRUMENT
; ------------------------------------------------
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyC,d4
		beq.s	.c_play
		bsr	FM_Update
.c_play:

; ------------------------------------------------
; STOP INSTRUMENT
; ------------------------------------------------
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyStart,d4
		beq	.st_stop
		move.w	#$0100,(z80_bus).l	; $0100 - Stop Z80
.waitz:
		btst	#0,(z80_bus).l		; Z80 stopped?
		bne.s	.waitz			; If not, wait
		moveq	#$42,d0			; LFO setting
		moveq	#$7F,d1
		move.w	#3,d2
.looptll:
		bsr	FM_Set
		add.w	#4,d0
		dbf	d2,.looptll
		moveq	#$28,d0
		moveq	#2,d1
		bsr	FM_Set
		move.w	#0,(z80_bus).l		; $0000 - Start Z80
.st_stop:

; ------------------------------------------------
; PLAY INSTRUMENT
; ------------------------------------------------
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyA,d4
		beq	.a_special
		cmp.w	#11,(RAM_CurrSet).l
		bne	.nosetch3
		bchg	#6,(RAM_FM_Intr+fmstru_chnmode).l
		beq.s	.nosetch3
		clr.w	(RAM_CurrOpt).l
.nosetch3:
		cmp.w	#18,(RAM_CurrSet).l
		bne.s	.a_special
		bchg	#3,(RAM_LFO+1).w
.a_special:
		
; ------------------------------------------------
; NORMAL UDLR
; ------------------------------------------------

		move.w	(Controller_1+on_hold),d4
		btst	#bitJoyB,d4
		bne	.b_edit
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyDown,d4		; UP/DOWN
		beq.s	.godown
		add.w	#1,(RAM_CurrSet).l
		cmp.w	#11,(RAM_CurrSet).l
		bne.s	.nofreqdown
		tst.b	(RAM_FM_Intr+fmstru_chnmode).l
		bne.s	.nofreqdown
		move.w	(RAM_CurrOpt).w,(RAM_LastOpt).w
		clr.w	(RAM_CurrOpt).w
.nofreqdown:
		cmp.w	#13,(RAM_CurrSet).l
		bne.s	.dontsvopt
		move.w	(RAM_LastOpt).w,(RAM_CurrOpt).w
.dontsvopt:
		cmp.w	#19,(RAM_CurrSet).l
		ble.s	.godown
		clr.w	(RAM_CurrSet).w
		move.w	(RAM_LastOpt).w,(RAM_CurrOpt).w
.godown:

	; Going up
		btst	#bitJoyUp,d4
		beq.s	.goup
		cmp.w	#11,(RAM_CurrSet).l
		bne.s	.dontsvopt3
		tst.b	(RAM_FM_Intr+fmstru_chnmode).l
		bne.s	.dontsvopt3
		move.w	(RAM_LastOpt).w,(RAM_CurrOpt).w	
.dontsvopt3:
		cmp.w	#13,(RAM_CurrSet).l
		bne.s	.dontsvopt2
		tst.b	(RAM_FM_Intr+fmstru_chnmode).l
		bne.s	.dontsvopt2
		move.w	(RAM_CurrOpt).w,(RAM_LastOpt).w
		clr.w	(RAM_CurrOpt).w
.dontsvopt2:
		sub.w	#1,(RAM_CurrSet).l
		bpl.s	.goup
		move.w	#19,(RAM_CurrSet).l
		move.w	(RAM_CurrOpt).w,(RAM_LastOpt).w
.goup:

		cmp.w	#11,(RAM_CurrSet).l
		beq.s	.chnlr3
		cmp.w	#12,(RAM_CurrSet).l
		bne.s	.continu2
.chnlr3:
		tst.b	(RAM_FM_Intr+fmstru_chnmode).l
		beq.s	.continu
.continu2:
		cmp.w	#14,(RAM_CurrSet).l
		bge.s	.continu
		
		btst	#bitJoyRight,d4		; LEFT/RIGHT
		beq.s	.goleft
		add.w	#1,(RAM_CurrOpt).l
		and.w	#%11,(RAM_CurrOpt).l
.goleft:
		btst	#bitJoyLeft,d4
		beq.s	.goright
		sub.w	#1,(RAM_CurrOpt).l
		and.w	#%11,(RAM_CurrOpt).l
.goright:
		bra.s	.continu
		
; ------------------------------------------------
; B EDIT
; ------------------------------------------------	

.b_edit:
		nop

; ------------------------------------------------	

.continu:	
		bsr	FmEdit_Trigger		; TRIGGER
		bra	FmEd_Loop
		
; ====================================================================
; ----------------------------------------------------------------
; VBlank
; ----------------------------------------------------------------

MD_VBlank:
		rte
		
; ====================================================================
; ----------------------------------------------------------------
; Subs
; ----------------------------------------------------------------

; ----------------------------------------------------------------
; a0 - string data
; d0 - locate(layer,x,y)
; d1 - VRAM
; ----------------------------------------------------------------

AscPrint_custom:
		bsr	vid_PickLayer
		lea	(vdp_data),a6
		move.l	d4,4(a6)
.loopy:
		moveq	#0,d4
		move.b	(a0)+,d4
		beq.s	.exit
		add.w	d1,d4
		move.w	d4,(a6)
		bra.s	.loopy
.exit:
		rts

; ----------------------------------------------------------------

ShowVal_custom:
		bsr	vid_PickLayer
		lea	(vdp_data),a6
		move.l	d4,4(a6)
		move.w	d2,d4
		and.w	#%1111,d4
		cmp.w	#10,d4
		bcs.s	.lowa
		add.w	#7,d4
.lowa:
		add.w	d1,d4
		move.w	d4,(a6)
		rts

ShowVal_custom2:
		bsr	vid_PickLayer
		lea	(vdp_data),a6
		move.l	d4,4(a6)
		move.w	d2,d4
		lsr.w	#4,d4
		and.w	#%1111,d4
		cmp.w	#10,d4
		bcs.s	.lowa
		add.w	#7,d4
.lowa:
		add.w	d1,d4
		move.w	d4,(a6)
		
		move.w	d2,d4
		and.w	#%1111,d4
		cmp.w	#10,d4
		bcs.s	.lowa2
		add.w	#7,d4
.lowa2:
		add.w	d1,d4
		move.w	d4,(a6)
		rts

ShowVal_word:
		bsr	vid_PickLayer
		lea	(vdp_data),a6
		move.l	d4,4(a6)
		swap	d3
		move.w	#3,d3
		rol.w	#8,d2
.loopw:
		move.w	d2,d4
		rol.w	#4,d2
		lsr.w	#4,d4
		and.w	#%1111,d4
		cmp.w	#10,d4
		bcs.s	.lowa
		add.w	#7,d4
.lowa:
		add.w	d1,d4
		move.w	d4,(a6)
		dbf	d3,.loopw
		swap	d3
		rts
		
; ----------------------------------------------------------------

FmEdit_Trigger:
		lea	(RAM_FM_Intr),a3
; 		tst.w	(RAM_CurrSet).w
; 		beq.s	.nopresb

		cmp.w	#5,(RAM_CurrSet).w
		beq.s	.nopresb
		cmp.w	#13,(RAM_CurrSet).w
		beq.s	.nopresb
; 		cmp.w	#18,(RAM_CurrSet).w
; 		beq.s	.nopresb
		
		move.w	(Controller_1+on_hold),d4
		move.w	(RAM_CurrOpt),d5
		btst	#bitJoyB,d4
		beq.s	.nopresb
		move.w	(RAM_CurrSet).w,d7
		add.w	d7,d7
		move.w	.b_list(pc,d7.w),d7
		jmp	.b_list(pc,d7.w)
; 		bra	FM_Update
.nopresb:
		move.w	(Controller_1+on_press),d4
		move.w	(RAM_CurrOpt),d5
		btst	#bitJoyB,d4
		beq.s	.exitprsb
		move.w	(RAM_CurrSet).w,d7
		add.w	d7,d7
		move.w	.b_list(pc,d7.w),d7
		jmp	.b_list(pc,d7.w)
; 		bra	FM_Update
.exitprsb:

		move.w	(RAM_CurrSet).w,d7
		sub.w	#14,d7
		bmi.s	.exithere
		add.w	d7,d7
		move.w	.lr_list(pc,d7.w),d7
		jmp	.lr_list(pc,d7.w)
; 		bra	FM_Update
.exithere:
		rts

; --------------------------------------------------------
; B HOLD list
; --------------------------------------------------------

.b_list:
		dc.w .detune-.b_list
		dc.w .mulitplr-.b_list
		dc.w .totalvol-.b_list
		dc.w .ratescal-.b_list
		dc.w .atckrate-.b_list
		dc.w .am_mode-.b_list
		dc.w .1stdec-.b_list
		dc.w .2nddec-.b_list
		dc.w .relrate-.b_list
		dc.w .sustain-.b_list
		dc.w .ssgset-.b_list
		dc.w .setfreq-.b_list	; freq
		dc.w .setnote-.b_list	; note
		dc.w .key_en-.b_list
		dc.w .return-.b_list	; feed
		dc.w .return-.b_list	; algo
		dc.w .return-.b_list	; AMS
		dc.w .return-.b_list	; FMS
		dc.w .return-.b_list	; LFO
		dc.w .return-.b_list
.return:
		rts

; --------------------------------------------------------
; LEFT/RIGHT list
; --------------------------------------------------------

.lr_list:
		dc.w .feedbck-.lr_list	; feed
		dc.w .algorit-.lr_list	; algo
		dc.w .doams-.lr_list	; AMS
		dc.w .dofms-.lr_list	; FMS
		dc.w .lfo_set-.lr_list	; LFO
		dc.w .return-.lr_list
		rts

; ------------------------------------------------
.key_en:
		move.b	fmstru_key(a3),d4
		lsr.w	#4,d4
		move.w	(RAM_CurrOpt),d5
		bchg	d5,d4
		lsl.w	#4,d4
		move.b	d4,fmstru_key(a3)
		rts

; ------------------------------------------------
.detune:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.dtnr
		move.w	#%00010000,d6
.dtnr:
		btst	#bitJoyLeft,d4
		beq.s	.dtnl
		move.w	#-%00010000,d6
.dtnl:
		move.b	fmstru_muldept(a3,d5.w),d4
		add.b	d6,d4
		and.b	#%01111111,d4
		move.b	d4,fmstru_muldept(a3,d5.w)	
		rts

; ------------------------------------------------
.mulitplr:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.mtnr
		move.w	#%0001,d6
.mtnr:
		btst	#bitJoyLeft,d4
		beq.s	.mtnl
		move.w	#-%0001,d6
.mtnl:
		move.b	fmstru_muldept(a3,d5.w),d4
		move.w	d4,d7
		and.b	#%01110000,d4
		add.w	d6,d7
		and.b	#%00001111,d7
		or.w	d4,d7
		move.b	d7,fmstru_muldept(a3,d5.w)	
		rts
		
; ------------------------------------------------
.totalvol:
		clr.w	d6
		clr.w	d7
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.tlnr
		move.w	#1,d6
.tlnr:
		btst	#bitJoyLeft,d4
		beq.s	.tlnl
		move.w	#-1,d6
.tlnl:
		btst	#bitJoyUp,d4
		beq.s	.tlnu
		move.w	#%00010000,d7
.tlnu:
		btst	#bitJoyDown,d4
		beq.s	.tlnd
		move.w	#-%00010000,d7
.tlnd:
		move.b	fmstru_tlevl(a3,d5.w),d4
		add.b	d6,d4
		add.b	d7,d4
		and.w	#%01111111,d4
		move.b	d4,fmstru_tlevl(a3,d5.w)	
		rts
	
; ------------------------------------------------
.ratescal:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.rscnr
		move.w	#%01000000,d6
.rscnr:
		btst	#bitJoyLeft,d4
		beq.s	.rscnl
		move.w	#-%01000000,d6
.rscnl:
		move.b	fmstru_rateatck(a3,d5.w),d4
		move.b	d4,d3
		and.w	#%00011111,d3
		add.b	d6,d4
		and.b	#%11000000,d4
		or.b	d3,d4
		move.b	d4,fmstru_rateatck(a3,d5.w)
		rts
		
; ------------------------------------------------
.atckrate:
		clr.w	d6
		clr.w	d7
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.atrnr
		move.w	#1,d6
.atrnr:
		btst	#bitJoyLeft,d4
		beq.s	.atrnl
		move.w	#-1,d6
.atrnl:
		btst	#bitJoyUp,d4
		beq.s	.atrnu
		move.w	#%00010000,d7
.atrnu:
		btst	#bitJoyDown,d4
		beq.s	.atrnd
		move.w	#-%00010000,d7
.atrnd:
		move.b	fmstru_rateatck(a3,d5.w),d4
		move.b	d4,d3
		and.b	#%11000000,d3
		add.b	d6,d4
		add.b	d7,d4
		and.w	#%00011111,d4
		or.b	d3,d4
		move.b	d4,fmstru_rateatck(a3,d5.w)
		rts

; ------------------------------------------------
.am_mode:
		move.b	fmstru_am1stdec(a3,d5.w),d4
		bchg	#7,d4
		move.b	d4,fmstru_am1stdec(a3,d5.w)
		rts

; ------------------------------------------------
.1stdec:
		clr.w	d6
		clr.w	d7
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.1stdnr
		move.w	#1,d6
.1stdnr:
		btst	#bitJoyLeft,d4
		beq.s	.1stdnl
		move.w	#-1,d6
.1stdnl:
		btst	#bitJoyUp,d4
		beq.s	.1stdnu
		move.w	#%00010000,d7
.1stdnu:
		btst	#bitJoyDown,d4
		beq.s	.1stdnd
		move.w	#-%00010000,d7
.1stdnd:
		move.b	fmstru_am1stdec(a3,d5.w),d4
		move.b	d4,d2
		and.b	#%10000000,d2
		add.b	d6,d4
		add.b	d7,d4
		and.w	#%00011111,d4
		or.w	d2,d4
		move.b	d4,fmstru_am1stdec(a3,d5.w)	
		rts

; ------------------------------------------------
.2nddec:
		clr.w	d6
		clr.w	d7
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.2nddnr
		move.w	#1,d6
.2nddnr:
		btst	#bitJoyLeft,d4
		beq.s	.2nddnl
		move.w	#-1,d6
.2nddnl:
		btst	#bitJoyUp,d4
		beq.s	.2nddnu
		move.w	#%00010000,d7
.2nddnu:
		btst	#bitJoyDown,d4
		beq.s	.2nddnd
		move.w	#-%00010000,d7
.2nddnd:
		move.b	fmstru_2nddec(a3,d5.w),d4
		add.b	d6,d4
		add.b	d7,d4
		and.w	#%00011111,d4
		move.b	d4,fmstru_2nddec(a3,d5.w)	
		rts

; ------------------------------------------------
.relrate:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.rrnr
		move.w	#%00010000,d6
.rrnr:
		btst	#bitJoyLeft,d4
		beq.s	.rrnl
		move.w	#-%00010000,d6
.rrnl:
		move.b	fmstru_relsust(a3,d5.w),d4
		add.b	d6,d4
		and.b	#%11111111,d4
		move.b	d4,fmstru_relsust(a3,d5.w)	
		rts

; ------------------------------------------------
.sustain:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.ssnr
		move.w	#%0001,d6
.ssnr:
		btst	#bitJoyLeft,d4
		beq.s	.ssnl
		move.w	#-%0001,d6
.ssnl:
		move.b	fmstru_relsust(a3,d5.w),d4
		move.w	d4,d7
		and.b	#%11110000,d4
		add.w	d6,d7
		and.b	#%00001111,d7
		or.w	d4,d7
		move.b	d7,fmstru_relsust(a3,d5.w)	
		rts

; ------------------------------------------------
.ssgset:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.ssgnr
		move.w	#%0001,d6
.ssgnr:
		btst	#bitJoyLeft,d4
		beq.s	.ssgnl
		move.w	#-%0001,d6
.ssgnl:
		move.b	fmstru_ssgeg(a3,d5.w),d4
		move.w	d4,d7
		add.w	d6,d7
		and.b	#%00001111,d7
		move.b	d7,fmstru_ssgeg(a3,d5.w)	
		rts
; ------------------------------------------------
.setfreq:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.frqnr
		move.w	#1,d6
.frqnr:
		btst	#bitJoyLeft,d4
		beq.s	.frqnl
		move.w	#-1,d6
.frqnl:
		move.w	(Controller_1+on_hold),d4
		btst	#bitJoyDown,d4
		beq.s	.frqnd
		move.w	#-1,d6
.frqnd:
		btst	#bitJoyUp,d4
		beq.s	.frqnu
		move.w	#+1,d6
.frqnu:

		lea	(RAM_SetFreq),a3
		add.w	d5,d5
		move.w	(a3,d5.w),d4
		add.w	d6,d4
; 		bpl.s	.nozr
; 		clr.w	d4
; .nozr:
; 		cmp.w	#96-1,d4
; 		blt.s	.nozl
; 		move.w	#96-1,d4
; .nozl:
		move.w	d4,(a3,d5.w)
		rts

; ------------------------------------------------
.setnote:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.ntenr
		move.w	#1,d6
.ntenr:
		btst	#bitJoyLeft,d4
		beq.s	.ntenl
		move.w	#-1,d6
.ntenl:
		btst	#bitJoyDown,d4
		beq.s	.ntend
		move.w	#-12,d6
.ntend:
		btst	#bitJoyUp,d4
		beq.s	.ntenu
		move.w	#+12,d6
.ntenu:

		lea	(RAM_SetNote),a3
		add.w	d5,d5
		move.w	(a3,d5.w),d4
		add.w	d6,d4
		bpl.s	.nozr
		clr.w	d4
.nozr:
		cmp.w	#96-1,d4
		blt.s	.nozl
		move.w	#96-1,d4
.nozl:
		move.w	d4,(a3,d5.w)
		add.w	d4,d4
		lea	FmData_FreqList(pc),a3
		lea	(RAM_SetFreq),a4
		move.w	(a3,d4.w),(a4,d5.w)
		rts

; ------------------------------------------------
.feedbck:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.fbnr
		move.w	#%00001000,d6
.fbnr:
		btst	#bitJoyLeft,d4
		beq.s	.fbnl
		move.w	#-%00001000,d6
.fbnl:
		move.b	fmstru_feedalg(a3),d4
		move.b	d4,d7
		and.b	#%00000111,d7
		add.b	d6,d4
		and.b	#%00111000,d4
		or.b	d7,d4
		move.b	d4,fmstru_feedalg(a3)	
		rts

; ------------------------------------------------
.algorit:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.alnr
		move.w	#1,d6
.alnr:
		btst	#bitJoyLeft,d4
		beq.s	.alnl
		move.w	#-1,d6
.alnl:
		move.b	fmstru_feedalg(a3),d4
		move.b	d4,d7
		and.b	#%00111000,d7
		add.b	d6,d4
		and.b	#%00000111,d4
		or.b	d7,d4
		move.b	d4,fmstru_feedalg(a3)
		rts

; ------------------------------------------------
.doams:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.amsnr
		move.w	#%00010000,d6
.amsnr:
		btst	#bitJoyLeft,d4
		beq.s	.amsnl
		move.w	#-%00010000,d6
.amsnl:
		move.b	fmstru_fmsams(a3),d4
		move.b	d4,d7
		and.b	#%11001111,d7
		add.b	d6,d4
		and.b	#%00110000,d4
		or.b	d7,d4
		move.b	d4,fmstru_fmsams(a3)	
		rts

; ------------------------------------------------
.dofms:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.fmsnr
		move.w	#1,d6
.fmsnr:
		btst	#bitJoyLeft,d4
		beq.s	.fmsnl
		move.w	#-1,d6
.fmsnl:
		move.b	fmstru_fmsams(a3),d4
		move.b	d4,d7
		and.b	#%11110000,d7
		add.b	d6,d4
		and.b	#%00000111,d4
		or.b	d7,d4
		move.b	d4,fmstru_fmsams(a3)	
		rts

; ------------------------------------------------


.lfo_set:
		clr.w	d6
		move.w	(Controller_1+on_press),d4
		btst	#bitJoyRight,d4
		beq.s	.fmlfr
		move.w	#1,d6
.fmlfr:
		btst	#bitJoyLeft,d4
		beq.s	.fmlfl
		move.w	#-1,d6
.fmlfl:
		move.b	(RAM_LFO+1),d4
		move.b	d4,d7
		and.b	#%00001000,d7
		add.b	d6,d4
		and.b	#%00000111,d4
		or.b	d7,d4
		move.b	d4,(RAM_LFO+1)
		rts

; ----------------------------------------------------------------

FmEdit_DrawMenu:

	; --------------------------------
	; Show OP Keys ON/OFF
	; --------------------------------

		move.l	#locate(0,20,19),d0
		moveq	#0,d2
		lea	(RAM_FM_Intr),a3
		move.b	fmstru_key(a3),d2
		lsr.w	#4,d2
		moveq	#3,d3
.lkey:
		swap	d3
		move.w	#$0000,d1
		lea	Asc_On(pc),a0
		btst	#0,d2
		bne.s	.keyoff
		lea	Asc_Off(pc),a0
		move.w	#$4000,d1
.keyoff:
		cmp.w	#13,(RAM_CurrSet).l
		bne.s	.notonk
		move.w	(RAM_CurrOpt).l,d4
		cmp.w	d4,d3
		bne.s	.notonk
		move.w	#$2000,d1
; 		tst.w	(RAM_BtnEdit).w
; 		beq.s	.notonk
; 		add.w	#$2000,d1
.notonk:

		bsr	AscPrint_custom
		lsr.w	#1,d2
; 		swap	d2
		
		add.l	#$00000400,d0
		add.w	#1,d3
		swap	d3
		dbf	d3,.lkey
		
	; --------------------------------
	; LFO | AMP Mode ON/OFF
	; --------------------------------
		lea	(RAM_FM_Intr+fmstru_am1stdec),a3
		move.l	#locate(0,20,9),d0
		moveq	#0,d2
		moveq	#3,d3
.lamp:
		move.w	#$0000,d1
		cmp.w	#5,(RAM_CurrSet).l
		bne.s	.notonka
		move.w	(RAM_CurrOpt).l,d4
		cmp.w	d4,d2
		bne.s	.notonka
		add.w	#$2000,d1
; 		tst.w	(RAM_BtnEdit).w
; 		beq.s	.notonka
; 		add.w	#$2000,d1
.notonka:
		lea	Asc_Off(pc),a0
		move.b	(a3),d4
		and.b	#%10000000,d4
		beq.s	.ampoff
		lea	Asc_On(pc),a0
.ampoff:
		bsr	AscPrint_custom
		
		add.l	#$00000500,d0
		add.w	#1,d2
		adda 	#1,a3
		dbf	d3,.lamp

		move.l	#locate(0,20,24),d0
		moveq	#0,d2
		move.w	#$0000,d1
		cmp.w	#18,(RAM_CurrSet).l
		bne.s	.lfoonka
		add.w	#$2000,d1
; 		tst.w	(RAM_BtnEdit).w
; 		beq.s	.lfoonka
; 		add.w	#$2000,d1
.lfoonka:

	; --------------------------------
	; LFO mode
	; --------------------------------
	
	; LFO CUSTOM
		move.l	d0,d3
		move.l	#locate(0,5,24),d0
		lea	Asc_Off(pc),a0
		btst	#3,(RAM_LFO+1).w
		beq.s	.lfooff
		lea	Asc_On(pc),a0
.lfooff:
		bsr	AscPrint_custom

		move.l	d3,d0
		moveq	#$30,d1
		cmp.w	#18,(RAM_CurrSet)
		bne.s	.notonon
		add.w	#$2000,d1
.notonon:
		move.w	(RAM_LFO),d2
		and.w	#%111,d2
		bsr	ShowVal_custom
		
	; --------------------------------
	; LFO mode
	; --------------------------------
	
	; LFO CUSTOM
		move.l	#locate(0,15,16),d0
		lea	Asc_Off(pc),a0
		btst	#6,(RAM_FM_Intr+fmstru_chnmode).l
		beq.s	.ch3off
		lea	Asc_On(pc),a0
.ch3off:
		clr.w	d1
		cmp.w	#11,(RAM_CurrSet)
		bne.s	.notonon2
		add.w	#$2000,d1
.notonon2:
		bsr	AscPrint_custom

	; --------------------------------
	; one digit mods
	; --------------------------------

		lea	List_ShftAnd_1(pc),a2
		move.w	(a2)+,d7
		sub.w	#1,d7
.nxt_one_entry:
		swap	d7
		lea	(RAM_FM_Intr),a1
		move.l	(a2),d0
		move.w	4(a2),d7
		move.w	6(a2),d4
		lea	(a1,d4.w),a0
		clr.w	d3
		move.w	#3,d2
.nxt_one:
		swap	d2
		moveq	#$30,d1
		cmp.w	(RAM_CurrSet),d7
		bne.s	.notono
		cmp.w	(RAM_CurrOpt),d3
		bne.s	.notono
		add.w	#$2000,d1
; 		tst.w	(RAM_BtnEdit).w
; 		beq.s	.notono
; 		add.w	#$2000,d1
.notono:
		move.b	(a0),d2
		move.w	8(a2),d4
		lsr.w	d4,d2
		move.w	$A(a2),d4
		and.w	d4,d2
		bsr	ShowVal_custom
		add.l	#$000500,d0
		adda	#1,a0
		add.w	#1,d3
		swap	d2
		dbf	d2,.nxt_one
		swap	d7
		adda	#$C,a2
		dbf	d7,.nxt_one_entry
		
	; --------------------------------
	; two digit mods
	; --------------------------------
		lea	List_ShftAnd_2(pc),a2
		move.w	(a2)+,d7
		sub.w	#1,d7
.nxt_two_entry:
		swap	d7
		lea	(RAM_FM_Intr),a1
		move.l	(a2),d0
		move.w	4(a2),d7
		move.w	6(a2),d4
		lea	(a1,d4.w),a0
		clr.w	d3
		move.w	#3,d2
.nxt_two:
		swap	d2
		moveq	#$30,d1
		cmp.w	(RAM_CurrSet),d7
		bne.s	.nottwo
		cmp.w	(RAM_CurrOpt),d3
		bne.s	.nottwo
		add.w	#$2000,d1
; 		tst.w	(RAM_BtnEdit).w
; 		beq.s	.nottwo
; 		add.w	#$2000,d1
.nottwo:
		move.b	(a0),d2
		move.w	8(a2),d4
		and.w	d4,d2
		bsr	ShowVal_custom2
		add.l	#$000500,d0
		adda	#1,a0
		add.w	#1,d3
		swap	d2
		dbf	d2,.nxt_two
		swap	d7
		adda	#$A,a2
		dbf	d7,.nxt_two_entry

	; --------------------------------
	; Frequency / Note
	; --------------------------------
	
		clr.w	d3
		lea	(RAM_SetFreq),a0
		move.l	#locate(0,20,16),d0
		moveq	#$30,d1
		cmp.w	#11,(RAM_CurrSet)
		bne.s	.nottwow1
		cmp.w	(RAM_CurrOpt),d3
		bne.s	.nottwow1
		add.w	#$2000,d1
.nottwow1:
		move.w	(a0)+,d2
		bsr	ShowVal_word
		add.l	#$000500,d0
		add.w	#1,d3
		
		move.w	#2,d2
.freqwrd:
		swap	d2
		moveq	#$30,d1
		tst.b	(RAM_FM_Intr+fmstru_chnmode).l
		bne.s	.noch3wow
		add.w	#$4000,d1
		bra.s	.nottwow
.noch3wow:
		cmp.w	#11,(RAM_CurrSet)
		bne.s	.nottwow
		cmp.w	(RAM_CurrOpt),d3
		bne.s	.nottwow
		add.w	#$2000,d1
.nottwow:
		move.w	(a0)+,d2
		bsr	ShowVal_word
		add.l	#$000500,d0
		add.w	#1,d3
		swap	d2
		dbf	d2,.freqwrd

	; Notes
		lea	(RAM_SetNote),a2
		move.l	#locate(0,20,17),d0
		clr.w	d3
		move.w	(a2)+,d2
		lsl.w	#2,d2
		lea	Asc_NoteNames(pc),a0
		adda	d2,a0
		moveq	#0,d1
		cmp.w	#12,(RAM_CurrSet)
		bne.s	.nottwow23
		cmp.w	(RAM_CurrOpt),d3
		bne.s	.nottwow23
		add.w	#$2000,d1
.nottwow23:
		bsr	AscPrint_custom
		
		add.l	#$000500,d0
		add.w	#1,d3
		move.w	#2,d2
.freqwrd2:
		swap	d2
		moveq	#0,d1
		tst.b	(RAM_FM_Intr+fmstru_chnmode).l
		bne.s	.noch3wow2
		add.w	#$4000,d1
		bra.s	.nottwow2
.noch3wow2:
		cmp.w	#12,(RAM_CurrSet)
		bne.s	.nottwow2
		cmp.w	(RAM_CurrOpt),d3
		bne.s	.nottwow2
		add.w	#$2000,d1
.nottwow2:
		move.w	(a2)+,d2
		lsl.w	#2,d2
		lea	Asc_NoteNames(pc),a0
		adda	d2,a0
		bsr	AscPrint_custom
		add.l	#$000500,d0
		add.w	#1,d3
		swap	d2
		dbf	d2,.freqwrd2
		
	; --------------------------------
	; Single byte
	; --------------------------------
		lea	List_SingleVal(pc),a2
		move.w	(a2)+,d7
		sub.w	#1,d7
.nxt_one_en:
		swap	d7
		lea	(RAM_FM_Intr),a1
		move.l	(a2),d0
		move.w	4(a2),d7
		move.w	6(a2),d4
		lea	(a1,d4.w),a0
		clr.w	d3
		move.w	#3,d2
; .nxt_two:
		swap	d2
		moveq	#$30,d1
		cmp.w	(RAM_CurrSet),d7
		bne.s	.notone
		add.w	#$2000,d1
; 		tst.w	(RAM_BtnEdit).w
; 		beq.s	.notone
; 		add.w	#$2000,d1
.notone:
		move.b	(a0),d2
		move.w	8(a2),d4
		lsr.w	d4,d2
		move.w	$A(a2),d4
		and.w	d4,d2
		bsr	ShowVal_custom
		add.l	#$000500,d0
		adda	#1,a0
		add.w	#1,d3
		swap	d2
; 		dbf	d2,.nxt_two
		swap	d7
		adda	#$C,a2
		dbf	d7,.nxt_one_en

	; --------------------------------
	; Left side names
	; --------------------------------
		lea	Asc_Names(pc),a0
		move.l	#locate(0,1,4),d0
		moveq	#0,d2
.lprint:
		moveq	#0,d3
		move.w	(RAM_CurrSet),d3
		add.w	d3,d3
		lea	List_FixdPals(pc),a4
		move.w	(a4,d3.w),d3
		move.w	#$0000,d1
		cmp.w	d3,d2
		bne.s	.noton
		or.w	#$2000,d1
.noton:
		bsr	AscPrint_custom
		add.l	#$00000001,d0
		add.w	#1,d2
		move.b	(a0),d4
		bpl.s	.lprint
		
	; --------------------------------
	; Show Algorithm icon
	; --------------------------------
	
		move.b	(RAM_FM_Intr+fmstru_feedalg),d4
		and.w	#%111,d4
		move.w	#$140,d2
		mulu.w	#45,d4
		add.w	d4,d2
		lea	Map_Algor(pc),a0
		move.l	#locate(0,22,20),d0
		move.l	#mapsize(72,40),d1
; 		move.w	#$140,d2
		bra	Video_LoadMap
		rts

; ----------------------------------------------------------------

FM_Update:
		move.w	#$0100,(z80_bus).l	; $0100 - Stop Z80
.waitz:
		btst	#0,(z80_bus).l		; Z80 stopped?
		bne.s	.waitz			; If not, wait
		moveq	#$28,d0
		moveq	#2,d1
		bsr	FM_Set
		moveq	#$22,d0					; LFO setting
		move.w	(RAM_LFO),d1
		bsr	FM_Set
		lea	(RAM_FM_Intr+fmstru_muldept),a3		; skip key MANUAL READ
		moveq	#$32,d0					; Regs $30-$90
		move.w	#$1B,d2
.loopi:
		move.b	(a3)+,d1
		bsr	FM_Set
		add.w	#4,d0
		dbf	d2,.loopi

		lea	(RAM_SetFreq),a0
		move.w	#$A6,d0
		move.b	(a0)+,d1
		bsr	FM_Set
		move.w	#$A2,d0
		move.b	(a0)+,d1
		bsr	FM_Set
		
		tst.b	(RAM_FM_Intr+fmstru_chnmode).l
		beq.s	.noedfreq3
		lea	(RAM_SetFreq),a0
		move.l	#$00AC00A8,d0
		move.w	#3-1,d2
.dofreq:
		move.b	(a0)+,d1
		bsr	FM_Set
		swap	d0
		move.b	(a0)+,d1
		bsr	FM_Set
		swap	d0
		add.l	#$00010001,d0
		dbf	d2,.dofreq
.noedfreq3:
		move.b	#$B2,d0
		move.b	(a3)+,d1
		bsr	FM_Set
		move.b	#$B6,d0
		move.b	(a3)+,d1
		or.b	#%11000000,d1
		bsr	FM_Set
		
		moveq	#$27,d0
		move.b	(RAM_FM_Intr+fmstru_chnmode),d1
		bsr	FM_Set

		moveq	#$28,d0
		move.b	(RAM_FM_Intr+fmstru_key),d1
		or.b	#%00000010,d1
		bsr	FM_Set
		move.w	#0,(z80_bus).l		; $0000 - Start Z80
		rts

; ----------------------------------------------------------------

FM_UpdateFreq:
; 		move.w	#$0100,(z80_bus).l	; $0100 - Stop Z80
; .waitz:
; 		btst	#0,(z80_bus).l		; Z80 stopped?
; 		bne.s	.waitz			; If not, wait
; 
; 		move.w	#0,(z80_bus).l		; $0000 - Start Z80
		rts

; ----------------------------------------------------------------

FM_Set:
		move.b	(ym_ctrl_1).l,d4
		btst	#7,d4
		bne.s	FM_Set
		move.b	d0,(ym_ctrl_1).l
.wait2:
		move.b	(ym_ctrl_1).l,d4
		btst	#7,d4
		bne.s	.wait2
		move.b	d1,(ym_data_1).l
		rts
		
; ====================================================================
; ----------------------------------------------------------------
; Small data
; ----------------------------------------------------------------

		align 2
List_FixdPals:
		dc.w 0,1,2,3,4,5,6,7,8,9,10
		dc.w 12,13
		dc.w 15,16,17,18,19,20
		dc.w 22
Asc_Title:	dc.b "YM2612 Editor",0
		align 2
Asc_OpNames:	dc.b "OP1  OP2  OP3  OP4",0
		align 2
Asc_On:		dc.b "ON ",0
		align 2
Asc_Off:	dc.b "OFF",0
		align 2
Asc_Names:	dc.b "Detune            ",0
		dc.b "Multiply          ",0
		dc.b "Total level       ",0
		dc.b "Rate scaling      ",0
		dc.b "Attack rate       ",0
		dc.b "AM Mode (AMS Enbl)",0
		dc.b "1st decay rate    ",0
		dc.b "2nd decay rate    ",0
		dc.b "Release rate      ",0
		dc.b "Sustain level     ",0
		dc.b "SSG-EG            ",0
		dc.b 0
		dc.b "Frequency CH3",0
		dc.b "Note",0
		dc.b 0
		dc.b "Keys",0
		dc.b "OP1 Feedback",0
		dc.b "Algorithm ",0
		dc.b "AMS",0
		dc.b "FMS",0
		dc.b "LFO",0
		dc.b 0
		dc.b "Save to SRAM",0
		dc.b -1
		align 2
Asc_NoteNames:	dc.b "C-0",0
		dc.b "C#0",0
		dc.b "D-0",0
		dc.b "D#0",0
		dc.b "E-0",0
		dc.b "F-0",0
		dc.b "F#0",0
		dc.b "G-0",0
		dc.b "G#0",0
		dc.b "A-0",0
		dc.b "A#0",0
		dc.b "B-0",0
		dc.b "C-1",0
		dc.b "C#1",0
		dc.b "D-1",0
		dc.b "D#1",0
		dc.b "E-1",0
		dc.b "F-1",0
		dc.b "F#1",0
		dc.b "G-1",0
		dc.b "G#1",0
		dc.b "A-1",0
		dc.b "A#1",0
		dc.b "B-1",0
		dc.b "C-2",0
		dc.b "C#2",0
		dc.b "D-2",0
		dc.b "D#2",0
		dc.b "E-2",0
		dc.b "F-2",0
		dc.b "F#2",0
		dc.b "G-2",0
		dc.b "G#2",0
		dc.b "A-2",0
		dc.b "A#2",0
		dc.b "B-2",0
		dc.b "C-3",0
		dc.b "C#3",0
		dc.b "D-3",0
		dc.b "D#3",0
		dc.b "E-3",0
		dc.b "F-3",0
		dc.b "F#3",0
		dc.b "G-3",0
		dc.b "G#3",0
		dc.b "A-3",0
		dc.b "A#3",0
		dc.b "B-3",0
		dc.b "C-4",0
		dc.b "C#4",0
		dc.b "D-4",0
		dc.b "D#4",0
		dc.b "E-4",0
		dc.b "F-4",0
		dc.b "F#4",0
		dc.b "G-4",0
		dc.b "G#4",0
		dc.b "A-4",0
		dc.b "A#4",0
		dc.b "B-4",0
		dc.b "C-5",0
		dc.b "C#5",0
		dc.b "D-5",0
		dc.b "D#5",0
		dc.b "E-5",0
		dc.b "F-5",0
		dc.b "F#5",0
		dc.b "G-5",0
		dc.b "G#5",0
		dc.b "A-5",0
		dc.b "A#5",0
		dc.b "B-5",0
		dc.b "C-6",0
		dc.b "C#6",0
		dc.b "D-6",0
		dc.b "D#6",0
		dc.b "E-6",0
		dc.b "F-6",0
		dc.b "F#6",0
		dc.b "G-6",0
		dc.b "G#6",0
		dc.b "A-6",0
		dc.b "A#6",0
		dc.b "B-6",0
		dc.b "C-7",0
		dc.b "C#7",0
		dc.b "D-7",0
		dc.b "D#7",0
		dc.b "E-7",0
		dc.b "F-7",0
		dc.b "F#7",0
		dc.b "G-7",0
		dc.b "G#7",0
		dc.b "A-7",0
		dc.b "A#7",0
		dc.b "B-7",0
		align 2
List_ShftAnd_1:
		dc.w 6
	; Detune
		dc.l locate(0,21,4)	; Position
		dc.w 0			; Entry ID
		dc.w fmstru_muldept	; Position
		dc.w 4			; LSR by
		dc.w %00000111		; AND by
	; Multiply
		dc.l locate(0,21,5)	; Position
		dc.w 1			; Entry ID
		dc.w fmstru_muldept	; Position
		dc.w 0			; LSR by
		dc.w %00001111		; AND by
	; Rate scaling
		dc.l locate(0,21,7)	; Position
		dc.w 3			; Entry ID
		dc.w fmstru_rateatck	; Position
		dc.w 6			; LSR by
		dc.w %00000011		; AND by
	; Release rate
		dc.l locate(0,21,12)	; Position
		dc.w 8			; Entry ID
		dc.w fmstru_relsust	; Position
		dc.w 4			; LSR by
		dc.w %00001111		; AND by
	; Sustain level
		dc.l locate(0,21,13)	; Position
		dc.w 9			; Entry ID
		dc.w fmstru_relsust	; Position
		dc.w 0			; LSR by
		dc.w %00001111		; AND by
	; SSG-EG
		dc.l locate(0,21,14)	; Position
		dc.w 10			; Entry ID
		dc.w fmstru_ssgeg	; Position
		dc.w 0			; LSR by
		dc.w %00001111		; AND by
		align 2

List_ShftAnd_2:
		dc.w 4
	; Total level
		dc.l locate(0,20,6)	; Position
		dc.w 2			; Entry ID
		dc.w fmstru_tlevl	; Position
		dc.w %01111111		; AND by
	; Attack rate
		dc.l locate(0,20,8)	; Position
		dc.w 4			; Entry ID
		dc.w fmstru_rateatck	; Position
		dc.w %00011111		; AND by
	; 1st decay rate
		dc.l locate(0,20,10)	; Position
		dc.w 6			; Entry ID
		dc.w fmstru_am1stdec	; Position
		dc.w %00011111		; AND by
	; 2nd decay rate
		dc.l locate(0,20,11)	; Position
		dc.w 7			; Entry ID
		dc.w fmstru_2nddec	; Position
		dc.w %00011111		; AND by
		align 2

List_SingleVal:
		dc.w 4
	; Feedback
		dc.l locate(0,20,20)	; Position
		dc.w 14			; Entry ID
		dc.w fmstru_feedalg	; Position
		dc.w 3			; LSR by
		dc.w %00000111		; AND by
	; Algorithm
		dc.l locate(0,20,21)	; Position
		dc.w 15			; Entry ID
		dc.w fmstru_feedalg	; Position
		dc.w 0			; LSR by
		dc.w %00000111		; AND by
	; AMS
		dc.l locate(0,20,22)	; Position
		dc.w 16			; Entry ID
		dc.w fmstru_fmsams	; Position
		dc.w 4			; LSR by
		dc.w %00000011		; AND by
	; FMS
		dc.l locate(0,20,23)	; Position
		dc.w 17			; Entry ID
		dc.w fmstru_fmsams	; Position
		dc.w 0			; LSR by
		dc.w %00000111		; AND by
		align 2

; Asc_Title:	dc.b "FM Editor",0
; 		dc.b 0
; 		dc.b "                   OP1  OP2  OP3  OP4",0
; 		dc.b "Channel key On/Off OFF  OFF  OFF  OFF",0
; 		dc.b "Detune             00   00   00   00 ",0
; 		dc.b "Multiply           00   00   00   00 ",0
; 		dc.b "Total level        00   00   00   00 ",0
; 		dc.b "Rate scaling       00   00   00   00 ",0
; 		dc.b "Attack rate        00   00   00   00 ",0
; 		dc.b "AMP Mode On/Off    OFF  OFF  OFF  OFF",0
; 		dc.b "1st decay rate     00   00   00   00 ",0
; 		dc.b "2nd decay rate     00   00   00   00 ",0
; 		dc.b "Release rate       00   00   00   00 ",0
; 		dc.b "Sustain level      00   00   00   00 ",0
; 		dc.b 0
; 		dc.b "Note/Frequency     C-0/0000",0
; 		dc.b "CH3 Notes/Freqs    OFF/----",0
; 		dc.b "                   OFF/----",0
; 		dc.b "                   OFF/----",0		
; 		dc.b 0
; 		dc.b "Feedback           00 XXXXXXXX",0
; 		dc.b "Algorithm          00 XXXXXXXX",0
; 		dc.b "                      XXXXXXXX",0
; 		dc.b "                      XXXXXXXX",0
; 		dc.b 0
; 		dc.b "AMS                00",0
; 		dc.b "FMS                OFF",0
; 		dc.b -1
; 		align 2

Pal_FmScreen:
		dc.w $0000,$0EEE,$0CCC,$0AAA,$0888,$0444,$000E,$0008
		dc.w $00EE,$0088,$00E0,$0080,$0E00,$0800,$0000,$0000
		dc.w $0000,$00AE,$008C,$006A,$0048,$0024,$000E,$0008
		dc.w $00EE,$0088,$00E0,$0080,$0E00,$0800,$0000,$0000
		dc.w $0000,$0AAA,$0888,$0666,$0444,$0222,$0000,$0000
		dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		dc.w $0000,$0E00,$0C00,$0A00,$0800,$0400,$0000,$0000
		dc.w $0000,$0000,$0000,$0000,$0000,$0000,$0000,$0000
		align 2

FmData_FreqList:
		dc.w 644		; C-0
		dc.w 681
		dc.w 722
		dc.w 765
		dc.w 810
		dc.w 858
		dc.w 910
		dc.w 964
		dc.w 1021
		dc.w 1081
		dc.w 1146
		dc.w 1214
		dc.w 644|$800		; C-1
		dc.w 681|$800
		dc.w 722|$800
		dc.w 765|$800
		dc.w 810|$800
		dc.w 858|$800
		dc.w 910|$800
		dc.w 964|$800
		dc.w 1021|$800
		dc.w 1081|$800
		dc.w 1146|$800
		dc.w 1214|$800
		dc.w 644|$1000		; C-2
		dc.w 681|$1000
		dc.w 722|$1000
		dc.w 765|$1000
		dc.w 810|$1000
		dc.w 858|$1000
		dc.w 910|$1000
		dc.w 964|$1000
		dc.w 1021|$1000
		dc.w 1081|$1000
		dc.w 1146|$1000
		dc.w 1214|$1000
		dc.w 644|$1800		; C-3
		dc.w 681|$1800
		dc.w 722|$1800
		dc.w 765|$1800
		dc.w 810|$1800
		dc.w 858|$1800
		dc.w 910|$1800
		dc.w 964|$1800
		dc.w 1021|$1800
		dc.w 1081|$1800
		dc.w 1146|$1800
		dc.w 1214|$1800
		dc.w 644|$2000		; C-4
		dc.w 681|$2000
		dc.w 722|$2000
		dc.w 765|$2000
		dc.w 810|$2000
		dc.w 858|$2000
		dc.w 910|$2000
		dc.w 964|$2000
		dc.w 1021|$2000
		dc.w 1081|$2000
		dc.w 1146|$2000
		dc.w 1214|$2000
		dc.w 644|$2800		; C-5
		dc.w 681|$2800
		dc.w 722|$2800
		dc.w 765|$2800
		dc.w 810|$2800
		dc.w 858|$2800
		dc.w 910|$2800
		dc.w 964|$2800
		dc.w 1021|$2800
		dc.w 1081|$2800
		dc.w 1146|$2800
		dc.w 1214|$2800		
		dc.w 644|$3000		; C-6
		dc.w 681|$3000
		dc.w 722|$3000
		dc.w 765|$3000
		dc.w 810|$3000
		dc.w 858|$3000
		dc.w 910|$3000
		dc.w 964|$3000
		dc.w 1021|$3000
		dc.w 1081|$3000
		dc.w 1146|$3000
		dc.w 1214|$3000
		dc.w 644|$3800		; C-7
		dc.w 681|$3800
		dc.w 722|$3800
		dc.w 765|$3800
		dc.w 810|$3800
		dc.w 858|$3800
		dc.w 910|$3800
		dc.w 964|$3800
		dc.w 1021|$3800
		dc.w 1081|$3800
		dc.w 1146|$3800
		dc.w 1214|$3800
		align 2

		align $10
		dc.b "DEFAULT FM DATA>"
FmData_Default:
		dc.b $00,$00,$00,$00
		dc.b $00,$00,$00,$00
		dc.b $00,$00,$00,$00
		dc.b $00,$00,$00,$00
		dc.b $00,$00,$00,$00
		dc.b $00,$00,$00,$00
		dc.b $00,$00,$00,$00
		dc.b $00
		dc.b $00
		dc.b $00
		dc.b $F0
		align 2
