
; 16-bit xorshift pseudorandom number generator
; source: http://www.retroprogramming.com/2017/07/xorshift-pseudorandom-numbers-in-z80.html
; 20 bytes, 86 cycles (excluding ret)
;
; returns   hl = pseudorandom number
_xrnd:
	ld hl,5       ; seed must not be 0

	ld a,h
	rra
	ld a,l
	rra
	xor h
	ld h,a
	ld a,l
	rra
	ld a,h
	rra
	xor l
	ld l,a
	xor h
	ld h,a

	ld (_xrnd+1),hl
	ret
