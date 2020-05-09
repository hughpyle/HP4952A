all: snek.app

clean:
	rm *.app

%.app: %.asm snek_getkey.asm snek_tail.asm snek_score.asm \
			 xrnd.asm lib/screen.asm lib/printf.asm lib/keyb.asm \
			 lib/delay.asm lib/splash.asm lib/strap.asm lib/header.asm
	z80asm -o $@ $<
