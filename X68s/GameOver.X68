*-----------------------------------------------------------
* Title      :	GameOver
* Written by :	Jarrett Wendt
* Date       :	10/8/2019
* Description:	This file contains all the logic directly to do with the game ending.
*-----------------------------------------------------------

; No preconditions.
GameOver:
	move.l	playerPosition, -(sp)			; Make the player explode.
	clr.w	-(sp)
	lea.l	explosionSet, a0
	bsr.w	AddItemToSet
	add.l	#BYTES_PER_EXPLOSION, sp		; Pop those args off the stack.

	bsr.w	StopAllSounds

	move.b	#GAMEOVER_SOUND, d1				; Play an explosion sound for the player.
	move.b	#PLAYSOUND, d0
	trap	#15

.DeathLoop
	bsr.w	WaitForNextFrame				; Ensure this explosion has the same framerate as the rest of the game.
	bsr.w	UpdateExplosions				; Returns number of explosions updated in d6.
	move.l	#REPAINT_SCREEN, d0				; Flush the buffer to the screen.
	trap	#15
	dbra.w	d6, .DeathLoop					; So long as explosions are still playing, keep looping.

	move.l	#DOUBLE_BUFFERING_DISABLE, d1	; Disable double buffering since for now we're just renering text.
	move.l	#SETDRAWMODE, d0
	trap	#15

	move.l	#WHITE, d1						; Set the font style.
	move.l	#GAMEOVER_FONT, d2
	move.l	#SETFONT, d0
	trap	#15

	lea.l	gameOverString, a1				; Tell them this is game over.
	move.l	#GAMEOVER_X, d1
	move.l	#GAMEOVER_Y, d2
	move.l	#PRINTAT, d0
	trap	#15

	lea.l	highScoreFilename, a1			; Open the high-score file.
	move.b	#FOPEN, d0
	trap	#15
	
	lea.l	oldHighScores, a1				; Load it into memory.
	move.l	#NUM_HIGH_SCORES*BYTES_PER_HIGH_SCORE, d2
	move.b	#FREAD, d0
	trap	#15

	move.b	#FCLOSE, d0						; Close the file.
	trap	#15

	move.b	#0, d1							; Opening a file re-enables keybaord echo. So disable it.
	move.l	#ECHO, d0
	trap	#15

	lea.l	oldHighScores, a0
	bsr.w	PrintHighScores
	
	move.l	#GAME_OVER_INPUT_DELAY, d1		; Delay a little bit so the player doesn't start putting the UP/DOWN keys into the high score.
	move.b	#SLEEP, d0
	trap	#15

	move.b	#GETCH, d0						; The player was just pressing a bunch of buttons which means there's at least one left for processing. Pop that from whatever data structure EASy68K.
	trap	#15

	bsr.w	GetPlayerName					; Get keyboard input from player. This automatically enters their name and score to the table.
	bsr.w	BubbleSortScores				; Sort the table.
	lea.l	newHighScores, a0				; Get the "new" table.
	bsr.w	PrintHighScores					; Print the "new" table.
	
	lea.l	highScoreFilename, a1			; Open the high-score file.
	move.b	#FOPEN, d0
	trap	#15
	
	lea.l	newHighScores, a1				; Write the scores back to the file.
	move.l	#NUM_HIGH_SCORES*BYTES_PER_HIGH_SCORE, d2
	move.b	#FWRITE, d0
	trap	#15

	move.b	#FCLOSE, d0						; Close the file.
	trap	#15

	move.b	#0, d1							; Opening a file re-enables keybaord echo. So disable it.
	move.l	#ECHO, d0
	trap	#15

	lea.l	enterToMainMenuString, a1		; Inform them that they can press ENTER to return to the Main Menu.
	move.l	#ENTER_TO_MAIN_MENU_X, d1
	move.l	#ENTER_TO_MAIN_MENU_Y, d2
	move.l	#PRINTAT, d0
	trap	#15

	lea.l	escToQuitString, a1				; Inform them that they can press ESC to quit.
	move.l	#HIGH_SCORE_ESC_TO_QUIT_X, d1
	move.l	#HIGH_SCORE_ESC_TO_QUIT_Y, d2
	move.l	#PRINTAT, d0
	trap	#15

	bsr.w	WaitForInput
	bra.w	START							; Jump back to main menu. This is not a subroutine call.

; Pre:
; Ensure there's no chars in EASy68K waiting to be processed.
; Post:
; Will wait for the player to enter their 3-char name and will add it as well as their score to the beginning of newHighScores.
GetPlayerName:
	lea.l	yourScoreString, a1				; Print "Your Score"
	move.l	#YOUR_SCORE_X, d1
	move.l	#YOUR_SCORE_Y, d2
	move.b	#PRINTAT, d0
	trap	#15

	move.l	score, d0						; Print their score.
	lea.l	decimalString, a0
	bsr.w	ToDecimalString
	move.l	a0, a1
	move.l	#HIGH_SCORE_NUMBER_X, d1
	move.l	#(YOUR_SCORE_Y+HIGH_SCORE_CHAR_HEIGHT), d2
	move.b	#PRINTAT, d0
	trap	#15

	; Have them type in their 3-char name.
	clr.l	d7								; Our index in the string.
	clr.l	(a1)							; Reusing decimalString in a1 as a place to put the player's name. Fill it with NULL terminators really quick.
.Loop
	move.b	#GETCH, d0
	trap	#15

	cmp.b	#ENTER, d1						; Only when they press ENTER does the loop end.
	bne.b	.NoEnter
	cmp.l	#(SCORE_STRING_LENGTH), d7		; If they're trying to submit but they don't have 3 chars yet, don't listen.
	bne.b	.NoEnter
	lea.l	newHighScores, a0				; Put this name and score in the high score table.
	move.l	(a1), (a0)
	move.l	score, (SCORE_STRING_LENGTH+1)(a0)
	rts
.NoEnter

	cmp.b	#BACKSPACE, d1
	bne.b	.NoBackspace
	sub.l	#1, d7
	move.b	#SPACE, (a1,d7)					; Put a SPACE at the last char to "erase" it.
	bra.b	.Continue
.NoBackspace

	cmp.l	#(SCORE_STRING_LENGTH), d7		; If they're trying to type a char, but they're already at 3, don't bother.
	beq.b	.Continue

	cmp.b	#'a', d1
	blt.b	.Loop							; Out of the ASCII range, try again.
	cmp.b	#'z', d1
	bgt.b	.Loop							; Out of the ASCII range, try again.

	sub.b	#('a'-'A'), d1					; Convert from lowercase to capital.
	move.b	d1, (a1,d7)						; Put this char into our string.
	add.l	#1, d7

.Continue
	move.l	#HIGH_SCORE_NAME_X, d1
	move.l	#(YOUR_SCORE_Y+HIGH_SCORE_CHAR_HEIGHT), d2
	move.b	#PRINTAT, d0
	trap	#15
	bra.b	.Loop
