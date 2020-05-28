*-----------------------------------------------------------
* Title      :	Common Header
* Written by :	Jarrett Wendt
* Date       :	9/25/2019
* Description:	This is an X68 file that only contains equates, INCBINs, and defined storage.
*               The name comes from a common C/C++ naming convention where header files like this are named "common.h"
*-----------------------------------------------------------

; trap #15 codes, put these in d0.
PRINTINT		equ	3	; Displays signed number ind d1.l in decimal.
GETCH			equ	5	; read single character from keyboard into d1.b
TIME			equ	8	; Time in centiseconds (hundredths of a second) since midnight in d1.l.
ECHO			equ	12	; Turn off keyboard echo by putting 0 in d1.b. Anything else will enable echo.
SCANKEYS		equ	19	; Put a key code in each byte of d1.l. After this trap the bytes will have a boolean (00 or FF) whether or not it was pressed.
SETFONT			equ	21	; Sets the font color to d1.l, font style to d2's least significant nybble, font size to d2's 3rd byte, and font to d2's most significant byte.
SLEEP			equ	32	; Delay d1.l centiseconds.
RESIZE_WINDOW	equ	33	; Resize the simulator's output window to x = d1's upper word, y = d1's lower word.
FCLOSE			equ	50	; Closes all files.
FOPEN			equ	51	; Opens null-terminated filename in a1. FID returned in d1.l.
FREAD			equ	53	; Reads d2.l bytes into (a1) from FID in d1.l. Afterwards d2.l holds the number of bytes actually read.
FWRITE			equ	54	; Writes d2.l bytes from (a1) into FID d1.l.
FMOVE			equ	55	; Sets file d1.l position to d2.l where next read/write will take place. Files begin at byte 0.
LOADSOUND		equ	74	; Load WAV file (name in a1) into DirectX sound memory. d1.b must contain refrence number.
PLAYSOUND		equ	75	; PLay sound from DirectX sound memory. d1.b must contain reference number.
CONTROLSOUND	equ	77	; d1.b must contain reference number. d2.l contains args for what to do with player.
SETPEN			equ	80	; Sets pen  color where d1.l is $00BBGGRR.
SETFILL			equ	81	; Sets fill color where d1.l is $00BBGGRR.
DRAWPIXEL		equ	82	; Draws pixel in pen color at (d1.w, d2.w).
DRAWLINE		equ	84	; Draws line from (x1 = d1.w, y1 = d2.w) to (x2 = d3.w, y2 = d4.w).
DRAWLINETO		equ	85	; Draws line from current pen position to (x = d1.w, y = d2.w).
MOVEPEN			equ	86	; Moves pen to (x = d1.w, y = d2.w).
DRAWRECT		equ	87	; Draws rectangle defined by coordinate pair for the top right (d1.w, d2.w) and bottom left (d3.w, d4.w)
DRAWELLIPSE		equ	88	; Draws ellipse   defined by coordinate pair for the top right (d1.w, d2.w) and bottom left (d3.w, d4.w)
SETDRAWMODE		equ	92	; For enabling buffering.
SETPENWIDTH		equ	93	; Sets pen width to d1.b in pixels.
REPAINT_SCREEN	equ	94	; For flushing the buffer.
PRINTAT			equ	95	; Print's NULL terminated string at a1 at location x = d1.w, y = d2.w.

; Args for trap task CONTROLSOUND
PLAY_ONCE		equ	0
PLAY_LOOP		equ	1
STOP_SOUND		equ	2
STOP_ALL_SOUNDS	equ	3

; Args for trap task SETDRAWMODE
DOUBLE_BUFFERING_DISABLE	equ	16
DOUBLE_BUFFERING_ENABLE		equ	17

; Colors
BLACK	equ $00000000
GREY	equ	$00D3D3D3
RED		equ	$000000FF
GREEN	equ	$0000FF00
BLUE	equ	$00FF0000
ORANGE	equ	$0000AAFF
WHITE	equ	$00FFFFFF

; Font styles for d2's least significant nybble in the SETFONT trap code.
BOLD			equ	%0001
ITALIC			equ	%0010
UNDERLINE		equ	%0100
STRIKETHROUGH	equ	%1000

; Fonts for d2's most significant byte in the SETFONT trap code.
								; sizes (multiples allowed for a pixelated scaled appearance)
