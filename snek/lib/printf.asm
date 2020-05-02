
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; This is a simple version of printf.  It works on a null-terminated 
; format string, with the following parameter types:
;
; %s	null-terminated ASCII string
; %d	single-byte unsigned int
; %c    ASCII character
;
; The single-byte unsigned int is printed in decimal, with leading 
; zeroes dropped.  To print single '%' characters, double them up 
; (e.g. "%%").
;
; Parameters are pushed onto the stack in reverse order, format string
; last.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

_printf:
	pop bc
	pop hl
_charloop:
	ld a,(hl)
	cp 000h
	jr z,_nullterm
	cp '%'				; this is a parameter
	jr z,_parameter
	call _writechar		; this is just a plain ol' ASCII character
_nextchar:
	inc hl
	jr _charloop

_nullterm:
	push bc
	ret

_parameter:
	inc hl				; get the next char, which is the type
	ld a,(hl)
	cp '%'
	jr z,_prcent		; a plain '%' character
	cp 'c'
	jr z,_prchr			; a single ASCII character
	cp 's'
	jr z,_prstr			; a string
	cp 'd'          
	jr z,_prdec			; a number (8-bit)
	cp 'x'          
	jr z,_prhex			; a number (8-bit)

_prstr:
	pop de				; print a simple null-terminated string
_nextcharstring:
	ld a,(de)
	cp 000h
	jr z,_nulltermstring
	call _writechar
	inc de
	jr _nextcharstring
_nulltermstring:
	jr _nextchar

_prcent:
	call _writechar		; it's a simple '%' character
	jr _nextchar

_prchr:
	pop de				; print an ASCII character
	ld a,e
	call _writechar
	jr _nextchar

_prdec:
	pop de
	push hl				; we'll be needing this later
	ld a,e
	ld hl,_hundreds		; reset the place counts
	ld (hl),000h
	ld hl,_tens
	ld (hl),000h
	ld hl,_ones
	ld (hl),000h

_dohundreds:			; count the hundreds in the number
	ld d,064h
	ld hl,_hundreds
_nexthundred:
	sub d
	jr c,_dotens
	inc (hl)
	jr _nexthundred

_dotens:				; count the tens in the number
	add d
	ld d,00ah
	ld hl,_tens
_nextten:
	sub d
	jr c,_doones
	inc (hl)
	jr _nextten

_doones:				; whatever is left is the ones
	add d
	ld (_ones),a

	ld d,0

_printhundreds:
	ld a,(_hundreds)
	cp 000h
	jr z,_printtens		; skip leading zeroes
	add a,030h			; print the hundreds
	call _writechar
	ld d,1

_printtens:
	ld a,(_tens)
	add d
	cp 000h
	jr z,_printones		; skip leading zeroes
	sub d
	ld d,1
	add a,030h			; print the tens
	call _writechar

_printones:
	ld a,(_ones)
	add a,030h			; print the ones
	call _writechar

	pop hl				; take hl back off the stack, oh for more registers
	jp _nextchar

_prhex:
	pop de
	push hl				; we'll be needing this later
	ld a,e
	ld hl,_tens
	ld (hl),000h
	ld hl,_ones
	ld (hl),000h

_dohexh:
	ld d,010h
	ld hl,_tens
_nexthexh:
	sub d
	jr c,_dohexl
	inc (hl)
	jr _nexthexh

_dohexl:				; whatever is left is the ones
	add d
	ld (_ones),a

	ld d,0

_prhexh:
	ld a,(_tens)
	cp 00ah
	jp p,_prhexha		; alphas
	add a,030h			; print the tens
	call _writechar
	jr _prhexl

_prhexha:
	add a,037h
	call _writechar

_prhexl:
	ld a,(_ones)
	cp 00ah
	jp p,_prhexla		; alphas
	add a,030h			; print the ones
	call _writechar
	jr _prhexdone

_prhexla:
	add a,037h
	call _writechar

_prhexdone:
	pop hl				; take hl back off the stack, oh for more registers
	jp _nextchar


_hundreds:
	defb 000h

_tens:
	defb 000h

_ones:
	defb 000h