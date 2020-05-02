; Print string at _cur_y, _cur_x, using _text_attr
; HL = Message (zero-terminated)
_writestring:
	ld a,(hl)			; Get character at HL
	or a				; Set flags
	ret z				; Return if zero
	call _writechar			; Print character from A
	inc hl				; Advance
	jr _writestring			; Loop
