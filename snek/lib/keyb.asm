_keyscan:
	push hl				; HL is used to index the keystate array
	push de				; D is the Row buffer for the keyboard matrix
	push bc				; E is the current row's bits
	push af				; B is the column counter

	ld hl, _keystates

	ld a, 001h			; Row to scan
_k_scan_row:
	ld d, a
	out (0d0h), a			; Set Row Bits

	nop
	nop
	nop
	nop
	nop

	in a, (0d0h)			; Get Col Bits

	ld b, 8
_k_store_key:
	ld e, a				; store the next columns bits...
	and 1				; extract this column
	sla (hl)			; shift the state over
	or (hl)				; OR it with the current state
	and 00fh
	ld (hl), a			; save it back to the array
	inc hl				; move on to the next array location
	ld a, e				; restore the remaining bits
	srl a				; take one down, pass it around
	djnz _k_store_key		; repeat for this entire key row
	
	ld a, d				; read the next row until we are done
	add a
	jr nz, _k_scan_row
	
	pop af				; restore all the registers we walked on
	pop bc
	pop de
	pop hl
	ret

_getkey_wait:
	call _keyscan
	call _getkey_nowait
	cp _key_none
	jr z, _getkey_wait
	ret

_getkey_nowait:
	push hl
	push de
	push bc

	ld a, (_keystates + _scancode_shift)			; C = (Ctrl << 2) | (Shift << 7)
	rr a
	rr a
	rr a
	rr a
	ld a, (_keystates + _scancode_ctrl)
	rr a
	ld c, a

	ld de, _keymatrix
	ld hl, _keystates
	ld b, 64
_gk_next_key:
	ld a, (hl)
	cp 007h							; Debounce the key press
	jr c, _gk_skip_code					; Not yet pressed for 3 consecutive reads

	jr z, _gk_decode					; Key was pressed for 3 consecutive reads

	bit 0, a						; Key is still held, do nothing
	jr nz, _gk_skip_code

	and 00fh						; Debounce the key release
	ld (hl), a						; 

_gk_skip_code:
	inc hl							; Otherwise keep going until
	inc de							; we have checked all of them
	djnz _gk_next_key

	or _key_none						; No key pressed
	jr _gk_done

_gk_decode:
	ex de, hl						; Swap to the matrix
	ld a, (hl)						; and retrieve the keycode
	ex de, hl

	cp _key_none						; We don't report invalid
	jr z, _gk_skip_code					; or modifier keys
	cp _key_ctrl						; most applications want
	jr z, _gk_skip_code					; just the ascii characters
	cp _key_shift
	jr z, _gk_skip_code

	bit 7, a						; Special characters are not
	jr nz, _gk_done						; modified here

	bit 2, c						; Handle Ctrl-[key]
	jr nz, _gk_ctrl
	
	bit 7, c						; Handle Shift-[key]
	jr nz, _gk_shift
	
_gk_done:
	pop bc
	pop de
	pop hl
	ret

_gk_ctrl:
	cp 030h							; The outlier
	jr z, _gk_ctrl_0
	bit 5, a						; Only modify valid ctrl-sequences
	jr z, _gk_done
_gk_ctrl_0:
	and 01fh
	jr _gk_done

_gk_shift:
	cp 040h							; Alpha & @ get bit 5 inverted
	jr nc, _gk_shift_alpha
	cp 030h
	jr z, _gk_shift_0					; Zero becomes underscore
	cp 02ch
	jr nc, _gk_shift_num					; 1 thru ? become ! thru /

	jr _gk_done

_gk_shift_num:
	xor 010h
	jr _gk_done

_gk_shift_alpha:
	xor 020h
	jr _gk_done

_gk_shift_0:
	ld a, _key_underscore
	jr _gk_done

_key_a:			equ 'a'
_key_b:			equ 'b'
_key_c:			equ 'c'
_key_d:			equ 'd'
_key_e:			equ 'e'
_key_f:			equ 'f'
_key_g:			equ 'g'
_key_h:			equ 'h'
_key_i:			equ 'i'
_key_j:			equ 'j'
_key_k:			equ 'k'
_key_l:			equ 'l'
_key_m:			equ 'm'
_key_n:			equ 'n'
_key_o:			equ 'o'
_key_p:			equ 'p'
_key_q:			equ 'q'
_key_r:			equ 'r'
_key_s:			equ 's'
_key_t:			equ 't'
_key_u:			equ 'u'
_key_v:			equ 'v'
_key_w:			equ 'w'
_key_x:			equ 'x'
_key_y:			equ 'y'
_key_z:			equ 'z'

_key_underscore:	equ '_'

