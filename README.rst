SD Card Libary
..............

:Stable release: 1.0.1

:Status:  alpha

:Maintainer:  interactive_matter

:Description:  SD card driver library


Key Features
============

* Read and write data operations on SD cards using either the SPI interface or native 4bit interface
* Port of FatFS - FAT file system module R0.09 (C)ChaN, 2011 (http://elm-chan.org/fsw/ff/00index_e.html).
* **Beware: FAT with long file names may be covered by various patents (in particular those held by Microsoft). Use of this code may require licensing from the patent holders**
* **Beware: 4bit SD protocol is subject to petents of the SD Association. When enabled on commercial products a license may be required. (see: https://www.sdcard.org/developers/howto/ )**
* Benchmark with 4bit interface multiblock read speed is about 4MBytes/sec. 1.2MBytes/sec with SPI. 

To Do
=====

* Initialization at low clock speed (400KHz max) for the 4bit interface.
* Test with SDXC card, SD physical layer ver 1.0 compliant card and MMC card (currently supported only with SPI interface).
* support for MMC/eMMC at 4 and 8bit bus.
* Date/Time function for files timestamp returning real date/time.

Firmware Overview
=================

This module provides functions to initialize SD cards, read and write data.
To enable the 4bit SD native bus interface functions it is necessary to uncomment the "//#define BUS_MODE_4BIT" in the "module_FatFs/src/diskio.h".
Resources (ports and clock blocks) used for the interface need to be specified in either "module_sdcardSPI/SDCardHostSPI.xc" or "module_sdcard4bit/SDCardHost4bit.xc" in the initialization of the SDif structure. 
If you run it in a core other than XS1_G you need pull-up resistor for miso line (if in spi mode) or Cmd line and D0(=Dat port bit 3) line (if in 4bit bus mode)

Known Issues
============

* Initialization for the 4bit protocol not done at correct clock speed of 400KHz maximum.

Required Repositories
================

* xcommon git\@github.com:xcore/xcommon.git

Support
=======

Issues may be submitted via the Issues tab in this github repo. Response to any issues submitted are at the discretion of the maintainers of this component.
