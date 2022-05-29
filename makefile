
date.bin: date.asm include/bios.inc include/kernel.inc
	asm02 -b -L date.asm

clean:
	-rm -f *.bin *.lst