_key_f1:		equ 0e0h
_key_f2:		equ 0e1h
_key_f3:		equ 0e2h
_key_f4:		equ 0e3h
_key_f5:		equ 0e4h
_key_f6:		equ 0e5h
_key_f7:		equ 0e6h
_key_f8:		equ 0e7h
_key_f9:		equ 0e8h
_key_f10:		equ 0e9h
_key_f11:		equ 0eah
_key_f12:		equ 0ebh

_key_more:		equ 0efh
_key_help:		equ 0edh

_key_exit:		equ 0ech
_key_halt:		equ 0eeh
_key_enter:		equ 0fah

_key_up:		equ 0f6h
_key_dn:		equ 0f7h
_key_lt:		equ 0f8h
_key_rt:		equ 0f9h

_key_pgup:		equ 0f4h
_key_pgdn:		equ 0f5h
_key_home:		equ 0f2h
_key_end:		equ 0f3h

_key_shift:		equ 0fdh
_key_ctrl:		equ 0feh
_key_none:		equ 0ffh

_scancode_null:		equ 000h
_scancode_caret:	equ 001h
_scancode_rightbracket:	equ 002h
_scancode_backslash:	equ 003h
_scancode_leftbracket:	equ 004h
_scancode_z:		equ 005h
_scancode_y:		equ 006h
_scancode_x:		equ 007h
_scancode_w:		equ 008h
_scancode_v:		equ 009h
_scancode_u:		equ 00ah
_scancode_t:		equ 00bh
_scancode_s:		equ 00ch
_scancode_r:		equ 00dh
_scancode_q:		equ 00eh
_scancode_p:		equ 00fh

_scancode_o:		equ 010h
_scancode_n:		equ 011h
_scancode_m:		equ 012h
_scancode_l:		equ 013h
_scancode_k:		equ 014h
_scancode_j:		equ 015h
_scancode_i:		equ 016h
_scancode_h:		equ 017h
_scancode_g:		equ 018h
_scancode_f:		equ 019h
_scancode_e:		equ 01ah
_scancode_d:		equ 01bh
_scancode_c:		equ 01ch
_scancode_b:		equ 01dh
_scancode_a:		equ 01eh
_scancode_at:		equ 01fh

_scancode_slash:	equ 020h
_scancode_period:	equ 021h
_scancode_minus:	equ 022h
_scancode_comma:	equ 023h
_scancode_semicolon:	equ 024h
_scancode_colon:	equ 025h
_scancode_9:		equ 026h
_scancode_8:		equ 027h
_scancode_7:		equ 028h
_scancode_6:		equ 029h
_scancode_5:		equ 02ah
_scancode_4:		equ 02bh
_scancode_3:		equ 02ch
_scancode_2:		equ 02dh
_scancode_1:		equ 02eh
_scancode_0:		equ 02fh

_scancode_space:	equ 030h
_scancode_ctrl:		equ 031h
_scancode_shift:	equ 032h
_scancode_enter:	equ 033h
_scancode_rt:		equ 034h
_scancode_lt:		equ 035h
_scancode_dn:		equ 036h
_scancode_up:		equ 037h
_scancode_more:		equ 038h
_scancode_f6:		equ 039h
_scancode_f5:		equ 03ah
_scancode_f4:		equ 03bh
_scancode_f3:		equ 03ch
_scancode_f2:		equ 03dh
_scancode_f1:		equ 03eh
_scancode_exit:		equ 03fh

_keystate_up:		equ 000h
_keystate_down:		equ 001h
_keystate_lastup:	equ 000h
_keystate_lastdown:	equ 002h
_keystate_pressed:	equ 007h
_keystate_held:		equ 00fh
_keystate_released:	equ 008h

_keystates:
	defs 64, 000h

_keymatrix:
;_keymatrix_u:
	defb 080h,  '^',  ']', '\\',  '[',  'z',  'y',  'x'		; 01
	defb  'w',  'v',  'u',  't',  's',  'r',  'q',  'p'		; 02
	defb  'o',  'n',  'm',  'l',  'k',  'j',  'i',  'h'		; 04
	defb  'g',  'f',  'e',  'd',  'c',  'b',  'a',  '@'		; 08
	defb  '/',  '.',  '-',  ',',  ';',  ':',  '9',  '8'		; 10
	defb  '7',  '6',  '5',  '4',  '3',  '2',  '1',  '0'		; 20
	defb  ' ', 0feh, 0fdh, 0fah, 0f9h, 0f8h, 0f7h, 0f6h		; 40
	defb 0efh, 0e5h, 0e4h, 0e3h, 0e2h, 0e1h, 0e0h, 0ech		; 80
