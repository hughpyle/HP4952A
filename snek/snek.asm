; snek
; for HP4952A protocol analyzer
; copyright (c) 2020 by Hugh Pyle
; this file released under MIT license

; library files are (c) by David Kuder and contributors
; licensed separately https://github.com/dkgrizzly/4952oss
; this project wouldn't exist without his work
include "lib/header.asm"
include "lib/strap.asm"

	org 02071h
	seek 00871h
_splash_screen_data:
	defb 0ffh

	defb 003h, 008h, _scrattr_ascii_n
	defb "get ready to play", 000h
	defb 006h, 00fh, _scrattr_ascii_n
	defb "snek", 000h
	defb 009h, 009h, _scrattr_ascii_n
	defb "on the HP 4952A", 000h
	defb 00ah, 008h, _scrattr_ascii_n
    defb "protocol analyzer", 000h

	defb 000h			;; End of Screen Data

_splash_menu_data:
	defb "Re-!BERT!Remote!Mass !snek!Self~"
	defb "set!Menu!&Print!Store!SNEK!Test|"

_p_main_menu_page_one:
	defw 08336h			;; First Page Menu Data
_p_mm_autoconfig:
	defw 0141ch			;; Ordinal 120h Auto Config
_p_mm_setup:
	defw 0b5a8h			;; Entry Point for Setup
_p_mm_mon:
	defw 0100dh			;; Entry Point for Monitor Menu
_p_mm_sim:
	defw 01013h			;; Entry Point for Sim Menu
_p_mm_run:
	defw 0b9ffh			;; Entry Point for Run Menu
_p_mm_exam:
	defw 013cdh			;; Ordinal 12eh Examine Data
_p_mm_next1:
	defw _p_main_menu_page_two	;; Next Page

_p_main_menu_page_two:
	defw _splash_menu_data		;; Second Page Menu Data
_p_mm_reset:
	defw 0bb1ah			;; Entry Point for Re-Set
_p_mm_bert:
	defw 0b22ch			;; Entry Point for BERT Menu
_p_mm_remote:
	defw 0d963h			;; Entry Point for Remote & Print
_p_mm_masstorage:
	defw 00f0ch			;; Entry Point for Mass Storage
_p_mm_launch_app:
	defw _launch_app		;; Entry Point for Application
_p_mm_selftest:
	defw 0136fh			;; Ordinal 12ah Self Test
_p_mm_next2:
	defw _p_main_menu_page_one	;; Next Page

_launch_app:
	ld a, 006h
	call 00e60h				; Page in 6
	ld hl,0aa00h			; Copy application to Work RAM
	ld de,_code_start		;
	ld bc,_code_end-_code_start	;
	ldir				;
	jp _app_main			; Run the application

_splash_end:

;; The screen has 16 rows of 32 characters, each char is 
;; - blank: 020h (space), or 
;; - food: 07fh
;; - border: $99 thru $9c
;; - whatever's in the score display
;; - tail: $B0 plus "quadrant bits"
;;		0001 - upper left
;;		0010 - upper right
;;		0100 - lower left
;;		1000 - lower right
;;      * but if all are set, use "inverted space", 0E4h with "invert" attr
;; When setting a position,
;; - get the value
;; - check if it's food, and handle appropriately
;; - add bits to make the new value
;; - if nothing changed, we hit a wall (it was already set).

; consts
_food_char: equ 07fh
_space_char: equ 020h

_scrattr_food: equ 083h			; normal

;; Main Application
	org 2200h
	seek 0a00h
_code_start:
_app_main:
	call _initialize_data
	call _clear_screen
	call _draw_borders

_main_loop:
	call _getkey_until_delay
	cp _key_lt
	jr z, _face_left
	cp _key_rt
	jr z, _face_right
	cp _key_up
	jr z, _face_up
	cp _key_dn
	jr z, _face_down
	cp _key_f1
	jr z, _turn_left
	cp _key_f2
	jr z, _turn_right
	cp _key_exit
	jr z, _exit_prompt
	cp _key_more
	call z, _go_faster

_main_loop_continues:
	call _move_one_step
	call _make_food
	call _status_display

	jr _main_loop



