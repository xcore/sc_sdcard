SD Card Libary
..............

:Stable release: unreleased

:Status:  alpha

:Maintainer:  interactive_matter

:Description:  SD card driver library


Key Features
============

* **Please note: FAT with long file names may be covered by various patents (in particular those held by Microsoft). Use of this code may require licensing from the patent holders**
* Port of FatFS - FAT file system module R0.08b (C)ChaN, 2011 (http://elm-chan.org/fsw/ff/00index_e.html).

To Do
=====

* Tidy up code to use the module system.
* Improve the interface code to use clock blocks and buffered ports, so that once initialised at 400kHz, it switches to 25 or 50MHz.

Firmware Overview
=================

<One or more paragraphs detailing the functionality of modules and apps in this repo>

Known Issues
============

* Currently quite slow as uses 400kHz bit banged interface.

Required Repositories
================

* <list of repos, likely to include xcommon if it uses the build system>
* xcommon git\@github.com:xcore/xcommon.git

Support
=======

<Description of support model>
