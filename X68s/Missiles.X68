*-----------------------------------------------------------
* Title      :	Defender68
* Written by :	Jarrett Wendt
* Date       :	10/2/2019
* Description:	This file contains all the logic to do with missiles.
*-----------------------------------------------------------

; Loops through all the missiles, invaling, drawing, and moving them as well as checking for collisions.
MissileLoop:
	lea.l	missileArray, a1			; Load the missileSet into registers.
	move.w	#MAX_MISSILES-1, d7
	move.l	#BYTES_PER_MISSILE, d6

.Loop
	cmp.w	#SET_SENTINEL, (a1)			; If we find the sentinel value, don't do anything with this missile.
	beq.b	.Continue

	bsr.w	InvalMissile
	bsr.b	MoveMissile

	move.w	2(a1), d0					; Get the x, y coord.
	swap.w	d0							; Get the x coord in the lower word.
	cmp.w	#MISSILE_X_DESPAWN, d0		; If we're off the screen...
	ble.b	.CheckCollision				; Don't draw it.
	move.w	#SET_SENTINEL, (a1)			; Remove this missile from the set.
	bra.b	.Continue

.CheckCollision
	bsr.w	MissileCollisions
	cmp.w	#SET_SENTINEL, (a1)			; A collision could have destroyed this missile, in which case we don't want to draw it.
	beq.b	.Continue
	bsr.w	DrawMissile

.Continue
	add.l	d6, a1
	dbra.w	d7, .Loop
.Break
	rts

; Pre:
; a1: current missile
MoveMissile:
	move.l	2(a1), d0					; Get the x, y coord.
	swap.w	d0							; Get the x coord in the lower word.
	move.w	(a1), d1					; Grab the velocity.
	add.w	d1, d0						; Add the velocity to the x coordinate.

	cmp.w	#MISSILE_IGNITION_THRESHOLD, d0
	bge.b	.Ignighted

	cmp.w	#(MISSILE_IGNITION_THRESHOLD-MISSILE_IGNITION_EPSILON), d0
	blt.b	.Unignighted

	move.l	d0, d2						; Save the x, y coord off in d2.
	move.w	d1, d3						; Save the velocity off in d3.
	move.b	#MISSILE_IGNITION_SOUND, d1	; Play the ignition sound.
	move.b	#PLAYSOUND, d0
	trap	#15
	move.w	d3, d1						; Getthe velocity back in d1.
	move.l	d2, d0						; Get the x, y coord back in d0.

.Unignighted
	swap.w	d0
	sub.w	#MISSILE_ACCELERATION, d1	; Decelerate since the missile hasn't ignighted yet.
	move.w	d1, (a1)					; Save the updated missile info back to memory.
	move.l	d0, 2(a1)
	rts

.Ignighted
	swap.w	d0							; Get the ordered pair back in the order of x, y.
	add.w	#MISSILE_ACCELERATION, d1	; Increase the velocity by the acceleration.
	move.w	d1, (a1)					; Save the updated missile info back to memory.
	move.l	d0, 2(a1)
	rts

; Pre:
; a1: current missile
MissileCollisions:
	lea.l	enemyArray, a2				; Look through every enemy to see if this bullet hit any.

.Loop
	cmp.w	#SET_SENTINEL, (a2)			; Skip this enemy if it doesn't exist.
	beq.w	.Continue

	move.l	2(a1), d0					; Get the coords of the missile as integers.
	swap.w	d0
	lsr.w	#NUM_FRAC_BITS, d0
	swap.w	d0
	move.l	2(a2), d1					; Get the coords of the enemy.
	add.w	#(ENEMY_HEIGHT/2), d1		; Compute the center of the enemy, since the coord is really the top left of it.
	swap.w	d1
	lsr.w	#NUM_FRAC_BITS, d1			; Turn the x coord into an integer.
	add.w	#(ENEMY_WIDTH/2), d1
	swap.w	d1
	bsr.w	SquaredDistance				; See if the squared distance is within the squared kill radius.
	cmp.l	#MISSILE_KILL_RADIUS_SQUARED, d0
	bgt.w	.Continue					; If out of range, try the next enemy.

.Hit
	move.b	#EXPLOSION_SOUND, d1
	move.b	#PLAYSOUND, d0
	trap	#15

	exg.l	a1, a2
	bsr.w	InvalEnemy
	exg.l	a1, a2
	move.w	#SET_SENTINEL, (a1)			; Remove this bullet from its set.
	move.w	#SET_SENTINEL, (a2)			; Mark this enemy as dead in its set.

	add.w	#ENEMY_JERK, enemyAcceleration		; Increase acceleration for every kill, making the game harder as you win more.

	move.l	2(a1), d0					; The new explosion's position will be integer coords.
	swap.w	d0
	lsr.w	#NUM_FRAC_BITS, d0			; Shift out the fractional bits of the enemy's position.
	swap.w	d0
	move.l	d0, -(sp)					; Add a new explosion to the set so it can be rendered.
	clr.w	-(sp)
	lea.l	explosionSet, a0
	bsr.w	AddItemToSet
	add.l	#BYTES_PER_EXPLOSION, sp	; Pop those args from the stack.
	move.l	#SCORE_PER_ENEMY_KILLED, d0	; Increase the score.
	bsr.w	AddToScore
	rts									; This missile can't hit any more enemies, so get out of here.

