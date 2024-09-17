# From Minimig to NanoMig

The [original Minimig invented in 2005 by Dennis van
Weeren](https://en.wikipedia.org/wiki/Minimig) was one of the the
first attempts to recreate the famous [Commodore
Amiga 500](https://en.wikipedia.org/wiki/Amiga) with modern
semiconductors. This implemented most of the Amiga chipset in an
[FPGA](https://en.wikipedia.org/wiki/Field-programmable_gate_array).
It still used a regular [68000
CPU](https://en.wikipedia.org/wiki/Motorola_68000), used
[SRAM](https://en.wikipedia.org/wiki/Static_random-access_memory) for
memory and a [PIC
microcontroller](https://en.wikipedia.org/wiki/PIC_microcontrollers)
was used to support floppy disk emulation and user control and helped
booting the system.

In theory the entire device could have been implemented using an FPGA
only. But since FPGAs were and are still rather expensive devices it
was reasonable to use regular off-the-shelf components where
available.

The Minimig code has been re-used in many other projects like the MiST
and [MiSTer](https://en.wikipedia.org/wiki/MiSTer) and has been
updated and developed further to e.g. implement the CPU in the FPGA as
well, use cheaper SDRAM and to support later Amiga features like the
AGA chipset of the Amiga 1200 as well.

Some very basic concepts have been untouched during this time and e.g.
the cooperation between the FPGA and the PIC microcontroller still
uses the same concepts with the microcontroller being connected to the
SD card and caring for all mass storage IO incl. harddisk simulation.

The NanoMig differs from this a little more as many of-the-shelf FPGA
boards come with an SD card slot connected to the FPGA. This allows to
reduce the dependency on the microcontoller somewhat also reducing the
microcontrollers impact on floppy and hard disk emulation
speed. Furthermore the NanoMig aims to be as independent from the
microcontroller implementation as possible with the microcontroller
only providing generic support functions that are common to many retro
related targets (e.g. Atari ST in FPGA) but avoid implementing target
specific functions in the FPGA. This should finally lead to a
microcontroller implementation that can be reused for further retro
targets without requiring updates and extensions to the
microcontroller.

The NanoMig thus relies on the a microcontroller running the [FPGA
Companion](https://github.com/harbaum/FPGA-Companion). The FPGA
Companion provides several main functions which are difficult to
implement in an FPGA or which would use up a lot of resources. This is
mainly:

  - Interfacing to USB devices like mice, keyboard and game controllers
  - Dealing with the SD cards own file system
  - Providing a means to control the system via an on-screen-display

There are several things that the microcontroller of the original Minimig
did which the NanoMig does not use the FPGA Companion for and which are
solved in the FPGA of the NanoMig. These are:

  - Booting the FPGA itself
  - Handling of the system ROMs (e.g. Amiga Kickstart ROMs)
  - Floppy disk data encoding and decoding
  - IDE hard disk interface

As a result the NanoMig can boot into Amiga Kickstart without the
microcontroller even being attached.

Still the microcontroller is needed for any useful application of
NanoMig as it's needed to simulate floppy and hard disks and to give
the user access to USB peripherals to actually use the system.

## A NanoMig without microcontroller?

Although not being implemented that way, yet, it's possible to get
a usable Amiga without using a microcontroller at all, not even
a simple one implemented inside the FPGA.

For floppy disk and hard disk IO the microcontroller is only required
to translate from the Amigas request to read or write sectors on a
floppy or hard disk to the matching sectors inside files stored on SD
card. Omitting this additional layer of complexity allows to use the
SD card as a floppy or hard drive directly. The downside of this is
that it's not possible, anymore, to store multiple floppy or harddisk
image files on an SD card. Instead the Amiga would see the entire SD
card as either a single floppy disk or hard disk. Since it doesn't
make much sense for an entire multi gigabytes SD card to be used as a
single 800k Amiga floppy disk. Instead it's probably more useful to
use an entire SD card as a hard disk.

Another solution need to be implemented for user interfacing like
keyboards, mice and joysticks. This would be possible by using [FPGA
based USB implementations](https://github.com/WangXuan95/FPGA-USB-Device) or by
not using USB peripherals at all and instead using original mice and
joysticks as used in the home computer era as these easily interface
to any FPGA without using up many resources.


