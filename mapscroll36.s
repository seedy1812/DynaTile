USE_DYNA_TILES:		equ 1

WINDOW_START_Y:		equ 0			; where on screen map is displayed
WINDOW_START_X:		equ 0

WINDOW_WIDTH:		equ +(18*2)		; width in tiles ( 16 pixels wide so times 2)
WINDOW_HEIGHT:     	equ +(14*2+1)	; 10 tiles high (16 pixels so times 2) + 1 extra

MAP_WIDTH:			equ +(18*2*2)	; how may bytes wide
MAP_HEIGHT 			equ +(532*8)-8		; height in pixels
HW_WIDTH:      		equ 40*2		; hw ism 40 tiles *2

WINDOW_PIXEL_HEIGHT equ (WINDOW_HEIGHT*8)-8	; this is height what is seen on screen
WINDOW_PIXEL_WIDTH	equ WINDOW_WIDTH*8


VBL_ON_LINE_INTERRUPT equ 1


; next regs
LAYER_2_Y_OFFSET 	 	equ $17
LAYER2_CLIP_WINDOW   	equ $18
LINE_INT_LSB		 	equ $23
LAYER3_SCROLL_X_MSB	 	equ $2f
LAYER3_SCROLL_X_LSB	 	equ $30
LAYER3_SCROLL_Y		 	equ $31
SPRITE_NUMBER		 	equ $34
PAL_INDEX            	equ $40
PAL_VALUE_8BIT       	equ $41
PAL_CTRL			 	equ $43
PAL_VALUE_9BIT       	equ $44
TILE_TRANS_INDEX: 	 	equ $4c
MMU_0					equ $50
MMU_1					equ $51
MMU_2					equ $52
MMU_3					equ $53
MMU_4					equ $54
MMU_5					equ $55
MMU_6					equ $56
MMU_7					equ $57


MMU_PAGE_SIZE			equ $2000

MMU_0_ADDR				equ MMU_PAGE_SIZE*0
MMU_1_ADDR				equ MMU_PAGE_SIZE*1
MMU_2_ADDR				equ MMU_PAGE_SIZE*2
MMU_3_ADDR				equ MMU_PAGE_SIZE*3
MMU_4_ADDR				equ MMU_PAGE_SIZE*4

MMU_5_ADDR				equ MMU_PAGE_SIZE*5
MMU_6_ADDR				equ MMU_PAGE_SIZE*6
MMU_7_ADDR				equ MMU_PAGE_SIZE*7


COPPER_DATA				equ $60
COPPER_ADDR_LSB			equ $61
COPPER_CTRL				equ $62
LAYER_3_CTRL		 	equ $6b
TILE_DEF_ATTR		 	equ $6c
LAYER3_MAP_HI		 	equ $6e
LAYER3_TILE_HI		 	equ $6f

// next reg equates
LAYER3_BANK_MASK		equ ($80+$3f)

// z80 ports

DMA_PORT    			equ $6b ;//: zxnDMA
NEXTREG_OUT			 	equ $243b

HW_MAP 				equ MMU_7_ADDR		; location in memory for hw map

border macro
           ld a,\0
           out ($fe),a
        endm

bordera macro
           out ($fe),a
        endm

MY_BREAK	macro
        db $fd,00
		endm


	OPT Z80
	OPT ZXNEXTREG    

NUM_MAP_PAGES 	equ 4

CODE_PAGE 		equ 2*2
HW_TILES_PAGE 	equ 5*2
DYNA_PAGE 		equ 9*2

HW_ATTR_PAGE	equ $e
GAME_MAP_PAGE 	equ DYNA_PAGE+2
GAME_TILES_PAGE equ GAME_MAP_PAGE+(2*NUM_MAP_PAGES)

HW_TILES_OFFSET equ $4000
HW_ATTR_OFFSET equ $e000

GAME_MAP_PAGE_ADDR equ 0

	seg 	HW_TILES_SEG,			HW_TILES_PAGE:$0000,HW_TILES_OFFSET
	;seg		HW_ATTR_SEG,			HW_ATTR_PAGE:$0000,HW_ATTR_OFFSET
    seg     CODE_SEG, 			 	CODE_PAGE:$0000,$8000

	seg 	GAME_MAP_SEG,			GAME_MAP_PAGE:$0000,GAME_MAP_PAGE_ADDR
	seg		GAME_TILES_SEG,			GAME_TILES_PAGE:$0000,$0000				

	seg 	DYNA_SEG,				DYNA_PAGE:$0000,$0000

    seg     CODE_SEG

db "JOY1"	
JOY_Current: db 0
JOY_JustPressed: db 0
JOY_JustReleased: db 0
db "JOY2"	

start:


	ld a, 6
	call ReadNextReg
	and %01011111 
	Nextreg 6,a

	nextreg 7,%11 ; 28mhz

	ld sp , StackStart

	call init_vbl

	call video_setup

	call backdrop_start

frame_loop:
	call wait_vbl


if 0
	ld hl,JOY_Current

	my_break

	ld b,(HL)		; prev
	in a,($1f)		; cur
	ld (hl),a

	xor b			; xor prev
	and (hl)
	ld (JOY_JustPressed),a

	ld a,(hl)
	cpl				; start is not currently pressed
	and b			; and with want is pressed
	ld (JOY_JustReleased),a


;	jr z, .no_move
endif
	border 7

	call backdrop_move

.no_move:

	call backdrop_copy


	call backdrop_update

	border 0

	in a,($fe)

	jr frame_loop

video_setup:
       nextreg $68,%10000000   ;ula disable
       nextreg $15,%00000100 ; no low rez , LSU ,  sprites lo priority , no sprites
       ret

 ReadNextReg:
       push bc
       ld bc,NEXTREG_OUT
       out (c),a
       inc b
       in a,(c)
       pop bc
       ret


StackEnd:
	ds	128*3
StackStart:
	ds  2

;include "debug.s"
include "irq.s"

if USE_DYNA_TILES = 1
include "dynatile.s"
endif
include "backdrop.s"

THE_END:

 	savenex "mapscroll36.nex",start

