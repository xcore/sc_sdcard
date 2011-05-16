// Copyright (c) 2011, XMOS Ltd., All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

#ifndef _SD_IO_H_
#define _SD_IO_H_

	// Functions to communicate with the SD card using bytes
	void byte_out ( unsigned char c );
	unsigned char byte_in ( void );

	// Functions for bit-banging the ports
	void cs_h ( void );
	void cs_l ( void );

	void ck_h ( void );
	void ck_l ( void );

	void mosi_h ( void );
	void mosi_l ( void );

	void init_port( void );

	void dly_us ( unsigned int n );


#endif // _SD_IO_H_