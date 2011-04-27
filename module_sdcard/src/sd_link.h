// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/*
 * SPI controller for SD
*/

#ifndef __SD_LINK_H__
#define __SD_LINK_H__


#include <xs1.h>
#include "sd_def.h"
#include "sd_phy.h"


SD_RTN_t SD_link_initialise( port p_sd_cmd, port p_sd_clk, port p_sd_dat, port p_sd_rsv);
void SD_getStatus();
SD_RTN_t SD_link_checkCardStatus(r1Response_t r, unsigned &currentState);
SD_RTN_t SD_readSingleBlock(unsigned blockNumber, SDDataBlock_t block[], port p_sd_cmd, port p_sd_clk, port p_sd_dat);
SD_RTN_t SD_writeSingleBlock(unsigned blockNumber, SDDataBlock_t block[], port p_sd_cmd, port p_sd_clk, port p_sd_dat);
void SD_link_check(port p_sd_cmd, port p_sd_clk, port p_sd_dat);
unsigned SD_blockCrc16(SDDataBlock_t dataBlock[]);

#endif // __SD_LINK_H__

