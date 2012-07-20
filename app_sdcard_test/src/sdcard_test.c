// Copyright (c) 2011, XMOS Ltd., All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/*
 ============================================================================
 Name        : sdcard_test
 Description : SD card host driver test
 ============================================================================
 */

#include <stdio.h> /* for the printf function */
#include "ff.h"    /* file system routines */
#include "timing.h"

FATFS Fatfs;            /* File system object */
FIL Fil;                /* File object */
BYTE Buff[512*40];      /* File read buffer (40 SD card blocks to let multiblock operations (if file not fragmented) */

void die(FRESULT rc ) /* Stop with dying message */
{
  printf("\nFailed with rc=%u.\n", rc);
  for(;;);
}

int main(void)
{
  FRESULT rc;                     /* Result code */
  DIR dir;                        /* Directory object */
  FILINFO fno;                    /* File information object */
  UINT bw, br, i;
  unsigned int T;

  for( i = 0; i < sizeof(Buff); i++) Buff[i] = i + i / 512; // fill the buffer with some data

  f_mount(0, &Fatfs);             /* Register volume work area (never fails) for SD host interface #0 */
  {
    FATFS *fs;
    DWORD fre_clust, fre_sect, tot_sect;

    /* Get volume information and free clusters of drive 0 */
    rc = f_getfree("0:", &fre_clust, &fs);
    if(rc) die(rc);

    /* Get total sectors and free sectors */
    tot_sect = (fs->n_fatent - 2) * fs->csize;
    fre_sect = fre_clust * fs->csize;

    /* Print free space in unit of KB (assuming 512 bytes/sector) */
    printf("%lu KB total drive space.\n"
           "%lu KB available.\n",
           fre_sect / 2, tot_sect / 2);
  }

  /****************************/

  printf("\nDeleting file Data.bin if existing...");
  rc = f_unlink ("Data.bin");    /* delete file if exist */
  if( FR_OK == rc) printf("deleted.\n");
  else printf("done.\n");

  /****************************/

  printf("\nCreating a new file Data.bin...");
  rc = f_open(&Fil, "Data.bin", FA_WRITE | FA_CREATE_ALWAYS);
  if(rc) die(rc);
  printf("done.\n");

  printf("\nWriting data to the file...");
  T = get_time();
  rc = f_write(&Fil, Buff, sizeof(Buff), &bw);
  T = get_time() - T;
  if(rc) die(rc);
  printf("%d bytes written. Write rate: %dKBytes/Sec\n", bw, (bw*100000)/T);

  printf("\nClosing the file...");
  rc = f_close(&Fil);
  if(rc) die(rc);
  printf("done.\n");

  /****************************/

  printf("\nOpening an existing file: Data.bin...");
  rc = f_open(&Fil, "Data.bin", FA_READ);
  if(rc) die(rc);
  printf("done.\n");

  printf("\nReading file content...");
  T = get_time();
  rc = f_read(&Fil, Buff, sizeof(Buff), &br);
  T = get_time() - T;
  if(rc) die(rc);
  printf("%d bytes read. Read rate: %dKBytes/Sec\n", br, (br*100000)/T);

  printf("\nClosing the file...");
  rc = f_close(&Fil);
  if(rc) die(rc);
  printf("done.\n");

  /****************************/

  printf("\nOpen root directory.\n");
  rc = f_opendir(&dir, "");
  if(rc) die(rc);

  printf("\nDirectory listing...\n");
  for(;;)
  {
    rc = f_readdir(&dir, &fno);    /* Read a directory item */
    if(rc || !fno.fname[0]) break; /* Error or end of dir */
    if(fno.fattrib & AM_DIR)
      printf("   <dir>  %s\n", fno.fname);
    else
    {
      printf("%8d  %s\n", fno.fsize, fno.fname);
    }
  }
  if(rc) die(rc);

  /****************************/

  printf("\nTest completed.\n");
  return 0;
}
