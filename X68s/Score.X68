*-----------------------------------------------------------
* Title      : Score
* Written by : Jarrett Wendt
* Date       : 10/2/2019
* Description: Everything to do with scoring is in this file.
* Score is drawn as a 7-Segment "LED" on screen.
* Score is kept in a long, but the maximum score is only 655350 due to limitations with divu.
* Score is only drawn when it changes. This saves approximately 2k cycles per frame.
*-----------------------------------------------------------

NUM_HIGH_SCORES				equ		8
SCORE_STRING_LENGTH			equ		3
BYTES_PER_HIGH_SCORE		equ		SCORE_STRING_LENGTH+1+4	; +1 for null terminator, +4 for long size high score.
highScoreFilename			dc.b	'scores.bin',0
newHighScores				dcb.l	BYTES_PER_HIGH_SCORE/4,0					; The new high score will be entered here.
oldHighScores				dcb.l	NUM_HIGH_SCORES*(BYTES_PER_HIGH_SCORE/4),0	; Where the old high scores are loaded to and most new ones will reside.
HIGH_SCORE_CHAR_HEIGHT		equ		25	; in pixels
HIGH_SCORE_NAME_X			equ		GAMEOVER_X+65
HIGH_SCORE_NAME_Y			equ		GAMEOVER_Y+180
HIGH_SCORE_NUMBER_X			equ		HIGH_SCORE_NAME_X+60
HIGH_SCORE_NUMBER_Y			equ		HIGH_SCORE_NAME_Y
HIGH_SCORE_FONT				equ		(FIXEDSYS<<24)+((9)<<16)+0

yourScoreString				dc.b	'Your Score',0
YOUR_SCORE_X				equ		GAMEOVER_X+75
YOUR_SCORE_Y				equ		GAMEOVER_Y+95

enterToMainMenuString		dc.b	'Press ENTER to return to Main Menu',0
ENTER_TO_MAIN_MENU_X		equ		GAMEOVER_X-25
ENTER_TO_MAIN_MENU_Y		equ		GAMEOVER_Y+430
HIGH_SCORE_ESC_TO_QUIT_X	equ		GAMEOVER_X+66
HIGH_SCORE_ESC_TO_QUIT_Y	equ		GAMEOVER_Y+455

score						dc.l	0
SCORE_X						equ		SCREEN_WIDTH-10
SCORE_Y						equ		SCREEN_HEIGHT-10
SCORE_POSITION				equ		(SCORE_X<<16)+SCORE_Y ; x, y coords of bottom left of LSD of score.
SCORE_PER_ENEMY_KILLED		equ		10
SCORE_PER_ENEMY_LOST		equ		-100

NUM_SEGMENTS				equ		7
SEGMENT_LENGTH				equ		10		; Pixel length of each segment. So one digit will be this wide and twice this tall.
SEGMENT_SPACE				equ		4		; Pixels between digits.
SEGMENT_THICKNESS			equ		2		; Thickness of line that makes up the segment in pixels.
MAX_SCORE					equ		655350	; Can't display numbers greater than this. This is because if the divu quotient is greater than a word, nothing happens. Since we're dividing by 10 ($A) this is the largest number we can have such that the quotient is still a word.
MAX_DIGITS					equ		6		; Update this if MAX_SCORE changes.

; Calculating these coords at assembly time to make the inval subrotine more efficient.
SCORE_INVAL_WIDTH			equ		MAX_DIGITS*(SEGMENT_LENGTH+SEGMENT_SPACE)
SCORE_INVAL_HEIGHT			equ		2*SEGMENT_LENGTH
SCORE_INVAL_X1				equ		SCORE_X-SCORE_INVAL_WIDTH
SCORE_INVAL_Y1				equ		SCORE_Y-SCORE_INVAL_HEIGHT
SCORE_INVAL_X2				equ		SCORE_X
SCORE_INVAL_Y2				equ		SCORE_Y
SCORE_INVAL_POSITION		equ		(SCORE_INVAL_X1<<16)+SCORE_INVAL_Y1
SCORE_INVAL_DIMENSIONS		equ		(SCORE_INVAL_WIDTH<<16)+SCORE_INVAL_HEIGHT

;	  A
;	  _
;	F|_|B
;	E|_|C
;	  D		G(inside)

sevenSegmentBitmaskTable:
		; bit		76543210
		; segment	_ABCDEFG
.0	dc.b			%1111110
.1	dc.b			%0110000
.2	dc.b			%1101101
.3	dc.b			%1111001
.4	dc.b			%0110011
.5	dc.b			%1011011
.6	dc.b			%1011111
.7	dc.b			%1110000
.8	dc.b			%1111111
.9	dc.b			%1110011

	ds.l	1 ; Store one long to make this long-aligned.