FIXEDSYS				equ	1	;    9
COURIER					equ	2	;       10,     12, 15
COURIER_NEW				equ	3	; 8, 9, 10, 11, 12,     14, 16, 18
LUCIDA_CONSOLE			equ	4	; 8, 9, 10, 11, 12,     14, 16, 18
LUCIDIA_SANS_TYPEWRITER	equ	5	; 8, 9, 10, 11, 12,     14, 16, 18
CONSOLAS				equ	6	; 8, 9, 10, 11, 12,     14, 16, 18
TERMINAL				equ	7	;    9,         12,     14

; ASCII Codes
BACKSPACE	equ	$08
LF			equ	$0A
CR			equ	$0D
ENTER		equ	$0D
SHIFT		equ	$10
ESC			equ	$1B
SPACE		equ $20
WASD		equ	('W'<<24)+('A'<<16)+('S'<<8)+'D'
UP			equ	'W'		; The key that makes the player go up.
DOWN		equ	'S'		; The key that makes the player go down.
BOOST		equ	SHIFT	; The key that makes the player boost.
FIRE		equ	SPACE	; The key that makes the player fire.

NUM_FRAC_BITS				equ	4		; We will have one nybble of fractional bits.

haveProcessedBitmaps		dc.b	0	; This gets set to true after the first time the scene is loaded.
							ds.w	1	; Make this next block word-aligned.
decimalString				ds.b	11	; Enough space for converting 32-bit number to a NULL terminated decimal string.

SCREEN_WIDTH				equ		1920
SCREEN_HEIGHT				equ		720
SCREEN_DIMENSIONS			equ		((SCREEN_WIDTH<<16)+SCREEN_HEIGHT)

	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
mainMenuBMP:
	INCBIN	"BMPs/mainMenu640x480_a8r8g8b8.bmp"
MAIN_MENU_WIDTH				equ		640
MAIN_MENU_HEIGHT			equ		480
MAIN_MENU_DIMENSIONS		equ		((MAIN_MENU_WIDTH<<16)+MAIN_MENU_HEIGHT)
MAIN_MENU_POSITION			equ		(((SCREEN_WIDTH-MAIN_MENU_WIDTH)/2)<<16)+(SCREEN_HEIGHT-MAIN_MENU_HEIGHT)/2
movementControlsString		dc.b	'W/S to move Up/Down',0
MOVEMENT_CONTROLS_X			equ		870
MOVEMENT_CONTROLS_Y			equ		400
specialControlsString		dc.b	'SPACE to Fire',0
SPECIAL_CONTROLS_X			equ		895
SPECIAL_CONTROLS_Y			equ		420
escToQuitString				dc.b	'ESC to Quit',0
MAIN_MENU_ESC_TO_QUIT_X		equ		905
MAIN_MENU_ESC_TO_QUIT_y		equ		440
pressAnyKeyToBegin			dc.b	'Press ENTER to Begin',0
PRESS_ANY_KEY_TO_BEGIN_X	equ		870
PRESS_ANY_KEY_TO_BEGIN_Y	equ 	600

gameOverString				dc.b	'GAME OVER',0
GAMEOVER_X					equ		895
GAMEOVER_Y					equ		120
GAMEOVER_FONT				equ		(FIXEDSYS<<24)+((9*3)<<16)+0
GAME_OVER_INPUT_DELAY		equ		150	; centiseconds.

	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
loadingScreenBMP:
	INCBIN	"BMPs/loadingScreen640x480_a8r8g8b8.bmp"
LOADING_SCREEN_WIDTH		equ		640
LOADING_SCREEN_HEIGHT		equ		480
LOADING_SCREEN_DIMENSIONS	equ		((LOADING_SCREEN_WIDTH<<16)+LOADING_SCREEN_HEIGHT)
LOADING_SCREEN_POSITION		equ		(((SCREEN_WIDTH-LOADING_SCREEN_WIDTH)/2)<<16)+(SCREEN_HEIGHT-LOADING_SCREEN_HEIGHT)/2

	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
backgroundBMP:
	INCBIN	"BMPs/pixelGalaxy_a8r8g8b8.bmp"
BACKGROUND_WIDTH			equ		SCREEN_WIDTH
BACKGROUND_HEIGHT			equ		SCREEN_HEIGHT
BACKGROUND_DIMENSIONS		equ		SCREEN_DIMENSIONS

	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
