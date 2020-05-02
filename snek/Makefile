all: snek.app

clean:
	rm *.app

%.app: %.asm lib/screen.asm lib/printf.asm lib/keyb.asm lib/delay.asm lib/splash.asm lib/strap.asm lib/header.asm
	z80asm -o $@ $<
