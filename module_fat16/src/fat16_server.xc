// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/*
 * @ModuleName FAT16_server
 * @Author Ali Dixon
 * @Date 07/06/2008
 * @Version 1.0
 * @Description: Server side functions for SD_FAT16
 *
*/

#include <xs1.h>
#include "fat16_server.h"
#include "sd_link.h"
#include "sd_phy.h"
#include "fat16_def.h"
#include "fat16.h"


void FAT16_server(chanend client1, port p_sd_cmd, port p_sd_clk, port p_sd_dat, port p_sd_rsv)
{
  SDDataBlock_t dataBlock[1];
  FAT16_RTN_t returnCode;
  char buffer[500];

  FAT16_CMD_t cmd;
  unsigned argc;
  char tmp;
  unsigned i;
  unsigned j;
  char argv[5][20];
  FP_t fp[1];
  DIR_t dir[1];
  unsigned active = 1;

  //clear the dataBlock
  for(i=0;i<128;i++){
    dataBlock[0].data[i]=0;
  }

  while (active)
  {
    select
    {
      // receive rpc args
      case slave
      {
        client1 :> cmd;
        client1 :> argc;

        for (i=0; i<argc; i++)
        {
          j=0;
          do
          {
            client1 :> tmp;
            argv[i][j] = tmp;
            j++;
          }
          while (tmp != '\0');
        }
      }:

      {
        switch (cmd)
        {
          case FAT16_CMD_initialise:
          {
            if (SD_link_initialise(p_sd_cmd, p_sd_clk, p_sd_dat, p_sd_rsv) == FAT16_SUCCESS)
            {
              if (FAT_initialise(dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat) == FAT16_SUCCESS)
              {
                currentDirSectorAddr = rootDirStartSector;
                returnCode = FAT16_SUCCESS;
              }
              else
              {
                returnCode = FAT16_FAIL;
              }
            }
            else
            {
              returnCode = FAT16_FAIL;
            }

            master
            {
              client1 <: returnCode;
            }


            break;
          }
          case FAT16_CMD_fopen:
          {
            unsigned found;

            currentDirSectorAddr = rootDirStartSector;

            // read current dir sector
            SD_readSingleBlock(currentDirSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);
            found = FAT_fopen(dataBlock, fp, argv[0], argv[1][0], p_sd_cmd, p_sd_clk, p_sd_dat);


            // send back
            master
            {
              client1 <: found;
              client1 <: fp[0];
            }
            break;
          }
          case FAT16_CMD_fclose:
          {
            slave
            {
              client1 :> fp[0];
            }

            currentDirSectorAddr = rootDirStartSector;

            // read current dir sector
            SD_readSingleBlock(currentDirSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);
            FAT_fclose(dataBlock, fp, p_sd_cmd, p_sd_clk, p_sd_dat);

            master
            {
              client1 <: returnCode;
              client1 <: fp[0];
            }
            break;
          }
          case FAT16_CMD_fread:
          {
            unsigned size;
            unsigned count;
            char buf[15];
            unsigned numBytes;


            slave
            {
              client1 :> fp[0];
              client1 :> size;
              client1 :> count;
            }
            numBytes = FAT_fread(dataBlock, fp, buffer, size, count, p_sd_cmd, p_sd_clk, p_sd_dat);

            // send data
            master
            {
              client1 <: numBytes;
              if (numBytes > 0)
              {
                for (unsigned i=0; i<numBytes; i++)
                {
                  client1 <: (char)buffer[i];
                }
                client1 <: fp[0];
              }
            }

            break;
          }
          case FAT16_CMD_fwrite:
          {
            unsigned size;
            unsigned count;
            unsigned numBytesWritten = 0;
            // receive data
            slave
            {
              client1 :> fp[0];
              client1 :> size;
              client1 :> count;

              for (int i=0; i<count; i++)
              {
                client1 :> buffer[i];
              }
            }

            numBytesWritten = FAT_fwrite(dataBlock, fp, buffer, size, count, p_sd_cmd, p_sd_clk, p_sd_dat);

            // return args
            master
            {
              client1 <: numBytesWritten;
              client1 <: fp[0];
            }
            break;
          }
          case FAT16_CMD_readdir:
          {
            char fileName[255];

            slave
            {
              client1 :> dir[0];
            }


            // Read directory
            returnCode = FAT_readDirTableEntry(dataBlock, fileName, dir, p_sd_cmd, p_sd_clk, p_sd_dat);

            // return args
            master
            {
              client1 <: returnCode;
              client1 <: dir[0];
            }

            break;
          }
          case FAT16_CMD_opendir:
          {
            returnCode = FAT16_SUCCESS;

            slave
            {
              client1 :> dir[0];
            }

            dir[0].entryNum = 0xFFFFFFFF;
            dir[0].entryAddr = 0x0;
            currentDirSectorAddr = rootDirStartSector;
            // return args
            master
            {
              client1 <: returnCode;
              client1 <: dir[0];
            }
            break;
          }
          case FAT16_CMD_closedir:
          {
            returnCode = FAT16_SUCCESS;

            slave
            {
              client1 :> dir[0];
            }

            // return args
            master
            {
              client1 <: returnCode;
              client1 <: dir[0];
            }
            break;
          }
          case FAT16_CMD_ls:
          {
            currentDirSectorAddr = rootDirStartSector;
            returnCode = SD_readSingleBlock(currentDirSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);
            if (returnCode == FAT16_SUCCESS)
            {
              returnCode = FAT_directoryList(dataBlock, dir, p_sd_cmd, p_sd_clk, p_sd_dat);
            }

            // return args
            master
            {
              client1 <: returnCode;
            }

            break;
          }
          case FAT16_CMD_rm:
          {
            returnCode = FAT16_FAIL;

            currentDirSectorAddr = rootDirStartSector;

            // read current dir sector
            SD_readSingleBlock(currentDirSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);
            
            if (FAT_find(dataBlock, fp, argv[0], p_sd_cmd, p_sd_clk, p_sd_dat))
            {
              if (fp[0].attributes == 0x10)
              {
                // directory
                returnCode = FAT16_FAIL;
              }
              else
              {
                returnCode = FAT_fdelete(dataBlock, fp, argv[0], p_sd_cmd, p_sd_clk, p_sd_dat);
              }
            }
            else
            {
              returnCode = FAT16_FAIL;
            }

            // return args
            master
            {
              client1 <: returnCode;
            }


            break;
          }
          case FAT16_CMD_finish:
          {
            active = 0;


            // return args
            master
            {
              client1 <: returnCode;
            }
            break;
          }
        }
        break;
      }
    }
  }
}
