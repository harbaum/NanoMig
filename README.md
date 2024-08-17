# NanoMig

NanoMig is a port of the [Minimig](https://en.wikipedia.org/wiki/Minimig) to the [Tang Nano 20k](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html).

This is based on the [MiSTeryNano project](https://github.com/harbaum/MiSTeryNano/) and also relies on a [M0S Dock](https://wiki.sipeed.com/hardware/en/maixzero/m0s/m0s.html) being connected to the Tang Nano 20k. Alternately you can use a [Raspberry Pi Pico](https://www.raspberrypi.com/documentation/microcontrollers/pico-series.html) or [esp32-s2](https://www.espressif.com/en/products/socs/esp32-s2)/[s3](https://www.espressif.com/en/products/socs/esp32-s3) and use the [FPGA companion firmware](http://github.com/harbaum/FPGA-Companion).

This is currently a very early work in progress. The current version is based on the [MiSTer Minimig AGA code](https://github.com/MiSTer-devel/Minimig-AGA_MiSTer) and runs many Amiga games and demos.

Current state:

  * Minimig based on [MiSTer Minimig AGA](https://github.com/MiSTer-devel/Minimig-AGA_MiSTer)
  * Kick ROM stored in flash ROM
  * Up to 2MB chip and 1.5MB slow RAM
  * OCS and ECS chipset (no AGA!)
  * Up to four virtual floppy drives
  * HDMI video and audio, PAL and NTSC
  * Keyboard, Mouse and Joystick via USB
  * [Fully simulated](sim)

## Videos

These youtube shorts mainly document the progress:

  * [NanoMig #1: Amiga DiagROM booting on Tang Nano 20k](https://www.youtube.com/shorts/ti7aLr5Kjqc)
  * [NanoMig #2: USB keyboard and audio for the FPGA Amiga](https://www.youtube.com/shorts/5n52x6f5NDI)
  * [NanoMig #3: Booting workbench for the first time on Tang Nano 20k](https://www.youtube.com/shorts/ZvdcHXi-k2g)
  * [NanoMig #4: Running Amiga Pro tracker on the Tang Nano 20k](https://www.youtube.com/shorts/00sgeovKQa4)

## What's needed?

The necessary binaries can be found in the [project releases](https://github.com/harbaum/NanoMig/releases).

  * ```nanomig.fs``` needs to be flashed to the FPGA's flash memory
  * Kickstart 1.3 ```kick13.rom``` needs to be flashed at offset 0x400000 _and_ 0x440000
  * The latest firmware needs to be flashed to the M0S Dock
  * A default ADF disk image named ```df0.adf``` should be placed on SD card (e.g. workbench 1.3)
  * For the SD card to work [all components incl. the M0S](https://github.com/harbaum/NanoMig/issues/5) have to work properly
