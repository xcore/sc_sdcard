// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/*
 * @ModuleName FAT16_client
 * @Author Ali Dixon
 * @Date 07/06/2008
 * @Version 1.0
 * @Description: Channel interface to FAT16 file system
 *
*/

#ifndef __FAT16_CLIENT_H__
#define __FAT16_CLIENT_H__

#include <xs1.h>
#include "fat16.h"

FAT16_RTN_t FAT16_Clnt_initialise(chanend server);
FAT16_RTN_t FAT16_Clnt_finish(chanend server);

FAT16_RTN_t FAT16_Clnt_fopen(chanend server, FP_t fp[], char filename[], char mode);
FAT16_RTN_t FAT16_Clnt_fclose(chanend server, FP_t fp[]);
unsigned FAT16_Clnt_fread(chanend server, FP_t fp[], char buffer[], unsigned size, unsigned count);
unsigned FAT16_Clnt_fwrite(chanend server, FP_t fp[], char buffer[], unsigned size, unsigned count);
FAT16_RTN_t FAT16_Clnt_rm(chanend server, FP_t fp[], char filename[]);
unsigned FAT16_Clnt_readdir(chanend server, DIR_t dir[]);
FAT16_RTN_t FAT16_Clnt_opendir(chanend server, char name[], DIR_t dir[]);
FAT16_RTN_t FAT16_Clnt_closedir(chanend server, DIR_t dir[]);
FAT16_RTN_t FAT16_Clnt_rm(chanend server, FP_t fp[], char filename[]);

// Unsupported functions - to be removed
FAT16_RTN_t FAT16_Clnt_ls(chanend server);

#endif // __FAT16_CLIENT_H__

