	;; test_rom.s
	;; test rom for nanomig/minimig on Tang nano 20k

	;; This is just a dummy test. It initializes video
	;; and outputs some increasing hex numbers on screen

	;; It can be loaded into the NanoMig simulation
	
VIDMEM	EQU	2048		; start video memory at 2048
COPPER  EQU     $220		; copperlist in RAM
XPOS	EQU     $200
YPOS	EQU     $202

	;; amiga like rom header
	ORG $f80000
	
        bra.s   start-1   	; -1? wtf ...
        dc.w    $4ef9           ; jmp ...

        dc.l    $f80030
        dc.l    $f80008 

        ORG $f80030	

	;; actual code starting point
start:
        ;; wait >80ms for minimig-aga syctrl reset to be gone
        move    #60000,d0
iwlp:   dbra    d0,iwlp
	
	move.l  #$100,sp	; use ram below $100 as stack
	move.b	#3,$bfe201	; LED and OVL are outputs
	move.b	#2,$bfe001	; switch rom overlay off

	bsr	startcopper

	;; just count ...
	clr.l	d0	
prt_lp:	clr.w	XPOS
	jsr 	printlong
	addq.l	#1,d0
	bra.s	prt_lp

startcopper:
	;; clear screem memory
	move.l	#(320*256)/32-1,d0
	move.l	#VIDMEM,a0
cllp:	clr.l	(a0)+
	dbra 	d0,cllp
	
	;; copy copper list to ram
	move.l	#(copperlist_end-copperlist)/4-1,d1
	move.l	#copperlist,a0
	move.l	#COPPER,a1
cplp:	move.l	(a0)+,(a1)+
	dbra	d1,cplp
	
	move.l	#COPPER,$dff080 ; load copper list
	move.w	$dff088,d0      ; start copper
	move.w	#$8380,$dff096  ; init dma controller
	move.w	#$20,$dff1dc	; PAL

	;; reset cursor
	clr.w	XPOS
	clr.w	YPOS	
	
	rts
	
copperlist:	
	dc.w $0100,$1200 ; enable one bitplane
	dc.w $0092,$003c ; display data fetch start 120
	dc.w $0094,$00d4 ; display data fetch end 424
	dc.w $008e,$2c81 ; \__ PAL 320x256
	dc.w $0090,$2cc1 ; /
	dc.w $00e0,$0000 ; bitplane 0 start hi
	dc.w $00e2,VIDMEM; bitplane 0 start low
	dc.w $0182, $000 ; pixel data black
	
	dc.w $0180, $fff ; background white
	dc.w $2a0f,$fffe ; wait for line $2a
	dc.w $0180, $0f0 ; background green
	dc.w $340f,$fffe ; wait for line $34
	dc.w $0180, $ff0 ; background yellow

	dc.w $ffff,$fffe ; End of copperlist
copperlist_end:	

	;; print long given in D0
printlong:
	swap	d0
	jsr 	printword
	swap	d0
	jsr 	printword
	rts

printword:
	movem.l	d0/d1,-(sp)
	move.w	#8,d1
	rol.w	d1,d0
	jsr 	printbyte
	rol.w	d1,d0
	jsr 	printbyte
	movem.l	(sp)+,d0/d1
	rts
	
printbyte:
	movem.l	d0/d1,-(sp)
	move	d0,d1
	lsr	#4,d0
	jsr 	printdigit
	move	d1,d0
	jsr 	printdigit
	movem.l	(sp)+,d0/d1
	rts
	
	;; print hex digit given in D0
printdigit:
	movem.l	d0/a0-a1,-(sp)
	move.l	#hexchars,a0
	and.l	#15,d0
	lsl	#3,d0
	add.l	d0,a0
	move.l	#VIDMEM,a1
	move	YPOS,d0
	mulu	#(8*40),d0
	add.l	d0,a1
	add	XPOS,d0
	ext.l	d0
	add.l	d0,a1	
	moveq	#7,d0
pd0:	move.b	(a0)+,(a1)+
	add.l	#(40-1),a1
	dbra	d0,pd0
	add	#1,XPOS
	movem.l	(sp)+,d0/a0-a1
	rts
	
hexchars:
	dc.b $7C, $C6, $CE, $DE, $F6, $E6, $7C, $00   ; 0
	dc.b $30, $70, $30, $30, $30, $30, $FC, $00   ; 1
	dc.b $78, $CC, $0C, $38, $60, $CC, $FC, $00   ; 2
	dc.b $78, $CC, $0C, $38, $0C, $CC, $78, $00   ; 3
	dc.b $1C, $3C, $6C, $CC, $FE, $0C, $1E, $00   ; 4
	dc.b $FC, $C0, $F8, $0C, $0C, $CC, $78, $00   ; 5
	dc.b $38, $60, $C0, $F8, $CC, $CC, $78, $00   ; 6
	dc.b $FC, $CC, $0C, $18, $30, $30, $30, $00   ; 7
	dc.b $78, $CC, $CC, $78, $CC, $CC, $78, $00   ; 8
	dc.b $78, $CC, $CC, $7C, $0C, $18, $70, $00   ; 9
	dc.b $30, $78, $CC, $CC, $FC, $CC, $CC, $00   ; A
	dc.b $FC, $66, $66, $7C, $66, $66, $FC, $00   ; B
	dc.b $3C, $66, $C0, $C0, $C0, $66, $3C, $00   ; C
	dc.b $F8, $6C, $66, $66, $66, $6C, $F8, $00   ; D
	dc.b $FE, $62, $68, $78, $68, $62, $FE, $00   ; E
	dc.b $FE, $62, $68, $78, $68, $60, $F0, $00   ; F

