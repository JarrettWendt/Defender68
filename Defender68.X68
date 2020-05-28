*-----------------------------------------------------------
* Title      :	Defender68
* Written by :	Jarrett Wendt
* Date       :	9/25/2019
* Description:	A game written in the Motorola 68000 assembly language inspired by the arcade game Defender.
*
* Common Paradigms within this project:
*
* Invaling old sprites is achieved by first drawing a black rect over the them, then drawing the backgroundBMP bitmap over this.
* The reason for this 2-step process is because drawing a rect is fast and drawing a bitmap with alpha is fast.
* The alternative would be to just draw a bitmap without alpha, which is about 2k cycles more for the player ship for example.
*
* Registers are often not pushed to/from the stack at the beginning and end of subroutines.
* This is a consious decision after observing that most registers do not need to be preserved after a subroutine call.
* Rather than just pushing and popping all registers anyway and wasting cycles, or going through every little case and figuring out exactly what registers should be saved,
* the convention is to just assume that a subroutine will destroy the values within registers.
* This results in a few more `lea`s and `movei`s, but I think it adds up to less memory accesses than a wasteful use of the stack.
* However, exceptions to this practice are common. So it's about 50/50 whether a given subroutine will preserve registers or not. Consult the subroutine's implementation if you're unsure.
*
* Coordinate pairs are expressed in one long with the upper word being the x coord and the lower word being the y coord.
* The x-coords are often expressed in fixed-point while the y coords are not. This is because the game is very heavy on the use of the x-axis but not the y.
*
* There is a lot of small chunks of duplicate code, such as common subroutine calls. It was determined that these calls are so frequent that the overhead of a bsr + rts would be too much.
* Furthermore, the chunks are so small - often only 3 lines - that their functionality is obvious enough that a subroutine call would not make the code that much more readable.
*
* The capitalization convention for labels throughout this project are as follows:
*	- ALL_CAPS 		equates and register equates
*	- PascalCase	Subroutines and other blocks of code, including local labels (those prefixed with '.')
*	- camelCase		Variables, meaning any dc, ds, dcb, or INCBIN.
*-----------------------------------------------------------

    ORG    $1000

	INCLUDE	"X68s/Common.X68"
	INCLUDE	"X68s/Init.X68"
	INCLUDE "X68s/Bitmap.X68"
	INCLUDE	"X68s/Set.X68"
	INCLUDE	"X68s/Queue.X68"
	INCLUDE "X68s/RNG.X68"
	INCLUDE	"X68s/Util.X68"
	INCLUDE	"X68s/Score.X68"
	INCLUDE	"X68s/Missiles.X68"
	INCLUDE	"X68s/Enemies.X68"
	INCLUDE	"X68s/GameOver.X68"
	INCLUDE	"X68s/Terrain.X68"

START:
	; Do everything that happens before the MainLoop.
	; Main menu, loading screen, preprocessing, etc.
	; This is not a subroutine call. Init will invoke the MainLoop when it is done.
	bra.w	Init

MainLoop:
	move.l	#REPAINT_SCREEN, d0				; Flush the buffer to the screen.
	trap	#15

	bsr.w	NextRand						; Update the random number for this frame.

	bsr.w	Input

	bsr.b	InvalPlayer
	bsr.b	DrawPlayer

	bsr.w	MissileLoop						; Missile logic is in a loop because there's many of them.
	bsr.w	EnemyPump						; Enemy logic is in a pump because there's too many of them. We focus on one enemy per frame.
	
	bsr.w	InvalTerrain
	bsr.w	MoveTerrain
	bsr.w	DrawTerrain
	
	bsr.w	UpdateExplosions

	bsr.w	NextRand						; Update the random number for the next frame.
	                                   		; The reason we're calling it twice is because it generates a random word, not long, and moves the old word up 2 bytes.
	                                   		; But we can't just call it twice back-to-back because it uses time. So spacing it out like this helps.
	bsr.b	WaitForNextFrame
	bra.b	MainLoop

; This assumes nobody will play a game through midnight.
WaitForNextFrame:
	move.b	#TIME, d0						; Get current centiseconds in d1.l.
	trap	#15
	move.l	d1, d2							; Copy of current centiseconds in d2.l.
	move.l	lastFrameTime, d0				; Get last centiseconds in d0.l.
	sub.l	d0, d1							; CurrentFrameTime -= lastFrameTime.
	cmp.l	#CENTISECONDS_PER_FRAME, d1		; If it hasn't been enough centiseconds since, try again.
	ble.b	WaitForNextFrame
	move.l	d2, lastFrameTime				; Update the frame time.
	rts

InvalPlayer:
	move.l	playerPositionLastFrame, d0		; Inval the old player sprite.
	move.l	#PLAYER_DIMENSIONS, d1
	bsr.w	DrawBlackRect

	lea.l	backgroundBMP, a0					; Now to draw the alpha'd bitmap over the player.
	move.l	playerPositionLastFrame, d0		; draw  x, y
	move.l	d0, d1							; chunk x, y
	move.l	#PLAYER_DIMENSIONS, d2			; chunk width, height
	bsr.w	DrawProcessedBitmap
	rts

