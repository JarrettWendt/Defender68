*-----------------------------------------------------------
* Title      : Queue
* Written by : Jarrett Wendt
* Date       : 10/9/2019
* Description: Implementation of a Queue data structure in 68k.
*
* Following is an example declaration of this Queue:
* NUM_Q		equ		16
* myQueue:
* .capacity	dc.w	NUM_Q	; Max number of elements.
* .size		dc.w	0		; Current number of elements.
* .head		dc.w	0		; Where we dequeue.
* .tail		dc.w	0		; Where we enqueue.
* .bytesPer	dc.w	2		; Must be even.
* .array	ds.w	NUM_Q
*-----------------------------------------------------------

; Byte-offsets of variables in the Queue header.
Q_CAPACITY	equ	0
Q_SIZE		equ	2
Q_HEAD		equ	4
Q_TAIL		equ	6
Q_BYTES_PER	equ	8
Q_ARRAY		equ	10

; Pre:
; a0:	Start address of Queue.
; sp:	n words of data to add.
; Post:
; a0:	Unchanged.
; sp:	Unchanged, responsibility of caller to pop the stack.
Enqueue:
.REGISTERS_USED		reg	d0-d1/a0
.NUM_REGISTERS_USED	equ	3
.STACK_ARGS			equ	(.NUM_REGISTERS_USED*4)+4
	movem.l	.REGISTERS_USED, -(sp)
	bsr.w	IsFull
	tst.b	d0
	bne.b	.Return				; If it's full, we can't enqueue. So return.
	
	add.w	#1, Q_SIZE(a0)		; Increment the size.

	; Compute the new tail.
	clr.l	d0					; Clear the upper word because we're about to div.
	move.w	Q_TAIL(a0), d0		; Get the tail.
	move.w	d0, d1				; Save the original tail for when we're inserting.
	add.w	#1, d0				; tail += 1.
	divu.w	Q_CAPACITY(a0), d0	; Mod it by the capacity.
	clr.w	d0					; Get rid of the quotient.
	swap.w	d0					; Get the remainder.
	move.w	d0, Q_TAIL(a0)		; Save it back to the Queue.

	; Compute the index.
	move.w	d1, d0				; Get the original tail back.
	clr.l	d1					; Clear the upper word since we're going to use this register as a byte-offset.
	move.w	Q_BYTES_PER(a0), d1	; Get the words-per-index.
	mulu.w	d1, d0				; Turn the index into a byte-offset.
	add.l	#Q_ARRAY, a0		; Move the pointer up to the array.
	add.l	d0, a0				; Get our pointer at the index we need to insert to.
	sub.w	#2, d1				; Subtract 2 for pseudo-dbra.

.Loop							; Put every word from the stack into this index.
	move.w	.STACK_ARGS(sp,d1), (a0,d1)
	sub.w	#2, d1
	bpl.b	.Loop

.Return
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Pre:
; a0:	Start address of Queue.
; a1:	Dest address of dequeued data.
; Post:
; a1:	Either unchanged or will contain the dequeued data.
Dequeue:
.REGISTERS_USED		reg	d0-d1/a0-a1
	movem.l	.REGISTERS_USED, -(sp)
	bsr.w	IsEmpty
	tst.b	d0
	bne.b	.Return				; If it's empty, we can't dequeue, so return.

	sub.w	#1, Q_SIZE(a0)		; Decrement the size.

	; Compute the new head.
	clr.l	d0					; Clear the upper word because we're about to div.
	move.w	Q_HEAD(a0), d0		; Get the head.
	move.w	d0, d1				; Save the original head for when we're inserting.
	add.w	#1, d0				; head += 1.
	divu.w	Q_CAPACITY(a0), d0	; Mod it by the capacity.
	clr.w	d0					; Get rid of the quotient.
	swap.w	d0					; Get the remainder.
	move.w	d0, Q_HEAD(a0)		; Save it back to the Queue.

	; Compute the index.
	move.w	d1, d0				; Get the original head back.
	clr.l	d1					; Clear the upper word since we're going to use this register as a byte-offset.
	move.w	Q_BYTES_PER(a0), d1	; Get the bytes-per-index.
	mulu.w	d1, d0				; turn the index into a byte-offset.
	lsr.w	#1, d1				; Turn bytes-per-index into words-per-index.
	add.l	#Q_ARRAY, a0		; Move the pointer up to the array.
	add.l	d0, a0				; Get our pointer at the index we need to insert to.
	sub.l	#1, d1				; Turn this into a dbra counter.

.Loop							; Put every word from this index into the destination.
	move.w	(a0)+, (a1)+
	dbra.w	d1, .Loop

.Return
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Pre:
; a0:	Start address of Queue.
; Post:
; d0.b:	$FF if queue is full, $00 otherwise.
IsFull:
.REGISTERS_USED	reg	d1
	movem.l	.REGISTERS_USED, -(sp)
	clr.b	d0					; Assume not full at first.
	move.w	Q_CAPACITY(a0), d1	; Get the capacity.
	cmp.w	Q_SIZE(a0), d1		; If capacity != size, then not full.
	bne.b	.Return
	not.b	d0					; If full, invert d0.b, making it $FF.
.Return
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Pre:
; a0:	Start address of Queue.
; Post:
; d0.b:	1 if queue is empty, 0 otherwise.
IsEmpty:
	clr.b	d0					; Assume not empty at first.
	tst.w	Q_SIZE(a0)			; If size != 0, then not empty.
	bne.b	.Return
	not.b	d0					; If empty, invert d0.b, making it $FF.
.Return
	rts