playerSprite:
	INCBIN	"BMPs/playerShip_a8r8g8b8.bmp"
PLAYER_WIDTH				equ		27
PLAYER_HEIGHT				equ		20
PLAYER_DIMENSIONS			equ		((PLAYER_WIDTH<<16)+PLAYER_HEIGHT)

PLAYER_MOVE_SPEED			equ		10	; In pixels per frame.
PLAYER_START_POSITION		equ		((PLAYER_WIDTH<<16)+(SCREEN_HEIGHT/2))
PLAYER_MIN_Y				equ		0
PLAYER_MAX_Y				equ		SCREEN_HEIGHT-PLAYER_HEIGHT-30
playerPosition				dc.l	PLAYER_START_POSITION
playerPositionLastFrame		dc.l	PLAYER_START_POSITION

	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
enemySprite1:
	INCBIN	"BMPs/enemyShip1_a8r8g8b8.bmp"
	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
enemySprite2:
	INCBIN	"BMPs/enemyShip2_a8r8g8b8.bmp"
	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
enemySprite3:
	INCBIN	"BMPs/enemyShip3_a8r8g8b8.bmp"
	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
enemySprite4:
	INCBIN	"BMPs/enemyShip4_a8r8g8b8.bmp"
	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
enemySprite5:
	INCBIN	"BMPs/enemyShip5_a8r8g8b8.bmp"
	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
enemySprite6:
	INCBIN	"BMPs/enemyShip6_a8r8g8b8.bmp"
	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
enemySprite7:
	INCBIN	"BMPs/enemyShip7_a8r8g8b8.bmp"
	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
enemySprite8:
	INCBIN	"BMPs/enemyShip8_a8r8g8b8.bmp"
enemySpriteArray:
							dc.l	enemySprite1,enemySprite2,enemySprite3,enemySprite4,enemySprite5,enemySprite6,enemySprite7,enemySprite8
NUM_ENEMY_SPRITES			equ		8
ENEMY_WIDTH					equ		27
ENEMY_HEIGHT				equ		20
ENEMY_MAX_Y					equ		SCREEN_HEIGHT-180
ENEMY_DIMENSIONS			equ		((ENEMY_WIDTH<<16)+ENEMY_HEIGHT)
MAX_ENEMIES					equ		32			; Can only handle this many enemies on screen at one time.
BYTES_PER_ENEMY				equ		10			; 2 for velocity, 4 for coords, 4 for sprite address.
enemySet:
.maxIndex					dc.w	MAX_ENEMIES-1
.bytesPerIndex				dc.l	BYTES_PER_ENEMY
enemyArray					dcb.b	MAX_ENEMIES*BYTES_PER_ENEMY,SET_SENTINEL
enemyArrayEnd
enemyCurrent				dc.l	enemyArray					; The ADDRESS of the current enemy being updated this frame.
ENEMY_START_VELOCITY		equ		15<<NUM_FRAC_BITS
ENEMY_START_ACCELERATION	equ		1
enemyAcceleration			dc.w	ENEMY_START_ACCELERATION	; Change in velocity.
ENEMY_JERK					equ		1							; Change in acceleration (fixed point).
enemySwitchTimeNext			dc.l	0							; The next time at which enemyCurrent will change.
ENEMY_SWITCH_TIME_DELTA		equ		32							; centiseconds
ENEMY_KILL_RADIUS_SQUARED	equ		20*20						; Enemy gets this close to player it's game over.

	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
missileSprite:
	INCBIN	"BMPs/playerMissile_a8r8g8b8.bmp"
