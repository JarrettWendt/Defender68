*-----------------------------------------------------------
* Title      :	Defender68
* Written by :	Jarrett Wendt
* Date       :	10/2/2019
* Description:	This file contains all the logic to do with enemies.
*-----------------------------------------------------------

; Will either spawn a new enemy or animate the current one. There's only one enemy animating per frame.
EnemyPump:
	move.l	enemyCurrent, a1
	cmp.w	#SET_SENTINEL, (a1)					; If there's no enemy in this index, spawn one.
	bne.b	.Animate

	clr.l	d0
	move.w	rand, d0							; Mod a random number by the amount of enemy sprites we have.
	divu.w	#NUM_ENEMY_SPRITES, d0
	clr.w	d0									; We don't care about the quotient.
	swap.w	d0									; Get the remainder.
	lsl.w	#2, d0								; Turn this remainder into a 4-byte offset.
	lea.l	enemySpriteArray, a0
	move.l	(a0,d0), -(sp)						; Pick a sprite from the array and put it on the stack.

	move.l	rand, d0							; Generate a random y coordinate for this enemy to spawn at.
	and.l	#$FFFFFF, d0						; If the quotient is larger than a word then division does nothing. This ensures that that'll never happen.
	divu.w	#(ENEMY_MAX_Y-ENEMY_HEIGHT), d0		; Get a random valid y coordinate.
	move.w	#((SCREEN_WIDTH-ENEMY_WIDTH)<<NUM_FRAC_BITS), d0	; The x coord is just the right side of the screen.
	swap.w	d0
	move.l	d0, -(sp)							; Put the start coordinate and velocity on the stack as args so it can be added to the set.
	move.w	#ENEMY_START_VELOCITY, -(sp)
	lea.l	enemySet, a0
	bsr.w	AddItemToSet
	add.l	#BYTES_PER_ENEMY, sp				; Pop those args back off the stack now that we're done.

	lea.l	enemyArray, a1						; After we spawn an enemy, reset to the beginning.
	move.l	a1, enemyCurrent
	rts

.Animate
	bsr.b	InvalEnemy
	bsr.w	MoveEnemy
	bsr.w	EnemyCollisions
	bsr.b	DrawEnemy

	move.l	enemySwitchTimeNext, d0				; See how long we've spent on this enemy.
	move.l	lastFrameTime, d1
	cmp.l	d1, d0
	bgt.b	.Return								; If it hasn't been enough time, get out of here. We'll be back at this same enemy next call.
	move.w	enemyAcceleration, d2				; This enemy will move faster next time.
	add.w	d2, (a1)
	add.l	#BYTES_PER_ENEMY, a1
	move.l	a1, enemyCurrent
	add.l	#ENEMY_SWITCH_TIME_DELTA, d1		; Mark the time in which we should switch again.
	move.l	d1, enemySwitchTimeNext

	cmp.l	#enemyArrayEnd, a1					; If we've reached the end of the array, reset to the beginning.
	bne.b	.Return
	lea.l	enemyArray, a1
	move.l	a1, enemyCurrent
.Return
	rts

; Pre:
; a1: enemyCurrent
InvalEnemy:
	move.l	2(a1), d0					; Get the x, y coord.
	swap.w	d0
	lsr.w	#NUM_FRAC_BITS, d0			; Shift out the x fractional bits.
	swap.w	d0
	move.l	#ENEMY_DIMENSIONS, d1		; chunk width, height
	bsr.w	DrawBlackRect				; Draw a black rect to partially inval the enemy.
	lea.l	backgroundBMP, a0				; Draw the alpha backgroundBMP over the black rect to finish invaling the enemy.
	move.l	d1, d2						; Get the width, height into d2 as DrawProcessedBitmap expects.
	move.l	d0, d1						; chunk x, y
	bsr.w	DrawProcessedBitmap
	rts

; Pre:
; a1: enemyCurrent
DrawEnemy:
	move.l	2(a1), d0					; Get x, y coord.
	swap.w	d0
	lsr.w	#NUM_FRAC_BITS, d0			; Shift out the x fractional bits.
	swap.w	d0
	move.l	6(a1), a0					; Get whatever sprite this enemy is using from the array.
	clr.l	d1							; chunk x, y
	move.l	#ENEMY_DIMENSIONS, d2		; chunk width, height
	bsr.w	DrawProcessedBitmap
	rts

; Pre:
; a1: enemyCurrent
; Post:
; d0: Will be updated with the new coord.
MoveEnemy:
	move.w	(a1), d3					; Get the enemy's velocity..
	move.l	2(a1), d0					; Get x, y coord.
	swap.w	d0
	sub.w	d3, d0						; Subtracting from the x coord because the enemies are going left.
	swap.w	d0
	move.w	d3, (a1)					; Update the velocity and coords in the array.
	move.l	d0,	2(a1)
	rts

; Pre:
; a1: enemyCurrent
EnemyCollisions:
	move.l	2(a1), d0					; Get x, y coord.
	swap.w	d0
	lsr.w	#NUM_FRAC_BITS, d0			; Shift out the x fractional bits.
	swap.w	d0
	move.l	playerPosition, d1			; If they get close enough to the player, it's considered a collision.
	bsr.w	SquaredDistance
	cmp.l	#ENEMY_KILL_RADIUS_SQUARED, d0
	bgt.b	.TestOffScreen
	bsr.w	GameOver
.TestOffScreen
	move.l	2(a1), d0					; Get the enemy's x, y coord back into d0.
	swap.w	d0
	tst.w	d0							; If the x coord is still positive, they're still on screen.
	bpl.b	.StillOnScreen
	bsr.w	GameOver
.StillOnScreen
	rts
