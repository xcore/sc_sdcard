# Copyright (c) 2011, XMOS Ltd., All rights reserved
# This software is freely distributable under a derivative of the
# University of Illinois/NCSA Open Source License posted in
# LICENSE.txt and at <http://github.xcore.com/>

SOURCE = src/ff.c src/main.xc src/mmcbb.c src/sd_io.xc src/sd_test.c  
FLAGS = -Wall -g -O2 -I. -Isrc/. -DTRIGGER_LOGIC -report -target=XK-1

ifeq "$(OS)" "Windows_NT"
DELETE = del
else
DELETE = rm -f
endif

bin\sd.xe: ${SOURCE}
	xcc ${FLAGS} ${SOURCE} -o bin\sd.xe

clean:
	$(DELETE) bin\*.xe
