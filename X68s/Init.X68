*-----------------------------------------------------------
* Title      :	Init file
* Written by :	Jarrett Wendt
* Date       :	10/9/2019
* Description:	This file contains all the startup logic for Defender68. It is called again when returning to the main menu.
*-----------------------------------------------------------

; Post:
; Resets the game to its initial state upon launch.
Init:
.Screen
	move.l	#((SCREEN_WIDTH<<16)+SCREEN_HEIGHT), d1
	move.b	#RESIZE_WINDOW, d0
	trap	#15

	move.l	#DOUBLE_BUFFERING_ENABLE, d1	; Enable double buffering.
	move.b	#SETDRAWMODE, d0
	trap	#15

	move.b	#0, d1							; Disable keyboard echo.
	move.b	#ECHO, d0
	trap	#15

.Audio
	bsr.w	StopAllSounds

	lea.l	grenadeLauncherSound, a1
	move.b	#GRENADE_LAUNCHER_SOUND, d1
	move.b	#LOADSOUND, d0
	trap	#15

	lea.l	explosionSound, a1
	move.b	#EXPLOSION_SOUND, d1
	move.b	#LOADSOUND, d0
	trap	#15

	lea.l	mainMenuMusic, a1
	move.b	#MAIN_MENU_MUSIC, d1
	move.b	#LOADSOUND, d0
	trap	#15

	lea.l	backgroundMusic, a1
	move.b	#BACKGROUND_MUSIC, d1
	move.b	#LOADSOUND, d0
	trap	#15

	lea.l	missileIgnitionSound, a1
	move.b	#MISSILE_IGNITION_SOUND, d1
	move.b	#LOADSOUND, d0
	trap	#15

	lea.l	gameoverSound, a1
	move.b	#GAMEOVER_SOUND, d1
	move.b	#LOADSOUND, d0
	trap	#15

.Misc
	move.b	#FCLOSE, d0						; Close any open files if there somehow is any.
	trap	#15

	move.l	#$1000000, sp					; Ensure the stack is empty.

	move.l	#ENEMY_START_ACCELERATION, enemyAcceleration
	move.l	#PLAYER_START_POSITION, playerPosition
	move.l	#PLAYER_START_POSITION, playerPositionLastFrame

	lea.l	enemySet, a0
	bsr.w	ClearSet

	lea.l	missileSet, a0
	bsr.w	ClearSet

	lea.l	explosionSet, a0
	bsr.w	ClearSet

	lea.l	missileSet, a0
	bsr.w	ClearSet

	clr.l 	score

	bsr.w	NextRand						; Ensure we have at least a long of random numbers.
	bsr.w	NextRand

.MainMenu
	move.b	#MAIN_MENU_MUSIC, d1			; Play the main menu music in a loop.
	move.l	#PLAY_LOOP, d2
	move.b	#CONTROLSOUND, d0
	trap	#15

	lea.l	mainMenuBMP, a0
	move.l	#MAIN_MENU_POSITION, d0			; draw x, y
	clr.l	d1								; chunk x, y
	move.l	#MAIN_MENU_DIMENSIONS, d2		; width, height
	bsr.w	DrawAlphaBitmap

	lea.l	movementControlsString, a1		; Print the movement controls.
	move.w	#MOVEMENT_CONTROLS_X, d1
	move.w	#MOVEMENT_CONTROLS_Y, d2
	move.b	#PRINTAT, d0
	trap	#15

	lea.l	specialControlsString, a1		; Print the special controls.
	move.w	#SPECIAL_CONTROLS_X, d1
	move.w	#SPECIAL_CONTROLS_Y, d2
	move.b	#PRINTAT, d0
	trap	#15

	lea.l	escToQuitString, a1				; Tell them how to stop playing.
	move.w	#MAIN_MENU_ESC_TO_QUIT_X, d1
	move.w	#MAIN_MENU_ESC_TO_QUIT_Y, d2
	move.b	#PRINTAT, d0
	trap	#15

	lea.l	pressAnyKeyToBegin, a1			; Inform them that they may press any key to begin.
	move.w	#PRESS_ANY_KEY_TO_BEGIN_X, d1	; This assumes that they take some time to read the main menu, because the loading screen has to prepare first.
	move.w	#PRESS_ANY_KEY_TO_BEGIN_Y, d2
	move.b	#PRINTAT, d0
	trap	#15

	move.l	#REPAINT_SCREEN, d0				; Flush the buffer to the screen.
	trap	#15

