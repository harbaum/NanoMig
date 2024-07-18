#
# Makefile
#

all: test_rom.bin

test_rom.bin: test_rom.s
	./vasm-mirror/vasmm68k_mot -Fbin test_rom.s -o test_rom.bin
