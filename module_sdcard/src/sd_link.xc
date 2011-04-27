// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/*
 * @ModuleName SD_link
 * @Author Ali Dixon
 * @Date 07/06/2008
 * @Version 1.0
 * @Description: Provide functions for reading/writing to SD card
 *
*/

#include <xs1.h>
#include <xclib.h>
#include "sd_link.h"
#include "sd_phy.h"

unsigned cardRelAddr;


// Wake up the card
SD_RTN_t SD_link_initialise(port p_sd_cmd, port p_sd_clk, port p_sd_dat, port p_sd_rsv)
{
  unsigned initialising;
  unsigned word;
  unsigned i;
  SD_RTN_t returnCode = SD_SUCCESS;
  unsigned currentState;

  r1Response_t r1Response[1];
  r2Response_t r2Response[1];
  r3Response_t r3Response[1];

  cardRelAddr = 0xFF << 16;

  SD_phy_initialise(p_sd_cmd, p_sd_clk, p_sd_dat, p_sd_rsv);

  // Put card into idle state // CMD0
  SD_phy_sendCommand(GO_IDLE_STATE, 0, p_sd_cmd, p_sd_clk);
  word = SD_phy_receiveCommandBits(32, p_sd_cmd, p_sd_clk);

  SD_phy_sendCommand(SEND_IF_COND, 0x1AA, p_sd_cmd, p_sd_clk);  // voltage 1, check pattern AA
  SD_phy_getR1Response(r1Response, p_sd_cmd, p_sd_clk);         // r7 response

  initialising = 1;
  i = 0;
  while (initialising)
  {

    r1Response[0].data = 0xABABABAB;
    r3Response[0].data = 0xABABABAB;

    SD_phy_sendCommand(APP_CMD, 0, p_sd_cmd, p_sd_clk);
    SD_phy_getR1Response(r1Response, p_sd_cmd, p_sd_clk);
    SD_link_checkCardStatus(r1Response[0], currentState);

    SD_phy_sendCommand(SD_SEND_OP_COND, 0x00FF8000, p_sd_cmd, p_sd_clk);
    SD_phy_getR3Response(r3Response, p_sd_cmd, p_sd_clk);

    if (r3Response[0].data == 0x80FF8000)
    {
      initialising = 0;
    }

    i++;

    if (i > 500)
    {
      returnCode = SD_FAIL;
      break;
    }
  }

  if (returnCode == SD_SUCCESS)
  {
    // request CID
    SD_phy_sendCommand(ALL_SEND_CID, 0, p_sd_cmd, p_sd_clk);
    SD_phy_getR2Response(r2Response, p_sd_cmd, p_sd_clk);

    // Assign relative address
    SD_phy_sendCommand(SET_RELATIVE_ADDR, cardRelAddr, p_sd_cmd, p_sd_clk);
    SD_phy_getR1Response(r1Response, p_sd_cmd, p_sd_clk);
    returnCode = SD_link_checkCardStatus(r1Response[0], currentState);

    // r6 response. extract new rel addr
    cardRelAddr = r1Response[0].data >> 16;
    cardRelAddr = cardRelAddr << 16;

    // Select card
    SD_phy_sendCommand(SELECT_DESELECT_CARD, cardRelAddr, p_sd_cmd, p_sd_clk);
    SD_phy_getR1Response(r1Response, p_sd_cmd, p_sd_clk);
    returnCode = SD_link_checkCardStatus(r1Response[0], currentState);

    if ((returnCode != SD_SUCCESS) || (currentState != SD_CARD_STATE_stby))
    {
    }

    if (returnCode == SD_SUCCESS)
    {
      // Set block size
      SD_phy_sendCommand(SET_BLOCKLEN, BLOCK_SIZE, p_sd_cmd, p_sd_clk);
      SD_phy_getR1Response(r1Response, p_sd_cmd, p_sd_clk);
      returnCode = SD_link_checkCardStatus(r1Response[0], currentState);

      if ((returnCode != SD_SUCCESS) || (currentState != SD_CARD_STATE_tran))
      {
      }
    }
  }

  SD_phy_setHighSpeed();

  return returnCode;
}


