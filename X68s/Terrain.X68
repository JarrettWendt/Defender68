*-----------------------------------------------------------
* Title      :	Terrain
* Written by :	Jarrett Wendt
* Date       :	10/8/2019
* Description:	This file contains all the logic directly to do with the Terrain, which is just an array of points which we draw lines between.
*-----------------------------------------------------------

TERRAIN_MAX_Y		equ		SCORE_Y-SCORE_INVAL_HEIGHT	; The tallest the terrain will ever be. We don't want it to accidentally cover the score.
TERRAIN_MIN_Y		equ		SCREEN_HEIGHT-180			; The shortest the terrain will ever be.
TERRAIN_MIN_X		equ		100							; The minimum x variation between terrain points.
TERRAIN_MAX_X		equ		200							; The maximum x variation between terrain points.
NUM_TERRAIN			equ		32							; The maximum amount of terrain points.
BYTES_PER_TERRAIN	equ		4							; word x + word y
terrainQueue:
.capacity			dc.w	NUM_TERRAIN
.size				dc.w	0
.head				dc.w	0
.tail				dc.w	0
.bytesPer			dc.w	BYTES_PER_TERRAIN
.array				dcb.b	BYTES_PER_TERRAIN*NUM_TERRAIN,$FF

terrainPoint		ds.l	1	; Space for 1 terrain point.

; Fills the terrainQueue.
InitTerrain:
.REGISTERS_USED	reg	d0/a0
	movem.l	.REGISTERS_USED, -(sp)
	lea.l	terrainQueue, a0
	
	; Init the queue with it's first value.
	bsr.b	MakeTerrainCoord
	move.w	d0, -(sp)						; Put the y coord on the stack as an arg.
	clr.w	-(sp)							; The x coord will be 0.
	bsr.w	Enqueue							; Enqueue it into the terrainQueue.
	add.l	#BYTES_PER_TERRAIN, sp			; Pop those args off the stack.

.Loop
	bsr.w	NextRand						; Update the RNG.
	bsr.b	MakeTerrainCoord				; Make a terrain coord.
	move.l	d0, -(sp)						; Put this on the stack as an arg.
	bsr.w	Enqueue							; Enqueue it into the terrainQueue.
	add.l	#BYTES_PER_TERRAIN, sp			; Pop those args off the stack.
	bsr.w	IsFull							; So long as we're not full, keep looping.
	tst.b	d0
	beq.b	.Loop
.Break
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Pre:
; d0.l:	Last terrain x, _ coords.
; Post:
; d0.l: Next terrain x, y coords.
MakeTerrainCoord:
	clr.l	d1
	move.w	rand, d1							; Get a random number.
	divu.w	#(TERRAIN_MAX_Y-TERRAIN_MIN_Y), d1	; Mod it by our y range.
	swap.w	d1									; Get the remainder.
	add.w	#TERRAIN_MIN_Y, d1					; Add the min y to get a valid y coord.
	move.w	d1, d0								; Put it into d0 for returning
	swap.w	d0									; Get the x in the lower word.

	clr.l	d1
	move.w	rand, d1							; Get a random number
	divu.w	#(TERRAIN_MAX_X-TERRAIN_MIN_X), d1	; Mod it by our x range.
	swap.w	d1									; Get the remainder.
	add.w	#TERRAIN_MIN_X, d1					; Gadd the min x to get a valid x offset.
	add.w	d1, d0								; Offset the last x coord by that amount.
	swap.w	d0									; Get the coords back into the order of x, y.
	rts

DrawTerrain:
	move.l	#ORANGE, d1
	move.b	#SETPEN, d0
	trap	#15
	bra.b	TraceTerrain

InvalTerrain:
	move.l	#BLACK, d1
	move.b	#SETPEN, d0
	trap	#15
	; Fall-through to TraceTerrain

; Moves the pen through the terrain, drawing in pen color along the way.
TraceTerrain:
	lea.l	terrainQueue, a0

	move.w	Q_BYTES_PER(a0), d7		; Get the bytes-per in d7 since we're going to use it a lot.

	; Compute the head.
	clr.l	d3						; Clear the upper word of d0 since we're about to use it for a byte-offset.
	move.w	Q_HEAD(a0), d3
	mulu.w	d7, d3					; Turn this index into a byte-offset.
	; Compute the max index.
	clr.l	d4
	move.w	Q_CAPACITY(a0), d4
	mulu.w	d7, d4
	; Compute dbra counter.
	move.w	Q_SIZE(a0), d6
	sub.w	#2, d6					; Subtract 1 for dbra and 1 because we're doing the first index out of the loop.

	move.l	Q_ARRAY(a0,d3), d1		; Get the starting point.
	move.w	d1, d2					; Put the y in d2.
	swap.w	d1						; Get the x in d1.

	move.b	#MOVEPEN, d0			; Move our pen here to begin with.
	trap	#15

.Loop
	add.w	d7, d3					; Increment our current index.
	cmp.w	d3, d4					; If we go beyond the capacity.
	bgt.b	.LessThanCapacity
	divu.w	d4, d3					; Mod by the capacity to keep it in the bounds of the array.
	clr.w	d3
	swap.w	d3
.LessThanCapacity

	move.l	Q_ARRAY(a0,d3), d1
	move.w	d1, d2
	swap.w	d1

	move.b	#DRAWLINETO, d0
	trap	#15

	dbra.w	d6, .Loop
.Break
	rts

MoveTerrain:
	lea.l	terrainQueue, a0
	lea.l	terrainPoint, a1		; When we dequeue, we need a place to dequeue to. Even though we don't use it. So this is just throwaway.

	move.w	Q_BYTES_PER(a0), d7

	clr.l	d3						; Our index in the array.
	move.w	Q_SIZE(a0), d6			; The size shall be our dbra counter.
	sub.w	#1, d6					; Subtract 1 for dbra.

.Loop
	move.l	Q_ARRAY(a0,d3), d1		; Get the current x, y coord.
	swap.w	d1						; Get the x in the lower word.
	sub.w	#1, d1					; Move it to the left.
	swap.w	d1						; Get it back in the order of x, y.
	move.l	d1, Q_ARRAY(a0,d3)		; Put it back into the array.
	add.w	d7, d3					; Increment our index.
	dbra.w	d6, .Loop
.Break

	move.w	Q_TAIL(a0), d4			; Compute the tail.
	sub.w	#1, d4					; The tail is really the next place to insert. So the tail element is really at tail - 1.
	divs.w	Q_CAPACITY(a0), d4		; Mod by the capacity to ensure it's within the bounds of the array.
	clr.w	d4
	swap.w	d4
	move.w	d4, d3					; We'll keep the index in d4 for later.
	mulu.w	d7, d3					; d3 is getting the byte-offset.
	move.l	Q_ARRAY(a0,d3), d0

	swap.w	d0						; Get the x coord.
	cmp.w	#SCREEN_WIDTH, d0		; If it's greater, everything's fine, just return.
	bge.b	.Return

	bsr.w	Dequeue					; Dequeue the last position to make space - it should be off screen anyway.
	
	swap.w	d0						; Get the tail coord back into the order of x, y.
	bsr.w	MakeTerrainCoord		; Create a new terrain coord based off of this one.
	move.l	d0, -(sp)				; Put the y coord on the stack as an arg.
	bsr.w	Enqueue					; Enqueue it into the terrainQueue.
	add.l	#BYTES_PER_TERRAIN, sp	; Pop those args off the stack.

.Return
	rts
