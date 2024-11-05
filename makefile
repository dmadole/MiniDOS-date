
all: date.bin

lbr: date.lbr

clean:
	rm -f date.lst
	rm -f date.bin
	rm -f date.lbr

date.bin: date.asm include/bios.inc include/kernel.inc
	asm02 -L -b date.asm
	rm -f date.build

date.lbr: date.bin
	rm -f date.lbr
	lbradd date.lbr date.bin

