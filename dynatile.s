USE_DMA equ 1

;/////////////////////////////////////////////////
;/////////////////////////////////////////////////
;/////////////////////////////////////////////////
;/////////////////////////////////////////////////
;/////////////////////////////////////////////////
;/////////////////////////////////////////////////
;/////////////////////////////////////////////////
;/////////////////////////////////////////////////

        SEG DYNA_SEG
NUM_HW_TILES: equ 355
MAX_TILES: equ 1500

DYNA_SEG_START:
        db "H2S_"
HtoS:    ds NUM_HW_TILES*2            ; msb -1  = free
HtoS_Length: equ *-HtoS

StoH_LABEL:  db "S2H_"
StoH2:       ds MAX_TILES*2
StoH_Length: equ *-StoH2

StoHcount_Label:        db "MANY"
StoHcount:  ds MAX_TILES*2      ; MSB -1 = free
StoHcount_Length: equ *-StoHcount

FirstFree: dw 0
LastFree: dw 0
        db "FRE1"
FreeList:   ds 2*NUM_HW_TILES
FreeList_Length: equ *-FreeList
        db "FRE2"

tileFlags:      db 0
SWtileIndex:    dw 0
HWTileIndex:    dw 0

/////////////////////////////////////////////////

       SEG CODE_SEG

dynatiles_start:

        call dynatile_store_MMU


; clear everything out
        ld hl, HtoS
        ld de, HtoS+1
        ld bc,HtoS_Length-1
        ld (hl),-1
        ldir

        ld hl, StoH2
        ld de, StoH2+1
        ld bc,StoH_Length-1
        ld (hl),0
        ldir

        ld hl, StoHcount
        ld de, StoHcount+1
        ld bc,StoHcount_Length-1
        ld (hl),-1
        ldir

        ld hl, FreeList
        ld de, 1
        ld bc, NUM_HW_TILES-1
        ld (LastFree),bc 
.fillFree:
        ld (hl),e
        inc hl
        ld (hl),d
        inc hl
        inc de
        dec bc
        ld a,b
        or c
        jr nz,.fillFree
        dec a // -1
        ld (hl),a
        inc hl
        ld (hl),a

        // first free tile is tile 0
        ld de,0
        ld (FirstFree),de

        call dynatile_restore_MMU:

        ret

;/////////////////////////////////////////////////

dynatiles_AddTileSW:
        ld e,(hl)
        inc hl
        ld d,(hl)

        ld a,0
        ld (tileFlags),a
        ld (SWtileIndex),de

        ld hl,StoHcount+1 ; looking at high byte
        add hl,de
        add hl,de


        bit 7,(hl)
        dec hl              ; point to low byte
        jr nz, .find_free_tile ; ok we have a a number so increase it

        inc (hl)
        jr nz,.no_carry
        inc hl
        inc (hl)
.no_carry:
; now get HW tile index
        ld hl,(SWtileIndex)
        add hl,hl
        add hl,StoH2
        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (HWTileIndex),bc

; now the reverse

        ld hl, HtoS
        adc hl,bc
        adc hl,bc
        ld de,(SWtileIndex)
        ld (hl),e
        inc hl
        ld (hl),d

        ld a,(tileFlags)
        ld bc,(HWTileIndex)
        ret

.error: jr .error

.find_free_tile:
        ld de,(FirstFree)       ;index of next

        bit 7,d  ;; check negative
        jr nz,.error

        ld (HWTileIndex),de

        ld hl,FreeList
        add hl,de
        add hl,de

        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (FirstFree),bc       ; point to next in list

        ; ok now link HW tile to SW one
        ld hl,HToS
        add hl,de
        add hl,de

        ld bc,(SWtileIndex)
        ld (hl),c
        inc hl
        ld (hl),b

        ; c is the index 0 ->255
;        my_break
        ld hl,StoH2
        add hl,bc
        add hl,bc
        ld (hl),e
        inc hl
        ld (hl),d

        ld hl,StoHcount ; looking at low byte
        add hl,bc
        add hl,bc
        inc (hl)
        jr nz,.no_wrap
        inc hl
        inc (hl)
.no_wrap
        // need SW tile index and hl which is the HW verison
        call dynatiles_FrameAdd

        ld bc,(HWTileIndex)

        ld a,(tileFlags)
        or b
        ld b,a

        ret


/////////////////////////////////////////////////

dynatiles_RemoveTileHW:
        ld e,(hl)
        inc hl
        ld d,(hl)
        ld hl, HtoS
        add hl,de
        add hl,de        
dynatiles_RemoveTileSW:
        ld e,(hl)
        inc hl
        ld d,(hl)