DrawPlayer:
	lea.l	playerSprite, a0
	move.l	playerPosition, d0				; draw  x, y
	clr.l	d1								; chunk x, y
	move.l	#PLAYER_DIMENSIONS, d2			; chunk width, height
	bsr.w	DrawProcessedBitmap
	rts

; Post:
; d0: PlayerPostion
; d1: playerPositionLastFrame
Input:
	move.l	#(ESC<<24)+(UP<<16)+(DOWN<<8)+FIRE, d1
	move.b	#SCANKEYS, d0
	trap	#15

	btst.l	#24, d1							; Pressing ESC ends the game.
	beq.b	.DidNotPressEscape
	move.b	#GETCH, d0						; Empty the pending char queue before returning to the main menu.
	trap	#15
	bra.w	START
.DidNotPressEscape

	btst.l	#0, d1
	beq.b	.EndFire
	move.l	lastButtonState, d0				; Debouncing. If the button was held last frame, don't fire.
	btst.l	#0, d0
	bne.b	.EndFire
	bsr.w	CreateMissile
.EndFire

	move.l	playerPosition, d0				; Grab the playerSprite position because the logic for Up and Down need it, plus it's part of the Post Condition.

	btst.l	#16, d1							; If the playerSprite wants up the y coord decreases.
	beq.b	.EndUp
	sub.w	#PLAYER_MOVE_SPEED, d0
	cmp.w	#PLAYER_MIN_Y, d0				; Don't let the playerSprite move past the screen.
	bgt.b	.EndUp
	add.w	#PLAYER_MOVE_SPEED, d0
	clr.l	d3
.EndUp

	btst.l	#8, d1							; If the playerSprite wants down the y coord increases.
	beq.b	.EndDown
	add.w	#PLAYER_MOVE_SPEED, d0
	cmp.w	#PLAYER_MAX_Y, d0				; Don't let the playerSprite move past the screen.
	blt.b	.EndDown
	sub.w	#PLAYER_MOVE_SPEED, d0
	clr.l	d3
.EndDown

	move.l	d1,	lastButtonState				; Update the Button State.

	move.l	playerPosition, d1				; Update the playerSprite positions.
	move.l	d1, playerPositionLastFrame
	move.l	d0, playerPosition

	rts

; Post:
; d6.l: Number of explosions updated.
UpdateExplosions:
	clr.l	d6
	lea.l	explosionSpritesheet, a0
	move.l	#EXPLOSION_DIMENSIONS, d2		; Set up the width, height now.
	lea.l	explosionArray, a1
	move.l	#MAX_EXPLOSIONS-1, d7
	lea.l	explosionChunksArray, a2
.Loop
	cmp.w	#SET_SENTINEL, (a1)				; If there's no explosion here, skip it.
	beq.b	.Continue

	move.l	2(a1), d0						; draw x, y
	move.w	(a1), d3						; Get the index in the explosionChunksArray.
	cmp.w	#NUM_EXPLOSIONS_IN_SHEET-1, d3	; If we go out of bounds in the array, the animation is over.
	beq.b	.StopAnimation

	clr.l	d1
	move.w	d3, d1							; We'll be using d1 for a while, but keep the copy in d3 because we need to save an incremented index back to the array.
	lsl.w	#2, d1							; Shift by 2 to convert index to a byte offset (Where each index of the explosionChunksArray is a long).
	move.l	(a2,d1), d1						; chunk x, y
	bsr.w	DrawProcessedBitmap

	add.w	#1, d3							; Increment the chunk position
	move.w	d3, (a1)						; Save it back into the array.
	add.l	#1, d6							; Mark +1 explosion updated.
	bra.b	.Continue

.StopAnimation
	move.w	#SET_SENTINEL, (a1)				; Remove this explosion from the array so we don't try drawing it again.
	move.l	d2, d1							; DrawBlackRect wants the (width, height) in d1, unlike DrawProcessedBitmap which wants it in d2.
	bsr.w	DrawBlackRect					; Inval this explosion.
	move.l	d0, d1							; Same draw and chunk coords.
	lea.l	backgroundBMP, a0				; Load the backgroundBMP for drawing a chunk from it.
	bsr.w	DrawProcessedBitmap
	lea.l	explosionSpritesheet, a0		; Get the explosion spritesheet back.
.Continue
	add.l	#BYTES_PER_EXPLOSION, a1
	dbra.w	d7, .Loop
.Break
	rts

; Halts until ENTER is pressed.
; Exits game if ESC is pressed.
WaitForInput:
	move.b	#GETCH, d0
	trap	#15
	cmp.b	#ENTER, d1						; ENTER to continue.
	beq.b	.Break
	cmp.b	#ESC, d1
	bne.b	WaitForInput					; ESC to end the game.
	bra.b	ExitGame
.Break
	rts

ExitGame:
	bsr.w	StopAllSounds
	move.b	#FCLOSE, d0						; Close any open files before exiting the program.
	trap	#15
	bsr.w	ResetWindowSize					; We can't close the simulator's window, so resetting to default is the next best thing.
	SIMHALT

    END    START