; Table of x, y coordinate pairs describing start/end positions of each segment with the bottomr right being 0, 0.
; Each value is a word, meaning one pair is a long.
segmentCoords:
.A	dc.w	-SEGMENT_LENGTH,-2*SEGMENT_LENGTH,0,-2*SEGMENT_LENGTH
.B	dc.w	0,-2*SEGMENT_LENGTH,0,-SEGMENT_LENGTH
.C	dc.w	0,-SEGMENT_LENGTH,0,0
.D	dc.w	-SEGMENT_LENGTH,0,0,0
.E	dc.w	-SEGMENT_LENGTH,-SEGMENT_LENGTH,-SEGMENT_LENGTH,0
.F	dc.w	-SEGMENT_LENGTH,-2*SEGMENT_LENGTH,-SEGMENT_LENGTH,-SEGMENT_LENGTH
.G	dc.w	-SEGMENT_LENGTH,-SEGMENT_LENGTH,0,-SEGMENT_LENGTH

; Pre:
; d0.l: Something to add to the score.
; This subroutine takes care of making sure the score never overflows.
AddToScore:
	move.l	score, d1		; Get the current score.
	add.l	d0, d1			; Add to the score.
	bpl.b	.PositiveScore	; If the score ever goes negative...
	clr.l	score			; Bound the score to zero (players don't like it when they get negative score).
	bsr.w	DisplayScore	; Make sure this 0 score shows up on the screen.
	bra.w	GameOver		; But also end the game because they lost.
.PositiveScore
	cmp.l	#MAX_SCORE, d1	; If the score has gone beyond the max.
	blt.b	.SaveScore
	move.l	#MAX_SCORE, d1	; Just keep it at the max.
.SaveScore
	move.l	d1, score		; Save the score back to memory.
	
	bsr.w	InvalScore
	; Fall-through to DisplayScore.

; Writes the score to the screen.
DisplayScore:
	move.l	#WHITE, d1
	move.b	#SETPEN, d0
	trap	#15

	move.l	score, d0
	move.l	#SCORE_POSITION, d1
	; Fall-through to SevenSegmentDecimal

; Pre:
; d0.l:	Number to be displayed in decimal.
; d1.l:	x, y coord on screen of where bottom right corner of least significant digit should go.
SevenSegmentDecimal:
	move.l	d0, d7				; Save the arg off in d7 since SevenSegmentDigit needs a different arg in d0.
	lea.l	sevenSegmentBitmaskTable, a0
.Loop
	divu.w	#10, d7
	swap.w	d7					; Get the remainder.
	move.b	(a0,d7), d0			; Use the remainder as an offset in the sevenSegmentBitmaskTable.
	bsr.b	SevenSegmentDigit

	swap.w	d1
	sub.w	#(SEGMENT_LENGTH+SEGMENT_SPACE), d1
	swap.w	d1

	swap.w	d7					; Get the quotient back.
	and.l	#$FFFF, d7			; Get rid of the remainder because that'll screw with the divu.
	tst.w	d7					; If the quotient is zero then there'll be no more remainders and so we're done.
	bne.b	.Loop
	rts

; Pre:
; d0.b:	byte such as one from the sevenSegmentBitmaskTable
; d1.l:	x, y coord on screen of where bottom right corner of this digit should go.
SevenSegmentDigit:
.REGISTERS_USED	REG	d0-d4/a0
	movem.l	.REGISTERS_USED, -(sp)
	move.l	d0, d3				; Save the byte into d3 because we're gonna need d0.
	move.l	d1, d2				; Save the coord into d2 because we're gonna need d1.
	lea.l	segmentCoords, a0
	move.l	#NUM_SEGMENTS-1, d4	; dbra counter
.Loop
	move.l	(a0)+, d0			; Get the first point from the array.
	move.l	(a0)+, d1			; Get the second point from the array.

	btst.l	d4, d3				; Test if this bit is set in the passed arg.
	beq.b	.Continue			; If not, don't draw this segment.

	add.w	d2, d0				; Add the offset to both coords.
	add.w	d2, d1
	swap.w	d0
	swap.w	d1
	swap.w	d2
	add.w	d2, d0
	add.w	d2, d1
	swap.w	d0
	swap.w	d1
	swap.w	d2

	bsr.b	DrawSegment
.Continue
	dbra.w	d4, .Loop
.Break
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Pre:
; d0: x, y coord
; d1: x, y coord
; Post:
; Draws line between d0 to d1.
DrawSegment:
.REGISTERS_USED	reg	d0-d4
	movem.l	.REGISTERS_USED, -(sp)
	move.w	d1, d4	; d4 has correct y
	swap.w	d1
	move.w	d1, d3	; d3 has correct x

	move.w	d0, d2	; d2 has correct y
	swap.w	d0
	move.w	d0, d1	; d1 has correct x

	move.b	#DRAWLINE, d0
	trap	#15
	movem.l	(sp)+, .REGISTERS_USED
	rts

; Clears the score display knowing what the maximum number of digits are.
InvalScore:
	move.w	#BLACK, d1
	move.w	#SETPEN, d0
	trap	#15

	move.w	#SCORE_INVAL_X1, d1		; Inval with a black rect.
	move.w	#SCORE_INVAL_Y1, d2
	move.w	#SCORE_INVAL_X2, d3
	move.w	#SCORE_INVAL_Y2, d4
	move.w	#DRAWRECT, d0
	trap	#15
	; We don't need to draw a bitmap because I know at the bottom of the screen there's no pixels.
	rts

; Sorts all NUM_HIGH_SCORES+1 elements of the newHighScores array.
; This is the real purpose of there being 1 exclusive element in newHighScores and for it to come before oldHighScores.
; If we assume oldHighScores is already sorted, then bubbling the new entry to where it belongs should be O(n).
BubbleSortScores:
	lea.l	newHighScores, a0
	move.w	#(NUM_HIGH_SCORES-1), d7
	move.l	a0, a1													; Copy of the original address in a1 for when we need to reset.
	move.w	d7, d2													; Copy of the original count in d2 for when we need to reset.
.Swapped
	clr.b	d1														; Mark for now that we have not swapped.
.Loop
	move.l	(SCORE_STRING_LENGTH+1)(a0), d3							; array[i]
	move.l	(SCORE_STRING_LENGTH+1+BYTES_PER_HIGH_SCORE)(a0), d4	; array[i + 1]

	cmp.l	d3, d4													; If they're already sorted, don't swap.
	ble.b	.Continue

	move.l	d4, (SCORE_STRING_LENGTH+1)(a0)							; Save the data back in reverse order from how we loaded it.
	move.l	d3, (SCORE_STRING_LENGTH+1+BYTES_PER_HIGH_SCORE)(a0)
	move.l	(a0), d3												; Also swap the names, which are conveniently 4 chars.
	move.l	BYTES_PER_HIGH_SCORE(a0), d4
	move.l	d3, BYTES_PER_HIGH_SCORE(a0)
	move.l	d4, (a0)
	move.b	#1, d1													; Mark that a swap has occured.
.Continue
	add.l	#BYTES_PER_HIGH_SCORE, a0
	dbra.w	d7, .Loop
.Break
	move.l	a1, a0													; Reset the address.
	sub.w	#1, d2													; Decrement size, the last index has the max element.
	move.w	d2, d7													; Reset the size.
	tst.b	d1														; If we did a swap, there could be more unsorted data.
	bne.s	.Swapped
	rts

; Pre:
; a0:	The high score table (either oldHighScores or newHighScores).
PrintHighScores:
	move.l	#WHITE, d1						; Set the font color and style.
	move.l	#HIGH_SCORE_FONT, d2
	move.l	#SETFONT, d0
	trap	#15

	move.l	a0, a2							; Keep the high score table in a2
	lea.l	decimalString, a0				; A place to convert numbers into strings.
	move.w	#HIGH_SCORE_NAME_Y, d3			; Hold on to the y positions because we'll need to increment them.
	move.w	#HIGH_SCORE_NUMBER_Y, d4
	move.w	#NUM_HIGH_SCORES-1, d7			; dbra counter.
.Loop
	move.l	a2, a1							; Get the current score, which starts with a null terminated string.
	move.w	#HIGH_SCORE_NAME_X, d1			; x coord.
	move.w	d3, d2							; y coord.
	move.w	#PRINTAT, d0
	trap	#15

	move.l	4(a2), d0						; Get the score.
	bsr.w	ToDecimalString					; Convert it to a string.
	move.l	a0, a1							; Print that string.
	move.w	#HIGH_SCORE_NUMBER_X, d1		; x coord
	move.w	d4, d2							; y coord
	move.w	#PRINTAT, d0
	trap	#15

	add.l	#BYTES_PER_HIGH_SCORE, a2		; Get to the next score.
	add.w	#HIGH_SCORE_CHAR_HEIGHT, d3		; Move the y position.
	add.w	#HIGH_SCORE_CHAR_HEIGHT, d4
	dbra.w	d7, .Loop
.Break
	rts