.LoadingScreen
	bsr.w	ClearScreen						; Clear the Main Menu in preparation for loading the loading screen.

	; Pre-load the loading screen while in the Main Menu.
	; Technically, we could pre-load the whole backgroundBMP while in the Main Menu, making the Main Menu our loading screen and the actual loading screen obsolete.
	; However, this would make the Main Menu unresponsive for a little while and we can't just put some text on screen without flushing the whole buffer.
	lea.l	loadingScreenBMP, a0
	move.l	#LOADING_SCREEN_POSITION, d0	; draw x, y
	clr.l	d1								; chunk x, y
	move.l	#LOADING_SCREEN_DIMENSIONS, d2	; width, height
	bsr.w	DrawAlphaBitmap

	bsr.w	WaitForInput

	move.l	#REPAINT_SCREEN, d0				; Flush the buffer to the screen.
	trap	#15

	bsr.w	ClearScreen						; Clear the Loading Screen in preparation for loading the backgroundBMP.

.PreprocessBitmaps
	move.b	haveProcessedBitmaps, d0		; Only preprocess the bitmaps once, so not on subsequent launches of the game.
	btst.l	#0, d0
	bne.w	.BitmapsProcessed

	lea.l	backgroundBMP, a0
	clr.l	d0								; draw x, y
	clr.l	d1								; chunk x, y
	move.l	#BACKGROUND_DIMENSIONS, d2		; width, height
	bsr.w	PreprocessBitmap

	lea.l	enemySpriteArray, a1
	move.l	#NUM_ENEMY_SPRITES-1, d3
.PreprocessEnemies
	move.l	(a1)+, a0						; sprite address
	clr.l	d0								; draw x, y
	clr.l	d1								; chunk x, y
	move.l	#ENEMY_DIMENSIONS, d2			; width, height
	bsr.w	PreprocessBitmap
	dbra.w	d3, .PreprocessEnemies

	lea.l	explosionSpritesheet, a0
	clr.l	d0								; draw x, y
	clr.l	d1								; chunk x, y
	move.l	#EXPLOSION_SHEET_DIMENSIONS, d2	; width, height
	bsr.w	PreprocessBitmap

	lea.l	missileSprite, a0
	clr.l	d0								; draw x, y
	clr.l	d1								; chunk x, y
	move.l	#MISSILE_DIMENSIONS, d2			; width, height
	bsr.w	PreprocessBitmap

	lea.l	playerSprite, a0
	move.l	#PLAYER_START_POSITION, d0		; draw x, y
	clr.l	d1								; chunk x, y
	move.l	#PLAYER_DIMENSIONS, d2			; width, height
	bsr.w	PreprocessBitmap

	move.b	#$FF, haveProcessedBitmaps		; Mark that we've already done the processing for the next time we're here.
.BitmapsProcessed

	bsr.w	InitTerrain

	lea.l	backgroundBMP, a0				; Draw the backgroundBMP for the first time.
	clr.l	d0								; draw x, y
	clr.l	d1								; chunk x, y
	move.l	#BACKGROUND_DIMENSIONS, d2		; width, height
	bsr.w	DrawProcessedBitmap

	move.b	#MAIN_MENU_MUSIC, d1			; Stop the main menu music.
	move.l	#STOP_SOUND, d2
	move.b	#CONTROLSOUND, d0
	trap	#15

	move.b	#BACKGROUND_MUSIC, d1			; Play the backgroundBMP music in a loop.
	move.l	#PLAY_LOOP, d2
	move.b	#CONTROLSOUND, d0
	trap	#15

	bsr.w	DisplayScore					; Display the initial score of 0.
	bra.w	MainLoop
