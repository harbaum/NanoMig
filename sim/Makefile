#
# Makefile
#

# SD_EMU=1   # set to enable sd card emulation

PRJ=nanomig

OBJ_DIR=obj_dir

# the original fx68k won't simulate. Thus we use this special version for simulation
FX68K_DIR=./fx68x_verilator
FX68K_FILES= fx68k.sv fx68kAlu.sv uaddrPla.sv fx68k_MicroRom.v fx68k_NanoRom.v

MINIMIG_DIR=../src/minimig
MINIMIG_CIA=ciaa.v ciab.v cia_int.v cia_timera.v cia_timerb.v cia_timerd.v
MINIMIG_FILES=Minimig1.v Agnus.v Paula.v Denise.v Copper.v Blitter.v CIA8520.v Floppy.v Amber.v Beamcounter.v Bitplanes.v Gayle.v Gary.v Sprites.v Audio.v Clock.v

MISC_DIR=../src/misc
MISC_FILES=video_analyzer.v

ifdef SD_EMU
MISC_FILES+=sd_rw.v sdcmd_ctrl.v
endif

# point these to your verilator setup
VERILATOR_DIR=/usr/local/share/verilator/include
VERILATOR_FILES=verilated.cpp verilated_vcd_c.cpp verilated_threads.cpp

HDL_FILES=nanomig.v $(MINIMIG_FILES:%=$(MINIMIG_DIR)/%) $(FX68K_FILES:%=$(FX68K_DIR)/%)
HDL_FILES+=$(MISC_FILES:%=$(MISC_DIR)/%) 

EXTRA_CFLAGS = `sdl2-config --cflags`
EXTRA_LDFLAGS = `sdl2-config --libs`

ifdef SD_EMU
EXTRA_CFLAGS+=-DSD_EMU
VERILATOR_FLAGS=-DSD_EMU
endif

all: $(PRJ)

$(PRJ): $(PRJ).cpp ${HDL_FILES} Makefile
	verilator -O3 -Wno-fatal --trace --threads 1 --trace-underscore -top-module $(PRJ) $(VERILATOR_FLAGS) -cc ${HDL_FILES} --exe $(PRJ).cpp -o ../$(PRJ) -CFLAGS "${EXTRA_CFLAGS}" -LDFLAGS "${EXTRA_LDFLAGS}"
	make -j -C ${OBJ_DIR} -f V$(PRJ).mk

$(PRJ).vcd: $(PRJ)
	./$(PRJ)

run: $(PRJ)
	./$(PRJ)

wave: $(PRJ).vcd
	gtkwave $(PRJ).gtkw

clean:
	rm -rf obj_dir $(PRJ)