;; ---- main-loop routines (jump back to main-loop) ----


;; orientations: (LURD)

_face_left:
	ld a, 000h
	ld (_orientation), a
	jr _main_loop_continues

_face_up:
	ld a, 001h
	ld (_orientation), a
	jr _main_loop_continues

_face_right:
	ld a, 002h
	ld (_orientation), a
	jr _main_loop_continues

_face_down:
	ld a, 003h
	ld (_orientation), a
	jr _main_loop_continues

_turn_left:
	;; decrement orientation
	ld a, (_orientation)
	dec a
	and 3
	ld (_orientation), a
	jr _main_loop_continues

_turn_right:
	;; increment orientation
	ld a, (_orientation)
	inc a
	and 3
	ld (_orientation), a
	jr _main_loop_continues


; to go faster, decrement the delay-ticks a few times (no further than 1)
_go_faster:
	ld a, (_delay_ticks)
	dec a
	jr z, _main_loop_continues
	dec a
	jr z, _main_loop_continues
	dec a
	jr z, _main_loop_continues
	dec a
	jr z, _main_loop_continues
	dec a
	jr z, _main_loop_continues
	dec a
	jr z, _main_loop_continues
	dec a
	jr z, _main_loop_continues
	dec a
	jr z, _main_loop_continues
	dec a
	jr z, _main_loop_continues
	dec a
	jr z, _main_loop_continues
	ld (_delay_ticks), a
	ret


_exit_prompt:
	call _clear_screen

	ld a, _scrattr_ascii_n			; Normal Text
	ld (_text_attr), a
	ld a, 008h						; Line 1 (Top)
	ld (_cur_y), a
	ld a, 001h						; Column 1 (Left)
	ld (_cur_x), a

	ld hl, _str_exit
	ld a, (_game_in_progress)
	cp 0
	jr nz, _exit_not_over 
	ld hl, _str_over
_exit_not_over:
	call _writestring
_wait_exit:
	call _getkey_wait
	cp 'y'
	jr z, _real_exit
	cp 'Y'
	jr z, _real_exit

	cp 'n'
	jp z, _app_main
	cp 'N'
	jp z, _app_main

	jr _wait_exit

_real_exit:
	call _clear_screen

	jp 014d5h				; Return to main menu.



; ======================== ------ subroutines ------ =========================


_die:
	ld a, 0
	ld (_game_in_progress), a
	call _splode
	call _splode
	; TODO pop the stack fwiw
	jr _exit_prompt


_move_one_step:
	;; (x=h, y=l)
	ld hl, (_position)		;; 'pixel coordinates', top left zero
	ld a, (_orientation)	;; LURD = 0123
_move_test_1:
	or a					;; cp 0, if the orientation is leftward
	jr nz, _move_test_2
	dec h
	jr _move_done
_move_test_2:
	dec a				    ;; 1=up
	jr nz, _move_test_3
	dec l
	jr _move_done
_move_test_3:
	dec a				    ;; right
	jr nz, _move_test_4
	inc h
	jr _move_done
_move_test_4:
	dec a				    ;; down
	jr nz, _move_done
	inc l
_move_done:
	;; store new position
	ld (_position), hl
	or a
	srl h	;; convert from pixels to screen-coordinates
	or a
	srl l	;; convert from pixels to screen-coordinates
	ld a, l
	ld (_cur_y), a
	ld a, h
	ld (_cur_x), a
	;; test absolute coords first
	dec a
	dec a
	cp 01eh
	jr nc, _die
	ld a, l
	dec a
	dec a
	cp 00eh
	jr nc, _die

	;; hit-test for food or borders
	call _get_char_on_board
	cp _food_char 	; food
	jr z, _eat
	cp 099h 	; border
	jr z, _die
	cp 09ah 	; border
	jr z, _die
	cp 09bh 	; border
	jr z, _die
	cp 09ch 	; border
	jr z, _die
	jr _update_char_at


_die_2:
	; trampoline
	jr _die


