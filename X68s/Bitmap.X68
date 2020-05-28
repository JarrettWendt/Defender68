*-----------------------------------------------------------
* Title      :	Bitmap
* Written by :	Jarrett Wendt
* Date       :	9/20/2019
* Description:	Displays a bitmap image with the following caveats:
*               	- Bitmaps allow long-size dimensions, but EASy68k's drawing tools only allow word-size ones.
*               	- Only one bitmap format is allowed for optimized performance:
*						- No CLUT allowed
*						- Row order must be flipped (top-down).
*						- 32-bit R8 G8 B8 A8 pixel pattern
*				The bitmap can be positioned anywhere on the screen when drawn.
*				Any chunk from the bitmap can be selected for exclusive printing by specifying a start coordinate, width, and height.
*
* These subroutines render a bitmap on the screen with the following arguments:
* a0: address of bitmap
* d0: x, y coordinate of where to draw bitmap
* d1: x, y coordinate of start chunk of bitmap
* d2: width, height of bitmap chunk
* Top left corner is origin
* Registers that are ordered pairs use the upper word for the first part of the tuple and the lower word for the second part.
*
* Inside these subroutine, the registers are used for the following:
* d0 arithmetic / trap codes
* d1 passed arg / draw x coordinte / color
* d2 draw y coordiante
* d3 x loop counter
* d4 y loop counter
* d5 bytes per row
* d6 x coord of where to draw bitmap
* d7 pixel width of bitmap chunk
* a0 address of bitmap / address of pixel
*-----------------------------------------------------------

BITMAP_REGISTERS_USED	reg	d0-d7/a0

; Called by every bitmap subroutine, so it was made into a subroutine to reduce duplicate code.
; Some of the logic here is redundant for PreprocessBitmap since that subroutine doesn't actually draw the bitmap, but that's inconsequential since we only call it once.
InterpretHeader:
.PIXEL_WIDTH_LOC	equ	$12
.ARRAY_START_LOC	equ	$0A
	move.w	d2, d4		; Move the height to d4 so we can avoid swapping all the time.
	swap.w	d2			; Swap d2 to get the width in the lower word.
	move.w	d2, d3		; Move the width to d3 so we can avoid swapping all the time.

	move.w	d0, d2		; Move the y draw coordinate to d2 so we can avoid swapping d0 all the time. Here, it will be used as part of our y draw coordinate.
	swap.w	d0			; Swap d0 to get the y coordinate in the lower word.
	move.w	d0, d6		; Move the x draw coordinate to d6 so we can avoid swapping d0 all the time.

	; Load the pixel width from the bitmap's header. Technically the width is a long, but I will assume it's a word in favor of performance because otherwise EASy68k couln't handle it.
	move.w	.PIXEL_WIDTH_LOC(a0), d5
	ror.w	#$8, d5		; Byte-swap d5.
	lsl.w	#2, d5		; Shifting by two rather than multiplying by 4 to convert number of pixels to number of bytes.
	
	; Since we're supporting two different types of bitmaps (one with alpha and one without) they have different starting addresses for the pixel array. Find that address offset.
	clr.l	d0			; Clear d0 from whatever the args were that were passed in.
	move.b	.ARRAY_START_LOC(a0), d0
	add.l	d0, a0		; Since we're only supporting one specific bitmap format, we can skip the rest of the header and go straight to the pixel array.

	; We're going to start at the end of the chunk to optimize dbra.
	; The end of the chunk is at bytes per pixel * (chunk start x + chunk width) + bytes per row * (chunk start y + chunk height)

	sub.w	#1, d4	; Subtract 1 from the height for dbra.

	move.w	d1, d0	; + chunk start y
	add.w	d4, d0	; + chunk height
	mulu.w	d5, d0	; * bytes per row
	add.l	d0, a0	; Add this number of bytes to the address.

	swap.w	d1		; Get the draw x coord in the lower word.
	clr.l	d0		; Clear d0 from the previous work.	

	move.w	d1, d0	; + chunk start x
	add.w	d3, d0	; + chunk width
	lsl.w	#2, d0	; * bytes per pixel
	add.l	d0, a0	; Add this number of bytes to the address.

	lsr.w	#2, d5	; We no longer need the total number of bytes per row. Shift right to undo the left shift we did earlier to convert number of bytes to number of pixels.
	sub.w	d3, d5	; Subtract the chunk width to get the difference in pixels from the start of a row of a chunk and the end of a row of a chunk.
	lsl.w	#2, d5	; Shift left by 2 to multiply by 4 to convert number of pixels to number of bytes.

	sub.w	#1, d3	; Subtract 1 from the width for dbra.
	move.w	d3, d7	; d7 is where we're keeping a copy of the chunk width because it'll need to be reset every iteration of the outer loop.
	add.w	d4, d2	; Add the chunk height to the start draw y coordinate to get our current draw y coordinate.
	rts

; For un-processed A8 R8 G8 B8 bitmaps.
DrawAlphaBitmap:
	movem.l	BITMAP_REGISTERS_USED, -(sp)
	bsr.b	InterpretHeader

