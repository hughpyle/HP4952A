;; busy wait for BC * 22 + 5 cycles
_delay:
	nop						; 4 cycles
	dec bc					; 6 cycles
	ld a,b
	or c
	jr nz,_delay			; 12/7 cycles
	ret						; 10 cycles
