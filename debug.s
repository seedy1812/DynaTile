
TXT_Released:  db "Release = %d : %d",0
TXT_Released1: dw 0
TXT_Released2: dw 0

TXT_FirstFree:  db "FirstFree = %d",0
TXT_FirstFree1: dw 0

TXT_Last:  db "Last = %d",0
TXT_Last1: dw 0

TXT_FirstEntry:  db "Entry[%d] = %d : %d",0
TXT_FirstEntry1: dw 01
TXT_FirstEntry2: dw 02
TXT_FirstEntry3: dw 03

TXT_Count:  db "Count = %d",0
TXT_Count1: dw 0

;\0 = type
;\1 = addrlo
;\2 = addrhi
my_SetBRK macro
;        my_break
        db $ED,$01
        db \0
        dw \1
       dw \2
endm

my_ClrBRK macro
        db $ED,$02
        db \0
        dw \1
        dw \2
endm


if 0




_DEBUGOUT macro
        push hl
        ld hl ,\0
        RST	$18
        pop hl
endm

else

_DEBUGOUT macro
        push hl
        ld hl ,\0
        call my_DBG_OUT
        pop hl
endm

my_DBG_OUT:
        push af
        ld a,MMU_0
        call ReadNextReg
        push af
        nextreg MMU_0,255

        RST	$18

        pop af
        nextreg MMU_0,a
        pop af
        ret
endif

debug_Count1:
        push hl
        push bc

        ld c,(hl)
        inc hl
        ld b,(hl)
        ld (TXT_Count1),bc

        ld hl,TXT_Count
        call my_DBG_OUT 
        
        pop bc
        pop hl
        ret


debug_release:
        push hl

        ld (TXT_Released1),bc
        ld (TXT_Released2),de

        ld hl,TXT_Released
        call my_DBG_OUT 
        
        pop hl
        ret


dynatile_debug:
        push af
        push de
        push hl

        ld de,(FirstFree)               ;; 1st free HW tile
.loop
       ld (TXT_FirstEntry1),de

        push de
        ld hl, HtoS
        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)

        ld a,d
        or e
        inc a

        ld (TXT_FirstEntry3),de
        pop de

        jr z,.ok

        my_break
        jr .exit

.ok:

        push de
        ld hl, FreeList

        add hl,de
        add hl,de
        ld e,(hl)
        inc hl
        ld d,(hl)
        pop hl
        or a
        sbc hl,de
        jr z, .same

        ld (TXT_FirstEntry2),de


        _DEBUGOUT TXT_FirstEntry

        bit 7,d
        jr z,.loop
.same:
     
        ld hl,(FirstFree)
        ld (TXT_FirstFree1),hl
        _DEBUGOUT TXT_FirstFree

        ld hl,(LastFree)
        ld (TXT_Last1),hl
        _DEBUGOUT TXT_Last
.exit:
        pop hl
        pop de
        pop af
        ret