.Loop:
	move.l	-(a0), d1		; Get the color for this pixel from the array. It will be in format GGBBRRAA.

	lsr.l	#8, d1			; Shift out the alpha bits.
	bcc.b	.Continue		; If we shifted out zeros, skip this pixel.

	move.b	#SETPEN, d0		; Set the pen color to the color we just loaded.
	trap	#15

	move.w	d6, d1			; Move the x coordinate into d1 because that's where the DRAWPIXEL trap code wants it.
	add.w	d3, d1			; Offset the x coordinate by the draw coordinate.

	move.b	#DRAWPIXEL, d0	; Draw this pixel.
	trap	#15

.Continue
	dbra.w	d3, .Loop		; See if we've reached the end (actually start) of the row.
	sub.l	d5, a0			; Decrement the address so it's ready and waiting at the next row.
	sub.w	#1, d2			; Subtract one from the y draw coordinate because we're going up to the next row.
	move.w	d7, d3			; Reset the x index.
	dbra.w	d4, .Loop		; See if we've reached the end (actually beginning) of the chunk

	movem.l	(sp)+, BITMAP_REGISTERS_USED
	rts

; For processed A8 R8 G8 B8 bitmaps.
DrawProcessedBitmap:
	movem.l	BITMAP_REGISTERS_USED, -(sp)
	bsr.b	InterpretHeader

.Loop:
	move.l	-(a0), d1		; Get the color for this pixel from the array. It will be in format GGBBRRAA.

	; NOTE: btst-ing memory might be a good option here. It could speed up alpha pixels a little at the expense of double memory access for non-alphas.
	bclr.l	#31, d1			; Test the MSB to see if there's alpha. This also sets the bit to 0 so the most significant byte is zeroed out like the DRAWPIXEL trap code wants.
	beq.b	.Continue		; If it was 0, then don't draw this pixel.

	move.b	#SETPEN, d0		; Set the pen color to the color we just loaded.
	trap	#15

	move.w	d6, d1			; Move the x coordinate into d1 because that's where the DRAWPIXEL trap code wants it.
	add.w	d3, d1			; Offset the x coordinate by the draw coordinate.

	move.b	#DRAWPIXEL, d0	; Draw this pixel.
	trap	#15

.Continue
	dbra.w	d3, .Loop		; See if we've reached the end (actually start) of the row.
	sub.l	d5, a0			; Decrement the address so it's ready and waiting at the next row.
	sub.w	#1, d2			; Subtract one from the y draw coordinate because we're going up to the next row.
	move.w	d7, d3			; Reset the x index.
	dbra.w	d4, .Loop		; See if we've reached the end (actually beginning) of the chunk

	movem.l	(sp)+, BITMAP_REGISTERS_USED
	rts

; For non-alpha X8 R8 G8 B8 bitmaps.
DrawBitmap:
	movem.l	BITMAP_REGISTERS_USED, -(sp)
	bsr.w	InterpretHeader

.Loop:
	move.l	-(a0), d1		; Get the color for this pixel from the array. It is already in format 00GGBBRR as the SETPEN trap code wants it.

	move.b	#SETPEN, d0		; Set the pen color to the color we just loaded.
	trap	#15

	move.w	d6, d1			; Move the x coordinate into d1 because that's where the DRAWPIXEL trap code wants it.
	add.w	d3, d1			; Offset the x coordinate by the draw coordinate.

	move.b	#DRAWPIXEL, d0	; Draw this pixel.
	trap	#15

	dbra.w	d3, .Loop		; See if we've reached the end (actually start) of the row.
	sub.l	d5, a0			; Decrement the address so it's ready and waiting at the next row.
	sub.w	#1, d2			; Subtract one from the y draw coordinate because we're going up to the next row.
	move.w	d7, d3			; Reset the x index.
	dbra.w	d4, .Loop		; See if we've reached the end (actually beginning) of the chunk

	movem.l	(sp)+, BITMAP_REGISTERS_USED
	rts

; Preprocesses an R8 G8 B8 A8 bitmap so that the main loop can be faster.
; This reorders the bits in memory, so only call it once and before you ever render the bitmap.
PreprocessBitmap:
	movem.l	BITMAP_REGISTERS_USED, -(sp)
	bsr.w	InterpretHeader

.Loop:
	move.l	-(a0), d1	; Get the color for this pixel from the array. It is already in format 00GGBBRR as the SETPEN trap code wants it.
	lsr.l	#7, d1		; 7 of the alpha bits are not necessary.
	ror.l	#1, d1		; Since alpha is only on or off, rotate one bit to the MSB. This is what the main loop will look for.
	move.l	d1, (a0)	; Put this preprocessed pixel data back in memory.
	dbra.w	d3, .Loop	; See if we've reached the end (actually start) of the row.
	move.w	d7, d3		; Reset the x index.
	dbra.w	d4, .Loop	; See if we've reached the end (actually beginning) of the chunk

	movem.l	(sp)+, BITMAP_REGISTERS_USED
	rts
