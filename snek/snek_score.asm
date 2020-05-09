; scorekeeper


_endgame:
	call _clear_screen
	ld a, _scrattr_ascii_n			; Normal Text
	ld (_text_attr), a
	; which endgame do you get?
	ld a, (_high_score)
	ld b, a
	ld a, (_cur_score)
	cp b
	jr c, _bleh

	; you got it, save the hi-score
	ld (_high_score), a

	; high-score screen
	ld a, 003h				; Line 1
	ld (_cur_y), a
	ld a, 009h				; Column 22
	ld (_cur_x), a
	ld hl, _str_gameover_congrats	; "Congratulations!" (16)
	push hl
	call _printf
	ld a, 007h				; Line 1
	ld (_cur_y), a
	ld a, 00ch				; Column 22
	ld (_cur_x), a
	ld a, (_cur_score)
	ld b, 0
	ld c, a
	push bc
	ld hl, _str_gameover_hiscore	; "Hi-Score %d" (11)
	push hl
	call _printf
	ld a, 00ch				; Line 1
	ld (_cur_y), a
	ld a, 004h				; Column 22
	ld (_cur_x), a
	ld hl, _str_gameover_2			; "...key to play again"
	push hl
	call _printf
	call _hiscore_twinkle
	ret

_bleh:
	; not-the-high-score screen
	ld a, 003h				; Line 1
	ld (_cur_y), a
	ld a, 00ch				; Column 22
	ld (_cur_x), a
	ld hl, _str_gameover_1		; "Game over!" (10)
	push hl
	call _printf
	ld a, 006h				; Line 1
	ld (_cur_y), a
	ld a, 00fh				; Column 22
	ld (_cur_x), a
	ld a, (_cur_score)
	ld b, 0
	ld c, a
	push bc
	ld hl, _str_score			; "Score %d"
	push hl
	call _printf
	ld a, 008h				; Line 1
	ld (_cur_y), a
	ld a, 00ch				; Column 22
	ld (_cur_x), a
	ld a, (_high_score)
	ld b, 0
	ld c, a
	push bc
	ld hl, _str_gameover_hiscore	; "Hi-Score %d"
	push hl
	call _printf
	ld a, 00ch				; Line 11
	ld (_cur_y), a
	ld a, 004h				; Column 22
	ld (_cur_x), a
	ld hl, _str_gameover_2	; "...key to play again"
	push hl
	call _printf
	call _getkey_wait
	ret


; twinkle if you got the high score
; animates until you press a key, returned in a
_hiscore_twinkle:
	; animate all the twinkles
	call _twinkle_animate
	; make one new twinkle
	call _twinkle_make_one
	; delay for a while (actually for _delay_ticks, which is the snake speed)
	call _getkey_until_delay
	cp _key_none
	ret nz
	jr _hiscore_twinkle


; drop a random twinkle (if there's space)
_twinkle_make_one:
	; find the first empty twinkle slot
	ld ix, _twinkle_data
	ld b, 8	  ; number of twinkles
	ld de, 2
_twinkle_make_loop:
	push bc
	ld a, (ix+0)
	cp 0
	jr nz, _twinkle_make_next
	ld a, (ix+1)
	cp 0
	jr nz, _twinkle_make_next
	; find somewhere (sets _cur_x, _cur_y)
	call _find_empty_space
	; store coordinates in the twinkle data area
	ld a, (_cur_y)
	ld (ix+0), a
	ld a, (_cur_x)
	ld (ix+1), a
	; put twinkle-first-char on the screen
	ld a, 0a2h
	call _put_char_on_board
	pop bc
	ret
_twinkle_make_next:
	; move to the next one
	inc ix
	inc ix
	pop bc
	djnz _twinkle_make_loop
	ret


; animate all the twinkles, once
_twinkle_animate:
	ld ix, _twinkle_data
	ld a, _scrattr_ascii_n
	ld (_text_attr), a
	ld b, 7	  ; number of twinkles
_twinkle_animate_loop:
	push bc
	ld a, (ix+0)
	cp 0
	jr z, _twinkle_update_next
	ld (_cur_y), a
	ld a, (ix+1)
	cp 0
	jr z, _twinkle_update_next
	ld (_cur_x), a
	; get the twinkle-character and increment it
	call _get_char_on_board
	inc a
	cp 0aah
	jr nz, _twinkle_update
	; finished animating this one, zero its coordinates
	ld a, 0
	ld (ix+0), a
	ld (ix+1), a
	; put a space on the screen
	ld a, _space_char
_twinkle_update:
	call _put_char_on_board
_twinkle_update_next:
	; move to the next one
	inc ix
	inc ix
	pop bc
	djnz _twinkle_animate_loop
	ret


_twinkle_data_len: equ 010h

_twinkle_data:
	; space for 8 twinkles (x, y screen-coordinate words)
	defs _twinkle_data_len, 0

_twinkle_data_end: equ _twinkle_data + _twinkle_data_len


_cur_score:
	;; yes we keep the score
	defb 000h

_high_score:
    ;; not yet implemented
	defb 000h


_str_over:
	defb "Game over!  Do you want to exit?", 000h

_str_gameover_1:
	defb "Game over!", 000h

_str_gameover_hiscore:
	defb "Hi-Score %d", 000h

_str_gameover_congrats:
	defb "Congratulations!", 000h

_str_gameover_2:
	defb	"Press a key to play again", 000h
