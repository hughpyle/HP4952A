; scorekeeper


;	"Game over!"
;	"   Score: %d"
;	"Hi-Score: %d"
;	"Congratulations!"
;	"Press any key to play again"

_show_hiscore:
;   game over
;   if you got hi:
;   - hi-score
;   - congatulations
;   - random flashing food
;
;   otherwise:
;   - your score
;   - hi-score

    ret


_cur_score:
	;; yes we keep the score
	defb 000h

_high_score:
    ;; not yet implemented
	defb 000h