_update_char_at:
	;; update the character [a] for our new _position
	
	; save a copy of the character in c for later
	ld c, a

	; it's 0x20 or (0xb0 plus pixels)
	; after this it'll be (0xb0 plus pixels)
	or 0b0h
	ld b, a

	ld a, _scrattr_graphics
	ld (_text_attr), a

	;; pixel characters for tail: $B0 plus "quadrant bits"
	;;		0001 - 1 - upper left	- x is even, y is even
	;;		0010 - 2 - upper right  - x is odd, y is even
	;;		0100 - 4 - lower left   - x is even, y is odd
	;;		1000 - 8 - lower right  - x is odd, y is odd
	;; (x=h, y=l) pixel-coordinates
	ld hl, (_position)
	ld a, h
	and 001h
	sla a
	sla a
	sla a
	sla a
	ld d, a
	ld a, l
	and 001h
	or d
	; now 'a' has the top nybble = whether x is even or odd,
	; and lower nybble = whether y is even or odd
	cp 000h
	jr nz, _what1
	ld a, 001h
	jr _add_the_pixel
_what1:
	cp 010h
	jr nz, _what2
	ld a, 002h
	jr _add_the_pixel
_what2:
	cp 001h
	jr nz, _what3
	ld a, 004h
	jr _add_the_pixel
_what3:
	cp 011h
	jr nz, _add_the_pixel
	ld a, 008h
_add_the_pixel:
	or b

	; special test for "all quadrants set" because the character doesn't fill (!),
	; so instead use 0E4h (space) with "invert" attr 8b
	cp 0bfh
	jr nz, _not_all_filled
	ld a, _scrattr_ascii_i
	ld (_text_attr), a
	ld a, 0e4h

_not_all_filled:
	; save for display
	ld (_cur_cell), a

	; Test whether it's different (c!=a)
	; If the same as original, we hit something that was already there
	; i.e. the snake ran into its tail, & die.
	cp c
	jr z, _die_2

	; ok, paint
	call _put_char_on_board
	ret


_eat:
	; moar scoar
	ld a, (_cur_score)
	inc a
	ld (_cur_score), a
	; no food now
	ld a, 0
	ld (_have_food), a
	; go faster
	call _go_faster
	; TODO extend the tail etc
	; clear the space where food was
	ld a, _scrattr_ascii_n
	ld (_text_attr), a
	ld a, (_food_x)
	ld (_cur_x), a
	ld a, (_food_y)
	ld (_cur_y), a
	ld a, _space_char
	jr _update_char_at


_initialize_data:
	; things that we reset after game-over
	ld a, 080h
	ld (_delay_ticks), a
	ld a, 0
	ld (_have_food), a
	ld (_cur_score), a
	ret

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


;; When the snake goes off the board, game over.
;; So it's good to draw a border around the board.
;; Characters:
;;   $98 bar to right of cell (for left border)
;;   $99 bar to top
;;   $9a bar to bottom
;;   $9a bar to right
_draw_borders:
	ld a, _scrattr_graphics			; Border Text
	ld (_text_attr), a
	ld b, 00fh						; 14 rows
_draw_borders_vertical:
	ld a, b
	ld (_cur_y), a
	ld a, 001h						; first column
	ld (_cur_x), a
	ld a, 09ch						; Right Edge character
	call _put_char_on_board
	ld a, 020h						; last column
	ld (_cur_x), a
	ld a, 09bh						; Left Edge character
	call _put_char_on_board
	djnz _draw_borders_vertical
	ld b, 01fh						; 30 columns
_draw_borders_horizontal:
	ld a, b
	ld (_cur_x), a
	ld a, 001h						; first column
	ld (_cur_y), a
	ld a, 09ah						; Top Edge character
	call _put_char_on_board
	ld a, 010h						; last column
	ld (_cur_y), a
	ld a, 099h						; Bottom Edge character
	call _put_char_on_board
	djnz _draw_borders_horizontal
_corners:
	ld a, _scrattr_ascii_n
	ld (_text_attr), a
	ld a, 1
	ld (_cur_x), a
	ld a, 1
	ld (_cur_y), a
	ld a, 0a2h
	call _put_char_on_board
	ld a, 020h
	ld (_cur_x), a
	ld a, 0a2h
	call _put_char_on_board
	ld a, 010h
	ld (_cur_y), a
	ld a, 0a2h
	call _put_char_on_board
	ld a, 1
	ld (_cur_x), a
	ld a, 0a2h
	call _put_char_on_board
	ret


