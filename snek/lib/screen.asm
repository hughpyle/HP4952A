_scrattr_ascii_n:	equ 083h
_scrattr_ascii_i:	equ 08bh
_scrattr_ebcdic_n:	equ 043h
_scrattr_ebcdic_i:	equ 04bh
_scrattr_hextex_n:	equ 003h
_scrattr_hextex_i:	equ 00bh
_scrattr_dim:		equ 020h
_scrattr_flash:		equ 004h
_scrattr_flash2:	equ 010h
_scrattr_inverse:	equ 008h
_scrattr_graphics:	equ 080h

_scrfont_ascii:		equ 08300h
_scrfont_ebcdic:	equ 04300h
_scrfont_baudot:	equ 083c0h
_scrfont_ebcd:		equ 0c300h
_scrfont_transcode:	equ 0c380h
_scrfont_ipars:		equ 0c3c0h

_clear_screen:
	push de
	push hl
	push bc
	push af
	ld de, 04000h			; Screen Buffer
	push de
	pop hl
	ld bc, 003feh
	ld a, 020h			; ' '
	ld (hl), a
	inc hl
	ld a, _scrattr_ascii_n		; Normal Attribute
	ld (hl), a
	inc hl
	ex de,hl
	ldir
	ld a, 1
	ld (_cur_y),a
	ld (_cur_x),a
	pop af
	pop bc
	pop hl
	pop de
	ret

_backspace:
	ld a,(_cur_x)
	dec a
	jr nz,_wrcurx
	ld a,01h
_wrcurx:
	ld (_cur_x),a
	ld a, 020h
	call _putchar_raw
	jp _updatecursor

; Print char at _cur_y, _cur_x, using _text_attr
; A = Character, AF is clobbered by function
_writechar:
	push af				; Store clobbered registers
	ld a, (_cursor_enabled)
	or a
	jr z, _no_cursor

	push de
	push hl

	call _locxy
	inc hl				;
	ld a,(_text_attr)		;
	ld (hl),a			; Text Attribute

	pop hl				; Restore clobbered registers
	pop de				;
_no_cursor:
	pop af

	cp 00ah				; Newline?
	jr z,_handle_nl			;
	cp 00dh				; Carriage Return?
	jr z,_handle_cr			;
	cp 00ch				; Clear Screen?
	jr z,_clear_screen		;
	cp 008h				; Backspace?
	jr z,_backspace			;
_writechar_raw:
	call _putchar_raw
	jr _advance_cursor

_updatecursor:
	ld a, (_cursor_enabled)
	or a
	ret z

	push de				; Store clobbered registers
	push hl				;

	call _locxy
	inc hl				;

	ld a,(hl)			;
	or _scrattr_flash2
	ld (hl),a			; Text Attribute

	pop hl				; Restore clobbered registers
	pop de				;
	ret

_advance_cursor:
	ld a,(_cur_x)
	inc a				; Advance cursor
	ld (_cur_x),a
	cp 021h				; Should we wrap?
	jr c,_updatecursor		; nope

	jr _advance_line

_handle_cr:
	ld a,001h			; Wrap to same line
	ld (_cur_x),a
	jr _updatecursor

_advance_line:
	ld a,001h			; Wrap to next line
	ld (_cur_x),a
_handle_nl:
	ld a,(_cur_y)			; Advance to new line
	inc a
	ld (_cur_y),a
	cp 11h
	jr c,_updatecursor

	push hl
	push de
	push bc
	; Scroll buffer
	ld hl, 04040h
	ld de, 04000h
	ld bc, 003c0h
	ldir

	; Clear last line
	ld de, 043c0h
	ld hl, 043c0h
	ld a, ' '
	ld (hl),a
	inc hl
	ld a, _scrattr_ascii_n
	ld (hl),a
	inc hl
	ex de, hl
	ld bc, 003eh
	ldir
	pop bc
	pop de
	pop hl

	ld a,010h			; We ran out of lines!
	ld (_cur_y),a			; loop (for now)
	jr _updatecursor				;

_locxy:
	ld h,000h
	ld a,(_cur_y)			; Line
	ld l,a
	dec l				; --
	add hl,hl			; <<
	add hl,hl			; <<
	add hl,hl			; <<
	add hl,hl			; <<
	add hl,hl			; <<
	add hl,hl			; <<

	ex de,hl			; de = hl

	ld h,000h
	ld a,(_cur_x)			; Column
	dec a				; --
	add a,a				; <<
	ld l,a				;
	add hl,de			;

	ld de,04000h			; Screen Buffer
	add hl,de			;
	ret

_putchar_raw:
	push de				; Store clobbered registers
	push hl				;
	push af				;

	call _locxy

	pop af				;
	ld (hl),a			; Text Character
	inc hl				;

	ld a,(_text_attr)		;
	ld (hl),a			; Text Attribute

	pop hl				; Restore clobbered registers
	pop de				;
	ret

_cursor_enabled:
	defb 000h
_cur_x:
	defb 001h
_cur_y:
	defb 001h
_text_attr:
	defb _scrattr_ascii_n