.Continue
	add.l	#BYTES_PER_ENEMY, a2
	cmp.l	#enemyArrayEnd, a2
	bne.w	.Loop
	rts

; Pre:
; a1: current missile
InvalMissile:
	move.l	2(a1), d0					; Get the x, y coord.
	swap.w	d0							; Get the x coord in the lower word.
	cmp.w	#MISSILE_IGNITION_THRESHOLD, d0
	bge.b	.Ignighted

	lsr.w	#NUM_FRAC_BITS, d0			; Shift out the fractional bits, leaving us with the integer x coord.
	swap.w	d0
	move.l	#MISSILE_UNIGNIGHTED_DIMENSIONS, d1
	bsr.w	DrawBlackEllipse

	move.l	d1, d2						; Get the #MISSILE_UNIGNIGHTED_DIMENSIONS into d2 as the chunk width/height for redrawing the backgroundBMP.
	bra.b	.RedrawBackground

.Ignighted
	lsr.w	#NUM_FRAC_BITS, d0			; Shift out the fractional bits, leaving us with the integer x coord.
	swap.w	d0
	move.l	#MISSILE_DIMENSIONS, d1		; Draw a black rectangle over the old missile to partially inval it.
	bsr.w	DrawBlackRect
	move.l	d1, d2						; Get the #MISSILE_DIMENSIONS into d2 as the chunk width/height for redrawing the backgroundBMP.

.RedrawBackground
	lea.l	backgroundBMP, a0				; Draw the alpha backgroundBMP over the black rect to finish invaling the missile.
	move.l	d0, d1						; chunk x, y
	bsr.w	DrawProcessedBitmap
	rts

; Pre:
; a1: current missile
DrawMissile:
	lea.l	missileSprite, a0			; Pre-load the missileSprite once.
	move.l	#MISSILE_DIMENSIONS, d2		; Pre-load the chunk width, height once.

	move.l	2(a1), d0					; Get the x, y coord.
	swap.w	d0							; Get the x coord in the lower word.
	cmp.w	#MISSILE_IGNITION_THRESHOLD, d0
	bge.b	.Ignighted

	lsr.w	#NUM_FRAC_BITS, d0			; Shift out the fractional bits, leaving us with the integer x coord.
	swap.w	d0
	move.l	#MISSILE_UNIGNIGHTED_DIMENSIONS, d1
	bsr.w	DrawGreyEllipse
	rts

.Ignighted
	lsr.w	#NUM_FRAC_BITS, d0			; Shift out the fractional bits, leaving us with the integer x coord.
	swap.w	d0
	clr.l	d1							; chunk x, y
	bsr.w	DrawProcessedBitmap
	rts

; Pre:
; N/A
; Post:
; A new missile will be added to the missileSet if there is room.
CreateMissile:
.REGISTERS_USED	reg	d0-d2/a0
	movem.l	.REGISTERS_USED, -(sp)

	move.l	playerPosition, d0				; Missile should spawn near the playerSprite.
	add.w	#MISSILE_Y_OFFSET, d0			; Offset the missile's y so it spawns in the middle of the playerSprite.

	swap.w	d0
	add.w	#PLAYER_WIDTH, d0				; Offset the missile's x so it spawns in front of the playerSprite.
	lsl.w	#NUM_FRAC_BITS, d0				; Make the x-coord a fixed-point number.
	swap.w	d0

	move.l	d0, -(sp)						; Put the coords and velocity of the missile onto the stack.
	move.w	#MISSILE_START_VELOCITY, -(sp)
	lea.l	missileSet, a0					; Add it to the set of missiles.
	bsr.w	AddItemToSet
	add.l	#BYTES_PER_MISSILE, sp			; Pop those args back off the stack now that we're done.

	move.l 	a0, d0							; We want to compare the address, so it needs to go in a data register first.
	cmp.l	#missileArrayEnd, d0			; If the address is past the array then it must be full and so it was not inserted.
	bge.b	.Return							; So we will not play a sound.

	move.b	#GRENADE_LAUNCHER_SOUND, d1		; Play the missile launch sound effect.
	move.b	#PLAYSOUND, d0
	trap	#15

.Return
	movem.l	(sp)+, .REGISTERS_USED
	rts
