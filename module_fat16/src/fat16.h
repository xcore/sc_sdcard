// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/*
 * @ModuleName FAT16
 * @Author Ali Dixon
 * @Date 07/06/2008
 * @Version 1.0
 * @Description: FAT16 file system
 *
*/

#ifndef __FAT16_H__
#define __FAT16_H__

#include <xs1.h>
#include "fat16_def.h"
#include "sd_phy.h"

typedef enum {
  FAT16_SUCCESS=0,
  FAT16_FAIL,
  FAT16_INVALID_PARA
} FAT16_RTN_t;

extern unsigned dataStartSector;
extern unsigned sectorsPerCluster;
extern unsigned rootDirStartSector;
extern unsigned currentDirSectorAddr;

FAT16_RTN_t FAT_initialise(SDDataBlock_t dataBlock[], port p_sd_cmd, port p_sd_clk, port p_sd_dat);
FAT16_RTN_t FAT_readPartitionTable(SDDataBlock_t dataBlock[], port p_sd_cmd, port p_sd_clk, port p_sd_dat);
unsigned FAT_readFATPartition(SDDataBlock_t dataBlock[], port p_sd_cmd, port p_sd_clk, port p_sd_dat);
unsigned FAT_directoryList(SDDataBlock_t dataBlock[], DIR_t dir[], port p_sd_cmd, port p_sd_clk, port p_sd_dat);
unsigned FAT_find(SDDataBlock_t dataBlock[], FP_t fp[], char name[], port p_sd_cmd, port p_sd_clk, port p_sd_dat);
unsigned FAT_validateFileName(char filename[], char shortfilename[], char ext[]);

unsigned FAT_readDirTableEntry(SDDataBlock_t dataBlock[], char fileName[], DIR_t dir[], port p_sd_cmd, port p_sd_clk, port p_sd_dat);

unsigned FAT_getClusterAddress(unsigned clusterNum);
unsigned FAT_getNextCluster(SDDataBlock_t dataBlock[], unsigned clusterNum, port p_sd_cmd, port p_sd_clk, port p_sd_dat);
unsigned FAT_setNextCluster(SDDataBlock_t dataBlock[], unsigned clusterNum, unsigned nextClusterNum, port p_sd_cmd, port p_sd_clk, port p_sd_dat);
unsigned FAT_getFreeCluster(SDDataBlock_t dataBlock[], unsigned prevCluster, port p_sd_cmd, port p_sd_clk, port p_sd_dat);

FAT16_RTN_t FAT_fopen(SDDataBlock_t dataBlock[], FP_t fp[], char filename[], char mode, port p_sd_cmd, port p_sd_clk, port p_sd_dat);
FAT16_RTN_t FAT_fclose(SDDataBlock_t dataBlock[], FP_t fp[], port p_sd_cmd, port p_sd_clk, port p_sd_dat);
FAT16_RTN_t FAT_fdelete(SDDataBlock_t dataBlock[], FP_t fp[], char filename[], port p_sd_cmd, port p_sd_clk, port p_sd_dat);
unsigned FAT_fread(SDDataBlock_t dataBlock[], FP_t fp[], char buffer[], unsigned size, unsigned count, port p_sd_cmd, port p_sd_clk, port p_sd_dat);
unsigned FAT_fwrite(SDDataBlock_t dataBlock[], FP_t fp[], char buf[], unsigned size, unsigned count, port p_sd_cmd, port p_sd_clk, port p_sd_dat);

FAT16_RTN_t CheckFileNameRules(char filename[]);


#endif // __FAT16_H__

