; getkey routines for snek

include "lib/keyb.asm"


_key_space: equ ' '


_getkey_until_delay:
	; test the keyboard until anything happens,
	; or the delay countdown,
	; returning any key in A
	ld a, (_delay_ticks)
	ld b, a
_getkey_until2:
	call _keyscan
	call _getkey_nowait
	cp _key_none
	ret nz
	dec b
	jr nz, _getkey_until2
	ret

_getkey_pretendtropy:
	; test the keyboard until anything happens
	; (except F5 because that just started the app),
	; return a fairly-random thing in HL
	ld bc, 0ffffh ; counter
_getkey_pretendtropy2:
	dec bc
	call _keyscan
	call _getkey_nowait
	cp _key_f5
	jr z, _getkey_pretendtropy2
	cp _key_none
	jr z, _getkey_pretendtropy2
	push bc
	ld hl, 0000h
	ld bc, 0000h
	cpdr
	xor h
	pop bc
	xor b
	xor c
	ld h, a
	ret
