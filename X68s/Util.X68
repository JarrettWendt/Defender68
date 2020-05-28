; Pre:
; d0.w:	Number of bytes to copy.
; a0.l:	Source memory.
; a1.l:	Destination memory.
; Post:
; a1.l: Will contain d0.w copied bytes from a0.l.
Memcpy:
.REGISTERS_USED	reg	d0/a0-a1
	movem.l	.REGISTERS_USED, -(sp)
	sub.w	#1, d0			; Subtract 1 for dbra.
.Loop
	move.b	(a0)+, (a1)+
	dbra.w	d0, .Loop
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Pre:
; d0.l: x, y coordinate pair.
; d1.l: x, y coordinate pair.
; Post:
; d0.l: Squared magnitude between d0.l and d1.l.
SquaredDistance:
	sub.w	d1, d0		; y0 -= y1
	swap.w	d0
	swap.w	d1
	sub.w	d1, d0		; x0 -= x1
	move.w	d0, d1		; Save the x in d1 because we need to do multiplication which needs a long destination.
	and.l	#$FFFF, d1	; Don't want either of the multiplicands to be longer than a word.
	swap.w	d0
	and.l	#$FFFF, d0
	muls.w	d0, d0		; (y0 - y1)^2
	muls.w	d1, d1		; (x0 - x1)^2
	add.l	d1, d0		; (y0 - y1)^2 += (x0 - x1)^2
	rts

; d0: x, y coord
; d1: width, height
DrawGreyEllipse:
.REGISTERS_USED	reg	d0-d1
	movem.l	.REGISTERS_USED, -(sp)
	move.l	#GREY, d1					; Set the pen color to GREY.
	move.l	#SETPEN, d0
	trap	#15
	movem.l	(sp)+, .REGISTERS_USED
	bra.b	PenColorEllipse

; d0: x, y coord
; d1: width, height
DrawBlackEllipse:
.REGISTERS_USED	reg	d0-d1
	movem.l	.REGISTERS_USED, -(sp)
	move.l	#BLACK, d1					; Set the pen color to BLACK.
	move.l	#SETPEN, d0
	trap	#15
	movem.l	(sp)+, .REGISTERS_USED
	; Fall-through to PenColorEllipse.

; d0: x, y coord
; d1: width, height
PenColorEllipse:
.REGISTERS_USED	reg	d0-d4
	movem.l	.REGISTERS_USED, -(sp)
	move.l	d0, d2						; Save the args into other registers that we'll use anyway.
	move.l	d1, d4
	
	swap.w	d2
	move.w	d2, d3						; d3 has correct left x
	swap.w	d2							; d2 has correct top y
	swap.w	d4
	move.w	d4, d1
	swap.w	d4
	add.w	d3, d1						; d1 has correct right x
	add.w	d2, d4						; d4 has correct bottom y

	move.b	#DRAWELLIPSE, d0			; Draw the ellipse.
	trap	#15

	movem.l	(sp)+, .REGISTERS_USED
	rts

; d0: x, y coord
; d1: width, height
DrawBlackRect:
.REGISTERS_USED	reg	d0-d4
	movem.l	.REGISTERS_USED, -(sp)
	move.l	d0, d2						; Save the args off in other registers that we'll use anyway.
	move.l	d1, d4

	move.l	#BLACK, d1					; Set the pen color to black.
	move.l	#SETPEN, d0
	trap	#15
	
	swap.w	d2
	move.w	d2, d3						; d3 has correct left x
	swap.w	d2							; d2 has correct top y
	swap.w	d4
	move.w	d4, d1
	swap.w	d4
	add.w	d3, d1						; d1 has correct right x
	add.w	d2, d4						; d4 has correct bottom y

	move.b	#DRAWRECT, d0				; Draw the rectangle.
	trap	#15

	movem.l	(sp)+, .REGISTERS_USED
	rts

; Draws a black rectangle over the entire screen.
ClearScreen:
.REGISTERS_USED	reg	d0-d1
	movem.l	.REGISTERS_USED, -(sp)
	clr.l	d0
	move.l	#SCREEN_DIMENSIONS, d1
	bsr.b	DrawBlackRect
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Resets Window size to EASy68K's default.
ResetWindowSize:
	move.l	#3, d1						; Any number smaller than the actual min will result in the min window size. 0-2 are reserved for special operations.
	move.b	#RESIZE_WINDOW, d0
	trap	#15
	rts

; Pre:
; d0.l:	Unsigned number to be converted to a decimal string in a0.
; a0:	Address of memory where NULL-terminated decimal string shall be written to.
ToDecimalString:
.REGISTERS_USED	reg	d0/a0
	movem.l	.REGISTERS_USED, -(sp)
.Loop
	divu.w	#10, d0			; Get this digit.
	swap.w	d0
	add.b	#'0', d0		; Turn it into its ASCII value.
	move.b	d0, (a0)+		; Put it into the string.
	clr.w	d0
	swap.w	d0
	tst.w	d0				; If the quotient is 0, then we're done.
	bne.b	.Loop
.Break
	clr.b	(a0)			; Make sure it's NULL terminated.
	movem.l	(sp)+, .REGISTERS_USED
	bsr.b	ReverseString	; The string comes out backwards, so just reverse it.
	rts

; Pre:
; a0: Address of NULL-terminated string to reverse.
ReverseString:
.REGISTERS_USED	reg d0-d2/a0
	movem.l	.REGISTERS_USED, -(sp)
	bsr.b	StringLength	; Get the string length in d0.
	sub.w	#1, d0			; Subtract 1 for pseudo-dbra.
.Loop
	move.b	(a0), d1		; Get str[0]
	move.b	(a0,d0), d2		; Get str[n-1]
	move.b	d1, (a0,d0)		; Swap them.
	move.b	d2, (a0)+
.Continue
	sub.w	#2, d0			; Subtracting 2 because there's 2 characters we just eliminated.
	bpl.b	.Loop			; So long as our index is still positive, keep looping. Zero is not positive.
.Break
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Pre:
; a0:	Address of NULL-terminated string to find length of.
; Post:
; d0.l:	Length of string, not including NULL terminator.
StringLength:
	clr.l	d0		; Counter starts at 0.
.Loop
	tst.b	(a0,d0)	; If this byte is NULL...
	beq.b	.Break	; break
	add.l	#1, d0	; Increment counter.
	bra.b	.Loop	; Go to next char.
.Break
	rts

StopAllSounds:
	clr.b	d1						; The EASy68K manual says that when stopping all sounds, d1.b is not read. This is a lie.
	move.l	#STOP_ALL_SOUNDS, d2
	move.b	#CONTROLSOUND, d0
	trap	#15
	rts
