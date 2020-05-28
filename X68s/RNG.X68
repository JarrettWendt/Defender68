*-----------------------------------------------------------
* Title      : Random Number Generator
* Written by : Jarrett Wendt
* Date       : 8/30/2019
* Description: Generates random 32-bit number via an LCG.
*-----------------------------------------------------------
*	Linear Congruential Generator
*	=============================
*	r[n + 1] = (a * r[n] + c) % m
*	
*	m		0 < m			the "modulus"
*	a		0 < a < m		the "multiplier" This is a magic number unique and constant for each implementation.
*	c		0 <= c < m		the "increment"
*	r[0]	0 <= r[0] <= m	the "seed" or "start value"
*	
*	There are three common families of parameter choice. I will be using the Hull-Dobell Theorem:
*	
*	c != 0
*	m and c are relatively prime
*	a - 1 is divisible by all prime factors of m
*	a - 1 is divisible by 4 if m is divisible by 4
*
*	specifically...
*
*	c is (roughly) the centiseconds since the last second
*	m is 2^16
*	a is 0xF1EA
*
*	If m were 32 then overflow while multiplying might be possible.
*	So to make a 32-bit random number just concatinate two 16-bit ones.
*-----------------------------------------------------------

; Generates a random word and places it in rand.
; Moves the last random word to rand+2.
NextRand:
.MULTIPLIER		equ	$F1EA
.MODULUS		equ	$FFFF
.REGISTERS_USED	reg	d0-d1
	movem.l	.REGISTERS_USED, -(sp)
	move.b	#TIME, d0			; Get time in centiseconds in d1.
	trap	#15
	and.l	#$FF, d1			; c is now in d1
	move.w	rand, d0			; Get the old random number, which we'll use to calculate the new one.
	move.w	d0, rand+2			; Move the old random number up.
	mulu.w	#.MULTIPLIER, d0
	add.l	d0, d1
	divu.w	#.MODULUS, d1		; Remainder is in upper word of d1.
	swap.w	d1
	move.w	d1, rand			; Update the random number.
	movem.l	(sp)+, .REGISTERS_USED
	rts
	
rand	dc.l	$00010000		; Seed the random number with 1.
