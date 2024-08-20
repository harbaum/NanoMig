# Gowin EDA on Linux

Tested with:

  - Gowin EDA V1.9.9.03 Education
  - Gowin EDA V1.9.10 and V1.9.10.1

Tested on:
  - Debian Testing/trixie
  - Ubuntu 24.04

With some adaptions the instructions described here should also work on other Linux distributions.

## Installation

As regular user extract the EDA and the Programmer tarballs into the same directory e.g. `gowin`. This creates two directories, `IDE` and `Programmer`:

```
gowin/
├── IDE
├── Programmer
```

The installation of the udev rules file `50-programmer_usb.rules` from `Programmer/Driver` is not necessary.
The file contains a rule to unload the `ftdi_sio` kernel module - with proper configuration (the regular user is allowed to run `sudo modprobe`) the Programmer does this anyways, see section `Errors and solutions/Programmer` below.

Be aware however that when module `ftdi_sio` is removed from the system the `/dev/ttyUSBx` serial connections are not available anymore.
These are required e.g. for the Tang Nano 20K [Unboxing tutorial](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/example/unbox.html).

To make the serial connections available again run `sudo modprobe ftdi_sio`.

## Errors and solutions

### Runtime errors EDA/Programmer

1. EDA fails to start

    **Error message on console:**

    ```
    $ IDE/bin/gw_ide
    IDE/bin/gw_ide: symbol lookup error: /lib/x86_64-linux-gnu/libfontconfig.so.1: undefined symbol: FT_Done_MM_Var
    ```

    **Fix:**

    `export LD_PRELOAD=/lib/x86_64-linux-gnu/libfreetype.so`

    or rename the offending library

    `mv IDE_V1.9.10/lib/libfreetype.so.6 IDE_V1.9.10/lib/libfreetype.so.6.disabled`

2. Programmer fails to start from EDA

    **Error message on console:**

    `Programmer/bin/programmer: Programmer/bin/libz.so.1: version 'ZLIB_1.2.3.4' not found (required by /lib/x86_64-linux-gnu/libpng16.so.16)`

    **Fix:**

    `export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libz.so`

Combined `LD_PRELOAD` to start `IDE/bin/gw_ide`:

`export LD_PRELOAD='/lib/x86_64-linux-gnu/libfreetype.so /usr/lib/x86_64-linux-gnu/libz.so'`

3. Qt: Session management error

    **Error message on console:**

    `Qt: Session management error: Authentication Rejected, reason : None of the authentication protocols specified are supported and host-based authentication failed`

    **Fix:**

    `unset SESSION_MANAGER`

### Programmer

1. `Error: Cable open failed.` when start to program the FPGA.

    **Error message in systemd journal/journalctl:**

    `user NOT in sudoers ; PWD=/opt/gowin/Programmer/bin ; USER=root ; COMMAND=/usr/sbin/modprobe -r ftdi_sio`

    **Fix:**

    As root user create sudoers config file `gowin_fpga_designer`.
    
    Run `visudo /etc/sudoers.d/gowin_fpga_designer`, file content:
 
    `<yourusername>  ALL = (root) NOPASSWD: /usr/sbin/modprobe`
    
    e.g.:
    
    `joe  ALL = (root) NOPASSWD: /usr/sbin/modprobe`

2. `Error: Error found!` when start to program the FPGA.

    **Error message in `Log Viewer` -> `query`:**

    ```
    2024-08-04 16:44:56,714 - ERROR :
    1927@gw: removeftdi_sio--[Errno 13] Permission denied: '/etc/modprobe.d/ftdi_sio.conf'
    ```

    **Fix:**
    
    As root user run
    ```
    touch /etc/modprobe.d/ftdi_sio.conf
    chmod 664 /etc/modprobe.d/ftdi_sio.conf
    chgrp plugdev /etc/modprobe.d/ftdi_sio.conf
    ```

    This assumes your regular user account is a member of group `plugdev`.

3. `Error: Spi flash not found.` when start to program the external flash of FPGA.

    **Error message in Programmer:**

    `Error: Spi flash not found.`

    **Fix:**

    Try again. Usually it works on the second run.

## Miscellaneous useful information

* [Make sure the programmer download frequency is equal or lower than 2.5MHz](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-Doc/questions.html#Download-frequency)
* [Programmer/EDA Questions & Answers](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-Doc/questions.html)
* Log files of Gowin EDA can be found in directory `~/.cache/GowinSemi/IDE`