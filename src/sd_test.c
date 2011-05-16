// Copyright (c) 2011, XMOS Ltd., All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

// Originally taken from FatFs - FAT file system module  R0.08b (C)ChaN, 2011
// Copyright (C) 2011, ChaN, all right reserved.

// FatFs sample project for generic microcontrollers (C)ChaN, 2010

#include <stdio.h>
#include "ff.h"

/* Stop with dying message */
/* FatFs return value */
void die ( FRESULT rc )
{
	printf("Failed with rc=%u.\n", rc);
	for (;;) ;
}

// Test Program
void test (void)
{
	FRESULT rc;				/* Result code */
	FATFS fatfs;			/* File system object */
	FIL fil;				/* File object */
	DIR dir;				/* Directory object */
	FILINFO fno;			/* File information object */
	UINT bw, br, i;
	BYTE buff[128];

	f_mount(0, &fatfs);		/* Register volume work area (never fails) */

	printf("\nCreate a new file (hello.txt).\n");
	rc = f_open(&fil, "HELLO.TXT", FA_WRITE | FA_CREATE_ALWAYS);
	if (rc) die(rc);

	printf("\nOpen a test file (message.txt).\n");
	rc = f_open(&fil, "MESSAGE.TXT", FA_READ);
	if (rc) die(rc);

	printf("\nType the file content.\n");
	for (;;) {
		rc = f_read(&fil, buff, sizeof(buff), &br);	/* Read a chunk of file */
		if (rc || !br) break;			/* Error or end of file */
		for (i = 0; i < br; i++)		/* Type the data */
			putchar(buff[i]);
	}
	if (rc) die(rc);

	printf("\nClose the file.\n");
	rc = f_close(&fil);
	if (rc) die(rc);

	printf("\nCreate a new file (hello.txt).\n");
	rc = f_open(&fil, "HELLO.TXT", FA_WRITE | FA_CREATE_ALWAYS);
	if (rc) die(rc);

	printf("\nWrite a text data. (Hello world!)\n");
	rc = f_write(&fil, "Hello world!\r\n", 14, &bw);
	if (rc) die(rc);
	printf("%u bytes written.\n", bw);

	printf("\nClose the file.\n");
	rc = f_close(&fil);
	if (rc) die(rc);

	printf("\nOpen root directory.\n");
	rc = f_opendir(&dir, "");
	if (rc) die(rc);

	printf("\nDirectory listing...\n");
	for (;;) {
		rc = f_readdir(&dir, &fno);		/* Read a directory item */
		if (rc || !fno.fname[0]) break;	/* Error or end of dir */
		if (fno.fattrib & AM_DIR)
			printf("   <dir>  %s\n", fno.fname);
		else
			printf("%8lu  %s\n", fno.fsize, fno.fname);
	}
	if (rc) die(rc);

	printf("\nTest completed.\n");
	for (;;) ;
}


// User Provided Timer Function for FatFs module
DWORD get_fattime (void)
{
	return	  ((DWORD)(2010 - 1980) << 25)	/* Fixed to Jan. 1, 2010 */
			| ((DWORD)1 << 21)
			| ((DWORD)1 << 16)
			| ((DWORD)0 << 11)
			| ((DWORD)0 << 5)
			| ((DWORD)0 >> 1);
}