dynatiles_Remove_Cont:

        ld (SWtileIndex),de
        ld hl,StoHcount+1 ; looking at high byte
        add hl,de
        add hl,de
        bit 7,(hl)
        jr nz,.error ; error if already free
.ok:
        ld d,(hl)
        dec hl
        ld e,(hl)

        dec de
        ld (hl),e
        inc hl
        ld (hl),d

        bit 7,d
        ret z
.last_one:
        ; count is -1 so no clear out th
        ld hl,(SWtileIndex)
        add hl,hl
        add hl,StoH2

        ld e,(hl)
        inc hl
        ld d,(hl)

        ld (HWTileIndex),de

        ; no clear out HW to SW linnk
        ld de,(HWTileIndex)
        ld hl,HtoS
        add hl,de
        add hl,de
        ld (hl),-1
        inc hl
        ld (hl),-1

        ld b,d
        ld c,e
        ld de,(LastFree)
        ld (LastFree),bc


        ld hl,FreeList
        add hl,de
        add hl,de
; hL point to last one , 
        ld (hl),c
        inc hl
        ld (hl),b

        ld hl,FreeList
        add hl,bc
        add hl,bc
        ld (hl),-1
        inc hl
        ld (hl),-1

        ret
.error: jr .error

;/////////////////////////////////////////////////

dynatiles_FrameAdd:

        ld hl,(SWtileIndex)
        ld bc,(HWTileIndex)
 
        call dynatile_DMA_StartUpload   // bc = HW , HL = Software

        ret

;/////////////////////////////////////////////////

dynatile_DMA_Start:     
; set up the dma transfer - dont need to set source and dest (Page)
    ld	hl,DMAC_CopyStart
    ld  bc, DMA_PORT+(DMAC_CopyStart_End-DMAC_CopyStart)*256
    otir
    ret

;/////////////////////////////////////////////////

dynatile_DMA_StartUpload:
; bc = destination tile
; hl = source tile

; need SW index - for page and offset
; and HW tile index 

        ld a, MMU_7
        call ReadNextReg
        push af


        ld a,1
        and b
        ld d,b
        ld e,c

  ;      // 8*8/2 bytes in a tile  = 1<<6
        ld b,5
        bsla de,b
        add de,HW_TILES_OFFSET

if USE_DMA == 0
        push de
else
        ld (DMAC_QuickCopy_Dest),de
endif
        ld a,h
        add a, GAME_TILES_PAGE
        nextreg MMU_7 ,a

        ld d,8*8/2 ; was 64 but we doubled hel
        ld e,l
        mul
        add de, HW_MAP

if USE_DMA == 0
        pop hl

        ex de,hl
        ld bc,8*8/2
        ldir
else
 
        ld (DMAC_QuickCopy_Source),de

        ld hl,DMAC_QuickCopy
        ld bc, +DMA_PORT+(DMAC_QuickCopy_End-DMAC_QuickCopy)*256
        otir
endif
        pop af
        nextreg MMU_7,a
        ret

;/////////////////////////////////////////////////
        SEG DYNA_SEG

DMAC_CopyStart:
   	db $83 ; dma disable
	db %0_11_00_101 ; Transfer , port a-> B ,Port A is memory , set length
	dw 8*8/2 ; WR0 nlock lenhgth

	db %00010100 ;WR1 - Port A address increments
	db %00010000 ;WR2 - Port B address increments
	db $cf ;WR6 - Load   
DMAC_CopyStart_End:

;/////////////////////////////////////////////////

DMAC_QuickCopy
	db $83 ; dma disable

	db %0_00_11_101 ; Transfer , port a-> B , port a start (l+h)
DMAC_QuickCopy_Source
        dw 0

	db %1_010_11_01 ; WR4 continous mode , port b start (l+h)
DMAC_QuickCopy_Dest:
	dw 0

	db $cf ; WR6 - Load
	db $87 ; enable DMA  
DMAC_QuickCopy_End:

DYNA_SEG_END:

        SEG CODE_SEG

;/////////////////////////////////////////////////


dynatile_store_MMU:
        ld a,MMU_0
        call ReadNextReg
        ld (dynatile_restore_MMU_0+1),a

        ld a, DYNA_PAGE
        nextreg MMU_0,a

if DYNA_SEG_END >= 8*1024

        ld a,MMU_1
        call ReadNextReg
        ld (dynatile_restore_MMU_1+1),a

        ld a, DYNA_PAGE+1
        nextreg MMU_1,a
endif
        ret

dynatile_restore_MMU:

dynatile_restore_MMU_0:
        ld a,0
        nextreg MMU_0,a

if DYNA_SEG_END >= 8*1024
dynatile_restore_MMU_1:
        ld a,0
        nextreg MMU_1,a
endif
        ret


