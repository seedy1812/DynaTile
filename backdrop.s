; MMU 2 = HW Tiles
; MMU 7 = HW Map/Attributes

; MMU 5+6 = window into SW MAP
;      as copying a line it could straddle pages

; MMU 0+1 dyna tile variables
; when copying tiles into MMU 2 need to page into MMU 7

set_pal:
        nextreg PAL_INDEX ,a
.loop:
        ld a,(hl)
        inc hl
        Nextreg PAL_VALUE_8BIT,a
        djnz .loop
        ret

backdrop_flags: db 1
backdrop_MMU5: db 0
backdrop_MMU6: db 0
backdrop_MMU7: db 0

MAP_X: dw 0
MAP_Y: dw 0
MAP_PREV_Y: dw 0

backdrop_start:

	nextreg $1c,%00001000	; reset tilemapclipping

;       layer 3 clipping
	nextreg $1b,WINDOW_START_X/2
	nextreg $1b,+(WINDOW_START_X+WINDOW_PIXEL_WIDTH-1)/2
	nextreg $1b,WINDOW_START_Y
	nextreg $1b,WINDOW_START_Y+WINDOW_PIXEL_HEIGHT-1

; set where the map should be

        ld de,0
        ld (MAP_X),de
        ld de,0
        ld (MAP_Y),de
        ld (MAP_PREV_Y),de

	nextreg TILE_TRANS_INDEX,0 ; set transparent colour for tilemap

        nextreg PAL_CTRL,%0_011_0000  ; layer 3 pal 1 to edit
        ld a,0  ; start at index 0
        ld b,16 ; 16 colours
        ld hl,bg_pal    ; the palette
        call set_pal

        ;On , 40x32, no disable attr , pal0 , no text,0 , 512 tile ,on top of ula
        nextreg LAYER_3_CTRL,%1_0_0_0_0_0_11
        ; using inline attributes , clear default just for fun of it
        nextreg TILE_DEF_ATTR,%000000000

        ld a,LAYER3_MAP_HI
        call ReadNextReg

        ld a,LAYER3_TILE_HI
        call ReadNextReg

 
        ld a,$80|(HI(MMU_7_ADDR)&LAYER3_BANK_MASK)
        nextreg LAYER3_MAP_HI,a

        ld a, HI(MMU_2_ADDR)&LAYER3_BANK_MASK
        nextreg LAYER3_TILE_HI,a

        nextreg MMU_7,14

if USE_DYNA_TILES = 1
        call dynatiles_start
endif
        call backdrop_display
        call backdrop_update
;        my_break
;        call backdrop_remove
;        my_break

        ret

;de = y
calc_layer3_offset:
        ld b,3
        ld d,0
        bsra de,b       ; y /8

        ld d, HW_WIDTH
        mul
        ret


; de = y
; can be speeded up with a look up table
calc_map_offset:
        ld b,3
        bsra de,b       ; y /8

        ld a, MAP_WIDTH    ; how many bytes wide is the map
        push de         ;d*a
        ld e,a
        mul
        ex de,hl
        pop de
        ld d,a          ; e*a
        mul

        ld a,d
        add a,l
        ld d,a
        ld a,0
        adc a,h
        ld h,a

; hl  = bits 23->16 $00ff0000
; de = 0ffset into 8 k bank

        ex de,hl

; can go over multiple banks
; 8k-1 is $1fff
        ld  a,h
        call backdrop_set_mmu
 
        ld a,$1f
        and h
        ld h,a
        ret

backdrop_copy:
        ld b,3
        ld de,(MAP_Y)
        bsra de,b
        ex de,hl

        ld de,(MAP_PREV_Y)
        bsra de,b

        or a
        sbc hl,de

        ret z

        call backdrop_store_MMU
        ex af,af'
if USE_DYNA_TILES = 1
        call dynatile_DMA_Start
endif
        ex af,af'

        ld de,(MAP_PREV_Y)
        jp  nc,.scrolling_up

.scrolling_down:
        add de,WINDOW_PIXEL_HEIGHT
        call backdrop_remove_line       
        border 1

        ld de,(MAP_Y)
        call backdrop_copy_line    
        border 2


        jr .return

;; y increasing - so remove line at top and add to bottom
.scrolling_up:
        border 3
        call backdrop_remove_line       
        border 4

        ld de,(MAP_Y)
        add de,WINDOW_PIXEL_HEIGHT
        call backdrop_copy_line       

.return:
        ld de,(MAP_Y)
        ld (MAP_PREV_Y),de

        call backdrop_restore_MMU

        ret

backdrop_store_MMU:

        ld a,MMU_5
        call ReadNextReg
        ld (backdrop_MMU5),a

        ld a,MMU_6
        call ReadNextReg
        ld (backdrop_MMU6),a

        ld a,MMU_7
        call ReadNextReg
        ld (backdrop_MMU7),a
        ret

backdrop_set_mmu:
        swapnib
        srl a
        and 7
        add a, GAME_MAP_PAGE
        nextreg MMU_5,a
        inc a
        nextreg MMU_6,a
        ret


backdrop_restore_MMU:
        ld a,(backdrop_MMU7)
        nextreg MMU_7,a
        ld a,(backdrop_MMU6)
        nextreg MMU_6,a
        ld a,(backdrop_MMU5)
        nextreg MMU_5,a
        ret

backdrop_move
        ld hl,backdrop_flags

        bit 0,(hl)
        jr z,.otherway
        
        ld bc,(MAP_Y)
        ld a,b
        or c
        jr z, .go_down
;        add bc,-8
        dec bc
        ld (MAP_Y),bc
        ret
.go_down:
        res 0,(hl)
        ret
.otherway:
        push hl
        ld bc,(MAP_Y)
        ld hl,MAP_HEIGHT-WINDOW_PIXEL_HEIGHT
        or a
        sbc hl,bc
        ld a,h
        or l
        pop hl
        jr z,.go_up
;        add bc,8
       inc bc
        ld (MAP_Y),bc
        ret
.go_up:
        set 0,(hl)
        ret


backdrop_update:
        or a 
        ld hl,(MAP_X)
        ld bc,WINDOW_START_X
        sbc hl,bc
        jp p, .no
        add hl, 320
.no:
        ld a,h
        and 1
        nextreg LAYER3_SCROLL_X_MSB,a
        ld a, l
        nextreg LAYER3_SCROLL_X_LSB,a

        // set at top of the map - rember 8 pixel border at top
        ld a, (MAP_Y)
        sub WINDOW_START_Y
        nextreg LAYER3_SCROLL_Y,a
        ret

backdrop_display:
        call backdrop_store_MMU

if USE_DYNA_TILES == 1
        ld a,MMU_7
        call ReadNextReg
        nextreg MMU_7,GAME_TILES_PAGE

        ld hl, MMU_2_ADDR
        ld de, MMU_2_ADDR+1
        ld bc ,MMU_PAGE_SIZE-1
        ld (hl),0
        ldir
        nextreg MMU_7,a
endif



if USE_DYNA_TILES = 1
        call dynatile_store_MMU
        call dynatile_DMA_Start
endif

        ld de,(MAP_Y)

        ld b, WINDOW_HEIGHT

.loop:
        push bc
        push de

        call backdrop_copy_line

        pop de
        add de,8
        pop bc

        djnz .loop

if USE_DYNA_TILES == 0
        ld a,MMU_7
        call ReadNextReg
        nextreg MMU_7,GAME_TILES_PAGE

        ld hl, MMU_7_ADDR
        ld de, MMU_2_ADDR
        ld bc ,MMU_PAGE_SIZE
        ldir
        nextreg MMU_7,a
endif

        call backdrop_restore_MMU
        ret


backdrop_remove:
        call backdrop_store_MMU

if USE_DYNA_TILES = 1
        call dynatile_store_MMU
        call dynatile_DMA_Start
endif

        ld de,(MAP_Y)
        add de,WINDOW_HEIGHT *8
        ld b, WINDOW_HEIGHT
.loop:
        add de,-8
        push bc
        push de
        call backdrop_remove_line

        pop de
        pop bc

        djnz .loop

        call backdrop_restore_MMU
        ret

; de = y
backdrop_copy_line:
;        call Copy_Debug_Y

        push de
        call calc_map_offset

        pop de
        call calc_layer3_offset


;fix this - problems with addresses and pages
        add de, HW_MAP
        add hl,MMU_5_ADDR    ; someplace in the 8k map window to copy from

if USE_DYNA_TILES = 1
        ld b,WINDOW_WIDTH    ; 2 byts attr * 13 tiles * 2 (each tile 16 pixels)
.loop
        push bc
        push hl
        push de

        // bc = SW tile ....
        call dynatiles_AddTileSW

        pop hl
        ld (hl),c
        inc hl
        ld (hl),b
        inc hl
        ex de,hl
        pop hl

        add hl,2 

        pop bc
        djnz .loop

else
        ld bc,WINDOW_WIDTH*2    ; 2 byts attr * 13 tiles * 2 (each tile 16 pixels)
        ldir
endif

        ret

backdrop_remove_line:
;        call Delete_Debug_Y

if USE_DYNA_TILES = 1
        call calc_layer3_offset
        add de, HW_ATTR_OFFSET
        ex de,hl
        ld b,WINDOW_WIDTH    ; 2 byts attr * 13 tiles * 2 (each tile 16 pixels)
.loop
        push bc
        push hl

        call dynatiles_RemoveTileHW

        pop hl
        inc hl
        inc hl

        pop bc
        djnz .loop
endif
;        my_break
        ret


        SEG GAME_MAP_SEG

bg_map: include "gfx/ww1.txm"
bg_map_length: equ *-bg_map

        SEG GAME_TILES_SEG

bg_tiles:incbin "gfx/ww1.nxi"
bg_tiles_length: equ *-bg_tiles


        SEG CODE_SEG

bg_pal: incbin "gfx/ww1.nxp"
bg_pal_length: equ *-bg_pal

                