MISSILE_DIMENSIONS				equ		((14<<16)+4)
MAX_MISSILES					equ		6
BYTES_PER_MISSILE				equ		6	; 2 for velocity, 4 for coords.
missileSet:
.maxIndex						dc.w	MAX_MISSILES-1
.bytesPerIndex					dc.l	BYTES_PER_MISSILE
missileArray					dcb.b	MAX_MISSILES*BYTES_PER_MISSILE,SET_SENTINEL
missileArrayEnd
MISSILE_Y_OFFSET				equ		(PLAYER_HEIGHT/2-1)
MISSILE_START_VELOCITY			equ		10<<NUM_FRAC_BITS	; The missile starts at this speed, slows by velocity (with deceleration (-acceleration)) to 0, then acelerates indefinitely.
MISSILE_ACCELERATION			equ		4
MISSILE_MAX_VELOCITY			equ		$0FFF<<NUM_FRAC_BITS
MISSILE_IGNITION_THRESHOLD		equ		250<<NUM_FRAC_BITS	; x coord where missile goes from circle to sprite as well as starts accelerating.
MISSILE_IGNITION_EPSILON		equ		5<<NUM_FRAC_BITS	; This epsilon defines when the ignition sound effect plays.
MISSILE_RADIUS					equ		4					; For when the missile hasn't reached ignition yet and is still just an ellipse.
MISSILE_UNIGNIGHTED_DIMENSIONS	equ		((MISSILE_RADIUS<<16)+MISSILE_RADIUS)
MISSILE_X_DESPAWN				equ		SCREEN_WIDTH<<NUM_FRAC_BITS
MISSILE_KILL_RADIUS_SQUARED		equ		17*17				; Squared to avoid computing square roots when computing distance.

	ds.w	1	; Store one word to ensure next INCBIN is word-aligned.
explosionSpritesheet:
	INCBIN	"BMPs/explosion_a8r8g8b8.bmp"
EXPLOSION_SHEET_DIMENSIONS		equ		((135<<16)+54)	; The dimensions of the entire sheet.
EXPLOSION_WIDTH					equ		27				; The width/height/dimensions of one chunk.
EXPLOSION_HEIGHT				equ 	27
EXPLOSION_DIMENSIONS			equ		((EXPLOSION_WIDTH<<16)+EXPLOSION_HEIGHT)
NUM_EXPLOSIONS_IN_SHEET			equ		8
explosionChunksArray:			; The chunk positions of each sprite in the spritesheet.
.topRow							dc.l	0,(EXPLOSION_WIDTH<<16),((EXPLOSION_WIDTH*2)<<16),((EXPLOSION_WIDTH*3)<<16)
.bottomRow						dc.l	EXPLOSION_HEIGHT,(EXPLOSION_WIDTH<<16)+EXPLOSION_HEIGHT,((EXPLOSION_WIDTH*2)<<16)+EXPLOSION_HEIGHT,((EXPLOSION_WIDTH*3)<<16)+EXPLOSION_HEIGHT
explosionChunksArrayEnd
MAX_EXPLOSIONS					equ		MAX_MISSILES	; It is a safe assumption that we will only have this many explosions at one time.
BYTES_PER_EXPLOSION				equ		6				; 2 index in the explosionChunksArray, 4 for coords.
explosionSet:
.maxIndex						dc.w	MAX_EXPLOSIONS-1
.bytesPerIndex					dc.l	BYTES_PER_EXPLOSION
explosionArray					dcb.b	MAX_EXPLOSIONS*BYTES_PER_EXPLOSION,SET_SENTINEL

; Audio
NUM_SOUNDS				equ		5
grenadeLauncherSound	dc.b	'WAVs/8bitChiptuneKick.wav',0
GRENADE_LAUNCHER_SOUND	equ		0							; Reference number.
explosionSound			dc.b	'WAVs/8bitFireball.wav',0
EXPLOSION_SOUND			equ		1
mainMenuMusic			dc.b	'WAVs/8bitElectrohouse.wav',0
MAIN_MENU_MUSIC			equ		2
backgroundMusic			dc.b	'WAVs/8bitArcadeMusicLoop.wav',0
BACKGROUND_MUSIC		equ		3
missileIgnitionSound	dc.b	'WAVs/8bitLaunch.wav',0
MISSILE_IGNITION_SOUND	equ		4
gameoverSound			dc.b	'WAVs/8bitArcadeGameover.wav',0
GAMEOVER_SOUND			equ		5

; Input Variables
lastButtonState	dc.l	$00000000	; For debouncing. Starting as 0 to say nothing was previously pressed.
thisButtonState	ds.l	1			; Default value is irrelivant because it will be set in the first call to Input on the first loop.

; Time Variables and Constants
CENTISECONDS_PER_FRAME	equ	3				; Becomes a little under 30fps.
lastFrameTime			dc.l	$00000000	; For figurint out if it's been enough seconds since the last frame to start the next one.