;; The display has "block characters" that can put 4 pixels in one
;; character cell.  But food still occupies a whole character, so
;; when placing food we need a completely-empty location.
;; Make new food at a random location
_make_food:
	; if we have food, nothing to do
	ld a, (_have_food)
	cp _food_char
	ret z
	call _xrnd
	;; is that location available?  Yes if it's a space (0x20)
	ld a, h
	and 01fh		; x, 0 to 31
	inc a
	ld (_cur_x), a
	ld (_food_x), a
	ld a, l
	and 00fh		; y, 0 to 15
	inc a
	ld (_cur_y), a
	ld (_food_y), a
	call _get_char_on_board
	cp _space_char
	ret nz		; something's there! - failed to make food, we'll try again later
	ld a, _scrattr_food  ; flashing normal text
	ld (_text_attr), a
	ld a, _food_char
	ld (_have_food), a
	call _put_char_on_board
	ret


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


;; get the char on the board at (_cur_x, _cur_y), return a.
_get_char_on_board:
	call _locxy     ; sets hl to (_cur_x, _cur_y) in the screen-buffer
	ld a, (hl)		; character
	ret


;; put the char (a) on the board at (_cur_x, _cur_y)
_put_char_on_board:
	; note _cur_x and _cur_y are 1-based screen-coordinates
	push af
	call _locxy     ; sets hl to (_cur_x, _cur_y) in the screen-buffer
	pop af
	ld (hl), a		; character
	inc hl
	ld a,(_text_attr)
	ld (hl), a		; attribute
	ret


_status_display:
	ld a, _scrattr_ascii_n			; Normal Text
	ld (_text_attr), a
	ld a, 001h				; Line 1
	ld (_cur_y), a
	ld a, 018h				; Column 24
	ld (_cur_x), a

	ld a, (_cur_score)
	ld b, 0
	ld c, a
	push bc

	ld hl, _str_status_display
	push hl
	call _printf
	ret


_splode:
	ld a, _scrattr_ascii_n
	ld (_text_attr), a
	ld a, 0a2h
_splode2:
	push af
	call _put_char_on_board
	ld bc, 02000h
	call _delay
	pop af
	inc a
	cp 0aah
	jr nz, _splode2
	ret


; ======================== ------ data area ------ =========================

;; todo store tail positions and trim the tail as we go


;; todo splode anim
;; with characters from A2 thru A9


;; todo animated bit signal
;;  8C - high
;;  8D - low
;;  8E - low-to-high edge
;;  8F - high-to-low edge
;;  A0 - hf pulse


_str_exit:
	defb " Are you sure you want to exit? ", 000h

_str_over:
	defb "Game over!  Do you want to exit?", 000h

_str_hex:
	defb "%x", 000h

_str_status_display:
	defb "Score %d", 000h

;; head of the snake
_orientation:
	;; integer LURD = 0123
	; default
	defb 002h

_position:
	;; bytes (x=h, y=l) in "pixel coordinates".
	;; Pixel-coordinates are 2x screen-coordinates since we have 2 pixels per character,
	;; so x from 0-63, y from 0-31
	defw 01f18h

_cur_score:
	;; yes we keep the score
	defb 000h

_cur_cell:
	;; contents of the current cell
	defb 000h

_game_in_progress:
	; not did we lose yet
	defb 001h

;; tail of the snake
_tail_orientation:
	defb 001h

_tail_position:
	;; bytes (x=h, y=l) in "pixel coordinates".
    defw 01f18h


_delay_ticks:
	; decrement this until morale improves
	defb 080h

_food_x:
	defb 0

_food_y:
	defb 0

_have_food:
	; nonzero if there's food
	; (should always be nonzero)
	defb 000h
	

include "lib/delay.asm"
include "lib/screen.asm"
include "lib/string.asm"
include "lib/printf.asm"
include "lib/keyb.asm"

_code_end:
;; End of Main Application

;; Fill to end of file
	org 0b0ffh
	seek 010ffh
	defb 000h
_file_end:
