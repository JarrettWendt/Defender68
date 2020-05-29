*-----------------------------------------------------------
* Title      :	Set Data Structure
* Written by :	Jarrett Wendt
* Date       :	9/26/2019
* Description:	This is a poor-man's implementation of a Set in 68k.
*               It has O(n) Insertion and Removal, where n is the capacity (max number of elements).
*				And element leading with the Sentinel value in the first word is considered empty.
*
* Following is an example declaration of this Set:
* NUM_SET	equ		16
* mySet:
* .maxIndex	dc.w	NUM_SET-1	; The index of the last element.
* .bytesPer	dc.l	2			; Must be even.
* .array	ds.w	NUM_Q
*-----------------------------------------------------------

; Byte-offsets of variables in the Set header.
SET_CAPACITY	equ	0
SET_BYTES_PER	equ	2
SET_ARRAY		equ	6

SET_SENTINEL	equ	$FFFF

; Pre:
; a0: 	Start address of Set.
; sp:	n bytes of info to add.
; Post:
; a0:	Address of where item was added or otherwise beyond the bounds of the Set.
; sp:	Unchanged, responsibility of caller to 'delete' those bytes if desired.
AddItemToSet:
.REGISTERS_USED		reg	d0-d1
.NUM_REGISTERS_USED	equ	2
.STACK_ARGS			equ	(.NUM_REGISTERS_USED*4)+4
	movem.l	.REGISTERS_USED, -(sp)
	move.w	(a0)+, d0				; Get the max index.
	move.l	(a0)+, d1				; Get the bytes-per-index.
.Loop:
	cmp.w	#SET_SENTINEL, (a0)		; If there's something in this index, skip it.
	bne.w	.Continue
	sub.l	#1, d1					; Subtract 1 for dbra.
.AddByte							; Add all the bytes from the stack to this index.
	move.b	.STACK_ARGS(sp,d1), (a0,d1)
	dbra.w	d1, .AddByte
	bra.b	.Break
.Continue:
	add.l	d1, a0
	dbra.w	d0, .Loop
.Break
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Pre:
; a0:	Start address of set.
; a1:	Subroutine to be applied to every filled index of set.
;		Subroutine will have available to it a0, which is the address of its element.
;		Subroutine should ensure a0 is intact when returning.
ForEach:
.REGISTERS_USED	reg	d0-d1
	movem.l	.REGISTERS_USED, -(sp)
	move.w	(a0)+, d0				; Get the max index.
	move.w	(a0)+, d1				; Get the bytes-per-index.
.Loop
	cmp.w	#SET_SENTINEL, (a0)		; If there's nothing in this index, skip it.
	beq.w	.Continue
	jsr		(a1)					; Otherwise, perform the subroutine on this index.
.Continue
	add.l	d1, a0
	dbra.w	d0, .Loop
.Break
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Pre:
; a0:	Start address of Set.
; Post:
; Set will have first word set to the SetSentinal of ever element.
ClearSet:
.REGISTERS_USED	reg	d0-d1
	movem.l	.REGISTERS_USED, -(sp)
	move.w	(a0)+, d0				; Get the max index.
	move.l	(a0)+, d1				; Get the bytes-per-index.
.Loop
	move.w	#SET_SENTINEL, (a0)		; Just put the SET_SENTINEL in every index.
	add.l	d1, a0
	dbra.w	d0, .Loop
	movem.l	(sp)+, .REGISTERS_USED
	rts
