// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/*
 * @ModuleName FAT16_server
 * @Author Ali Dixon
 * @Date 07/06/2008
 * @Version 1.0
 * @Description: Server side functions for FAT16 file system
 *
*/

#ifndef __FAT16_SERVER_H__
#define __FAT16_SERVER_H__

#include <xs1.h>
#include "fat16.h"

void FAT16_server(chanend client1, port p_sd_cmd, port p_sd_clk, port p_sd_dat, port p_sd_rsv);

#endif // __FAT16_SERVER_H__

