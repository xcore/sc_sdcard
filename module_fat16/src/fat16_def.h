// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/*
 * @ModuleName FAT16_def
 * @Author Ali Dixon
 * @Date 07/06/2008
 * @Version 1.0
 * @Description: Server side functions for FAT16 file system
 *
*/

#ifndef __FAT16_DEF_H__
#define __FAT16_DEF_H__

#include <xs1.h>

typedef enum FAT16_CMD
{
  FAT16_CMD_error = 0,
  FAT16_CMD_initialise,
  FAT16_CMD_fopen,
  FAT16_CMD_fclose,
  FAT16_CMD_fread,
  FAT16_CMD_fwrite,
  FAT16_CMD_readdir,
  FAT16_CMD_opendir,
  FAT16_CMD_closedir,
  FAT16_CMD_rm,
  FAT16_CMD_finish

  // for testing only
  ,
  FAT16_CMD_ls

} FAT16_CMD_t;

// file pointer structure
typedef struct FP
{
  unsigned startAddr;
  unsigned currentClusterNum;
  unsigned currentSectorNum;
  unsigned currentBytePos;
  unsigned attributes;
  unsigned size;

  // dir info
  unsigned dirEntry_blockNum;
  unsigned dirEntry_entryAddr;
} FP_t;

#define DIR_NAME_SIZE 50

// directory entry
typedef struct DIR
{
  unsigned attributes;

  unsigned entryAddr;  // offset of entry in FAT
  unsigned entryNum;   // number of entry in FAT
  char name[DIR_NAME_SIZE];   // string
}DIR_t;

// Channel protocol definitions
#define CHAN_ACK 1

#endif // __FAT16_DEF_H__