// check the card status register
// format:
//     Bits:
//     [31]                    Out of range
//     [30]                    Address error
//     [29]                    Block_len_error
//     [28]                    Erase seq error
//     [27]                    Erase param
//     [26]                    Wp violation
//     [25]                    Not used
//     [24]                    Not used
//     [23]                    Com crc error
//     [22]                    Illegal command
//     [21]                    Not used
//     [20]                    Not used
//     [19]                    Error
//     [18]                    Not used
//     [17]                    Not used          !
//     [16]                    CID/CSD overwrite !
//     [15]                    Wp erase skip
//     [14]                    Card ecc disabled
//     [13]                    Erase reset
//     [12:9]                  Current state
//     [8]                     Ready for data
//     [7:6]                   Reserved
//     [4:0]                   Reserved
//
SD_RTN_t SD_link_checkCardStatus(r1Response_t r, unsigned &currentState)
{
  SD_RTN_t returnCode = SD_SUCCESS;

  currentState = (r.data >> 9) & 0xF;

  if ((r.data >> 19) & 0x1)
  {
    returnCode = SD_FAIL;
  }
  
  if ((r.data >> 22) & 0x1)
  {
    returnCode = SD_FAIL;
  }
  
  if ((r.data >> 23) & 0x1)
  {
    returnCode = SD_FAIL;
  }
  
  if ((r.data >> 28) & 0x1)
  {
    returnCode = SD_FAIL;
  }

  if ((r.data >> 29) & 0x1)
  {
    returnCode = SD_FAIL;
  }
  
  if ((r.data >> 30) & 0x1)
  {
    returnCode = SD_FAIL;
  }
  
  if ((r.data >> 31) & 0x1)
  {
    returnCode = SD_FAIL;
  }

  return returnCode;
}


// Read a block from memory, saving it into
// the SDDataBlock_t structure
// Also receives the command response to ensure its valid
SD_RTN_t SD_readSingleBlock(unsigned blockNumber, SDDataBlock_t block[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  //timer t;
  //unsigned time;
  unsigned blockAddress;
  unsigned result;
  unsigned blockResult;

  r1Response_t r1Response[1];
  SD_RTN_t returnCode;
  unsigned i=0;

  // Calculate block address
  blockAddress = blockNumber * BLOCK_SIZE;
  returnCode = SD_FAIL;
  while (i<100)
  {
    i++;

    SD_phy_receiveCommandBits(32, p_sd_cmd, p_sd_clk);

    // send CMD17 with the specified address.
    SD_phy_sendCommand(READ_SINGLE_BLOCK, blockAddress, p_sd_cmd, p_sd_clk);

    r1Response[0].data = 0;

    blockResult = SD_phy_receiveDataBlockWithR1Response(block, r1Response, p_sd_cmd, p_sd_clk, p_sd_dat);

    if (blockResult == 0)
    {
      result = SD_blockCrc16(block);
      if (block[0].crc == result)
      {
        returnCode = SD_SUCCESS;
        break;
      }
    }
  }

  return blockResult;
}


// Write a block from memory
// Also receives the command response to ensure its valid
SD_RTN_t SD_writeSingleBlock(unsigned blockNumber, SDDataBlock_t block[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned i;
  unsigned word;
  unsigned blockAddress;
  unsigned crc;
  unsigned result;
  r1Response_t r1Response[1];

  // crc the block
  crc = SD_blockCrc16(block);
  block[0].crc = crc;

  // Calculate block address
  blockAddress = blockNumber * BLOCK_SIZE;

  block[0].crc = SD_blockCrc16(block);

  // send CMD24 with the specified address.
  SD_phy_sendCommand(WRITE_SINGLE_BLOCK, blockAddress, p_sd_cmd, p_sd_clk);

  // receive response
  SD_phy_getR1Response(r1Response, p_sd_cmd, p_sd_clk);

  // Keep DAT high before sending data
  SD_phy_sendDataBits(5, 0xF0000000, p_sd_clk, p_sd_dat);

  // send data
  for (i=0; i<BLOCK_SIZE>>2; i++)
  {
    SD_phy_sendDataBits(32, block[0].data[i], p_sd_clk, p_sd_dat);
  }

  // send crc
  SD_phy_sendDataBits(16, block[0].crc << 16, p_sd_clk, p_sd_dat);

  // send End bit
  SD_phy_sendDataBits(1, 0xF0000000, p_sd_clk, p_sd_dat);

  // receive CRC status
  SD_phy_receiveStartDataBits(p_sd_clk, p_sd_dat);
  word = SD_phy_receiveDataBits(4, p_sd_clk, p_sd_dat);

  if (word == 0x5) // 0101 binary which is CRC pass
  {
    // CRC Pass;
    result = 1;
  }
  else
  {
    // CRC Fail.
    result = 0;
  }

  // wait for programming to complete
  word = 0;
  while (word == 0)
    word = SD_phy_receiveDataBits(8, p_sd_clk, p_sd_dat);


  return SD_SUCCESS;
}


// CRC the data block
unsigned SD_blockCrc16(SDDataBlock_t dataBlock[])
{
  unsigned i;
  unsigned crc;
  unsigned data;
  unsigned poly;
  unsigned poly_rev;
  unsigned tmp;

  poly = 0x1021<<16;
  poly_rev = bitrev(poly);
  crc = 0;

  // loop through each 32 bits
  for (i=0; i<BLOCK_SIZE>>2; i++)
  {
    data = dataBlock[0].data[i];

    tmp = bitrev(data);
    crc32(crc, tmp, poly_rev);
  }

  // augmentation
  crc32(crc, 0x0, poly_rev);
  crc = bitrev(crc);
  crc = crc >> 16;

  return crc;
}
