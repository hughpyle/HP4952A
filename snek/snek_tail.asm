; snek
;-- tail stuff
;   TAIL_MAX_LEN: 			; (word) buffer size in bytes
;	_tail_tail_location:    ; (word) contains address of final entry in the tail (the next one to be removed)
;	_tail_actual_length:	; (word) how many pixels the tail is right now
;	_tail_target_length:	; (word) length in pixels that the tail should grow to
;	_tail_buff:	; space
;	TAIL_BUFF_END: equ _tail_buff + TAIL_MAX_LEN - 1

_tail_init:
	ld hl, 00020h				; initial tail is quite long
	ld (_tail_target_length), hl
	ld hl, 00000h
	ld (_tail_actual_length), hl
	ld hl, _tail_buff
	ld (_tail_tail_location), hl
	ret

_tail_put_position:
	;; put the current _position in a new slot at the head (highest address) of the tail.

	; increment the actual-length by one pixel
	ld de, (_tail_actual_length)
	inc de
	ld (_tail_actual_length), de

	; add (actual length * words) to tail-tail-location, wrapping if needed
	; - that's the head of the tail, where we'll store new data
	ld hl, (_tail_tail_location)
	add hl, de
	add hl, de
	call _wrap_hl

	; put the _position word (x=h, y=l) into (hl)
	push hl
	pop ix
	ld hl, (_position)
	ld (ix+0), l
	ld (ix+1), h

	ret

_tail_remove_end:
	;; If the tail is long enough,
	; remove the last entry (lowest address),
	; and update the display for the end of the tail.
	ld hl, (_tail_target_length)	; pixels
	ld bc, (_tail_actual_length)	; pixels
	or a
	sbc hl, bc
	ret p			; no need to remove, target > actual

	; the tail will be one pixel shorter after this
	ld hl, (_tail_actual_length)	; pixels
	dec hl
	ld (_tail_actual_length), hl

	; where is the block to remove?  Its position is in the buffer at _tail_tail_location
	ld ix, (_tail_tail_location)
	ld l, (ix+0)
	ld h, (ix+1)
	push hl
;	ld (_debug_word), hl

	; hl contains the _position word (x=h, y=l) in "pixel coordinates".
	or a
	srl h	;; convert from pixels to screen-coordinates
	or a
	srl l	;; convert from pixels to screen-coordinates
	ld a, l
	ld (_cur_y), a
	ld a, h
	ld (_cur_x), a

	ld a, _scrattr_graphics
	ld (_text_attr), a

	; get the 4-pixel block at (cur_x, cur_y) into a
	call _get_char_on_board
	cp 020h
	jr z, _pixels
	; it should be $B0 plus "quadrant bits"
	;;		0001 - 1 - upper left	- x is even, y is even
	;;		0010 - 2 - upper right  - x is odd, y is even
	;;		0100 - 4 - lower left   - x is even, y is odd
	;;		1000 - 8 - lower right  - x is odd, y is odd
	; but "all quadrants" (_quad_fill_char) is instead _special_fill_char
	cp _special_fill_char
	jr nz, _pixels
	ld a, _quad_fill_char
_pixels:
	ld b, a
;	ld (_debug_byte1), a

	; ok we can knock out the relevant pixel now
	pop hl
	call _get_quadrant_bits  ; return the bits in a, for the position in hl,
	xor 0ffh
	and b
	; if no bits are set anymore, use _space_char not $B0
	cp _quad_none_char
	jr nz, _update
	ld a, _scrattr_ascii_n
	ld (_text_attr), a
	ld a, _space_char
_update:
	; update the screen
;	ld (_debug_byte2), a
	call _put_char_on_board

	; Save the new end-of-tail pointer, one word higher
	ld hl, (_tail_tail_location)
	inc hl
	inc hl
	call _wrap_hl
	ld (_tail_tail_location), hl

	ret

_wrap_hl:
	; hl should be a pointer into the _tail_buff,
	; so if it's beyond TAIL_BUFF_END, substract the size of the buffer (TAIL_MAX_LEN).
	; Stomps on a, bc, de.  Returns new value in hl.
	push hl
	ld bc, 0
	call _how_much_do_we_need_to_subtract
	pop hl
	or a
	sbc hl, bc
	ret
_how_much_do_we_need_to_subtract:
	; amount to subtract is returned in bc
	ld de, TAIL_BUFF_END
	or a
	sbc hl, de
	ret m			; if negative: tail-buff-end is > hl, don't need to subtract anything
	ld bc, TAIL_MAX_LEN
	ret


_grow_tail:
	; make the tail "target length" longer, if we can
	ld hl, TAIL_MAX_LEN
	ld bc, (_tail_target_length)
	or a
	sbc hl, bc
	ret m			; return if negative: target > hard max
	inc bc
	ld (_tail_target_length), bc
	ret



; ======================== ------ data area ------ =========================

; Circular buffer for the tail.
;
; Each tail location stores a word (x, y) position.
; The next move, the new position is stored at the next+1 word.
; At each move, the "tail of the tail" will be shortened (unless the tail is too short already).

TAIL_MAX_LEN: equ 00400h ; (word) length of the buffer, in bytes

_tail_actual_length:
	; how many pixels the tail is right now
	defw 0

_tail_target_length:
	; length in pixels that the tail should grow to
	; adjust this to make the tail grow (NB it's a word, not a byte)
	defw 8

_tail_buff:
	; space
	defs TAIL_MAX_LEN, 0

_tail_buff_spare:
	; did someone mess up their pointer arithmetic? of course they did
	defs 4, 0

TAIL_BUFF_END: equ _tail_buff + TAIL_MAX_LEN - 1

_tail_tail_location:
	; address of final entry in the tail (the next one to be removed)
	defw _tail_buff
