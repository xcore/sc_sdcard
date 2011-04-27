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

#include <xs1.h>
#include <safestring.h>
#include "fat16.h"
#include "sd_link.h"
#include "sd_phy.h"

// Globals
unsigned dataStartSector;
unsigned sectorsPerCluster;
unsigned rootDirStartSector;
unsigned currentDirSectorAddr;
unsigned FATstartSector;
unsigned partition_firstSectorBlockAddr;
unsigned currentDirSectorNum;


// Initialise the file system
FAT16_RTN_t FAT_initialise(SDDataBlock_t dataBlock[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  FAT16_RTN_t returnCode;

  returnCode = FAT_readPartitionTable(dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

  if (returnCode == FAT16_SUCCESS)
  {
    FAT_readFATPartition(dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);
    currentDirSectorAddr = rootDirStartSector;
  }

  return returnCode;
}


// Open then the 16-bit FAT table & find the next cluster in the file/dir after
// the given cluster.
// If thisthe last cluster in the chain, return -1.
//
// Return the cluster ID of the next cluster after the given cluster in the chain.
unsigned FAT_getNextCluster(SDDataBlock_t dataBlock[], unsigned clusterNum, port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned nextCluster;
  unsigned wordAddr;
  unsigned FATblockNumber;

  // goto the entry for the current cluster & return its entry
  wordAddr = (clusterNum >> 1);

  // determine which block of the FAT the cluster is in.
  FATblockNumber = (wordAddr>>7);  // 8 - 512 byte block

  //get offset into this block
  wordAddr = (wordAddr & 0x7F);

  FATblockNumber = FATblockNumber + FATstartSector;

  // Read File Access Table (FAT)
  SD_readSingleBlock(FATblockNumber, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

  if ((clusterNum & 0x1) == 1)
  {
    nextCluster = ((dataBlock[0].data[wordAddr] & 0xFF) << 8) | ((dataBlock[0].data[wordAddr] >> 8) & 0xFF);
  }
  else
  {
    nextCluster = ((dataBlock[0].data[wordAddr] >> 8) & (0xFF << 8)) | ((dataBlock[0].data[wordAddr] >> 24) & 0xFF);
  }

  switch (nextCluster)
  {
    case 0x000:
    {
      break;
    }
    case 0x0001:
    {
      break;
    }
    case 0xFFF7:
    {
      break;
    }
    case 0xFFFF:
    {
      break;
    }
  }

  return nextCluster;
}


// Open then the 16-bit FAT table & find the given cluster in the file. Set its
// entry to point to the given next cluster.
unsigned FAT_setNextCluster(SDDataBlock_t dataBlock[], unsigned clusterNum, unsigned nextClusterNum, port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned oldNextCluster;
  unsigned wordAddr;
  unsigned FATblockNumber;

  // goto the entry for the current cluster & return its entry
  wordAddr = (clusterNum >> 1);

  // determine which block of the FAT the cluster is in.
  FATblockNumber = (wordAddr>>7);  // 8 - 512 byte block

  //get offset into this block
  wordAddr = (wordAddr & 0x7F);

  FATblockNumber = FATblockNumber + FATstartSector;

  // Read File Access Table (FAT)
  SD_readSingleBlock(FATblockNumber, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

  if ((clusterNum & 0x1) == 1)
  {
    oldNextCluster = ((dataBlock[0].data[wordAddr] & 0xFF) << 8) | ((dataBlock[0].data[wordAddr] >> 8) & 0xFF);

    // set the next cluster
    dataBlock[0].data[wordAddr] = (dataBlock[0].data[wordAddr] & ((unsigned)0xFFFF<<16)) | (((nextClusterNum & 0xFF) << 8) | (((nextClusterNum>>8) & 0xFF)));
  }
  else
  {
    oldNextCluster = ((dataBlock[0].data[wordAddr] >> 8) & (0xFF << 8)) | ((dataBlock[0].data[wordAddr] >> 24) & 0xFF);

    // set the next cluster
    dataBlock[0].data[wordAddr] = (dataBlock[0].data[wordAddr] & 0xFFFF) | (((nextClusterNum & 0xFF) << 24 )) | ((nextClusterNum & (unsigned)0xFF00) << 8);
  }

  SD_writeSingleBlock(FATblockNumber, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

  return 0;
}


// Open then the FAT table & find the next free cluster. This involves reading multiple blocks.
// Set the entry for the given previous cluster to the new cluster
// (to mark the next cluster for the given previous cluster)
// If no previous cluster, pass cluster intue 0
//
// Set the entry for the new cluster to 0xFFFF (mark it as the last cluster
// in the chain).
//
// Return the cluster ID of the next free cluster
unsigned FAT_getFreeCluster(SDDataBlock_t dataBlock[], unsigned prevCluster, port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned newCluster;
  unsigned halfWordPointer;
  unsigned nextCluster;
  unsigned currentFATblock;

  // find the first free cluster. May look at multiple blocks. Entry = 0xFFFF
  currentFATblock = FATstartSector;
  nextCluster = 1;

  halfWordPointer = 2 << 1;  // cant use the first 2 clusters
  while (nextCluster != 0x0)
  {
    SD_readSingleBlock(currentFATblock, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

    // find first free cluster.
    while ((nextCluster != 0x0) && ((halfWordPointer>>1) < (BLOCK_SIZE<<2)))
    {
      // entry either first or second 2 bytes
      if (halfWordPointer & 0x1)
      {
        nextCluster = ((dataBlock[0].data[(halfWordPointer>>1)] >> 8) & 0xFF) | ((dataBlock[0].data[(halfWordPointer>>1)] & 0xFF) << 8);
      }
      else
      {
        nextCluster = ((dataBlock[0].data[(halfWordPointer>>1)] >> 24) & 0xFF) | (((dataBlock[0].data[(halfWordPointer>>1)]>>16) & 0xFF)  << 8);
      }

      if (nextCluster == 0x0)
      {
        newCluster = halfWordPointer;
      }

      halfWordPointer += 1;
    }

    // use next block of FAT
    halfWordPointer = 0;
    currentFATblock += 1;
  }

  currentFATblock -= 1;

  // set its entry to 0xFFFF.
  if (newCluster & 0x1)
  {
    dataBlock[0].data[newCluster>>1] = (dataBlock[0].data[newCluster>>1] | 0xFFFF);
  }
  else
  {
    dataBlock[0].data[newCluster>>1] = (dataBlock[0].data[newCluster>>1] | ((unsigned) 0xFFFF<<16));
  }

  SD_writeSingleBlock(currentFATblock, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

  return newCluster;
}


// Calculate the address of the first sector of the given cluster number.
// Cluster address is calculated as start of data sector + sectorsPerCluster * (clusterNum-2)
// NB: clusterNum starts from 2.
unsigned FAT_getClusterAddress(unsigned clusterNum)
{
  unsigned clusterAddr;

  // return the rootDir if clusterNum is 0, otherwise calculate the address
  if (clusterNum == 0)
  {
    clusterAddr = rootDirStartSector;
  }
  else
  {
    clusterAddr = dataStartSector + (sectorsPerCluster*(clusterNum-2));
  }

  return clusterAddr;
}


// Find the directory/file with the given name.
// Currently searches only the short names, all of
// which appear to be padded with spaces and are 8 chars
// long. Therfore all search names are padded with spaces if
// they are not already 8 chars long.
//
// name is a packed string of length 8 to match FAT short filename
//
// The directory sector must be in dataBlock
// Return the word offset into the dataBlock for the dir entry
unsigned FAT_find(SDDataBlock_t dataBlock[], FP_t fp[], char name[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned found;

  char fileName[255];
  DIR_t dir[1];

  found = 0;
  dir[0].entryNum = 0xFFFFFFFF;
  dir[0].entryAddr = 0;

  // Read directories
  while (FAT_readDirTableEntry(dataBlock, fileName, dir, p_sd_cmd, p_sd_clk, p_sd_dat))
  {
    if (safestrcmp(name, fileName) == 0)
    {
      found = 1;

      fp[0].currentClusterNum = ((dataBlock[0].data[dir[0].entryAddr+6] & 0xFF) << 8) | ((dataBlock[0].data[dir[0].entryAddr+6] >> 8) & 0xFF);
      fp[0].startAddr = FAT_getClusterAddress(fp[0].currentClusterNum);
      fp[0].attributes = dataBlock[0].data[dir[0].entryAddr+2] & 0xFF;;
      fp[0].size = (((dataBlock[0].data[dir[0].entryAddr+7]>>24) & 0xFF)) | (((dataBlock[0].data[dir[0].entryAddr+7]>>16) & 0xFF) << 8)|
                   (((dataBlock[0].data[dir[0].entryAddr+7]>>8)  & 0xFF) << 16)| (((dataBlock[0].data[dir[0].entryAddr+7]   )  & 0xFF) << 24);
      fp[0].dirEntry_entryAddr = dir[0].entryAddr;
      fp[0].dirEntry_blockNum  = currentDirSectorAddr;


      break;
    }
  }

  if (found)
  {
    if (fp[0].currentClusterNum == 0)
    {
      // ClusterNum==0. defaults to root
      fp[0].currentClusterNum = rootDirStartSector;
    }
  }

  return found;
}


// List the current directory - dir sector is in dataBlock
// Each entry32 bytes, holding the name, attribute, size,
// date, time & initial cluster number for the file or directory.
//
// Normal Entry format:
//
//     Byte Pos    Length (bytes)  Description
//     0x00        8               Name
//
//     0x08        3               Blank-padded extension
//     0x0B        1               Attributes: 5 bit-mapped field. intue 0x0F
//                                             indicates an LFN entry
//                                 00001 : Read-Only
//                                 00010 : System
//                                 00100 : Hidden
//                                 01000 : Volume
//                                 10000 : Directory

//     0x0C        1               Reserved

//     0x0D        1               10-ms unit’s "Create Time" refinement (added with VFAT).
//     0x0E        2               Creation time (added with VFAT).
//     0x00        2               Creation date (added with VFAT).
//     0x12        2               Access date (added with VFAT).
//     0x14        2               High 16-bits of Cluster // (added with & used for FAT32).
//     0x16        2               Update time (set on creation as well)
//     0x18        2               Update date (set on creation as well)
//                                     Year: 1980 + [15:9]
//                                     Month: [8:5]
//                                     Day:   [4:0]
//     0x1A        2               16-bit Cluster - sector num of the beginning of the file, or
//                                                 for a directory, the subdirectory table.
//                                         The '.' entry points to the directoy itself
//                                         The '..' entry points to the parent directoy. 0 if root.
//     0x1C        4               File size in bytes (always zero for directories).
//
// Long FileName (LFN) entry format:
//
//     Byte Pos    Length (bytes)  Description
//     0x00        1               LFN Record Sequence Number
//                                     Bits 5:0 hold a 6-bit LFN sequence number (1..63).
//                                     This limits the number of LFN entries per long name to 63 entries or
//                                     63 * 13 = 819 characters per name.
//                                     Bit 6set for the last LFN record in the sequence.
//                                     Bit 7set if the LFN recordan erased long name entry
//                                     or maybe if itpart of an erased long name?
//
//     0x01        2               Unicode character 1 - each unicode char2 bytes
//     0x03        2               Unicode character 2
//     0x05        2               Unicode character 3
//     0x07        2               Unicode character 4
//     0x09        2               Unicode character 5
//     0x0B        1               Attribute - 0x0F to indicate LFN entry
//     0x0C        1               Type (reserved; always 0)
//     0x0D        1               Checksum
//     0x0E        2               Unicode character 6
//     0xF0        2               Unicode character 7
//     0xF2        2               Unicode character 8
//     0xF4        2               Unicode character 9
//     0xF6        2               Unicode character 10
//     0xF8        2               Unicode character 11
//     0xFA        2               Cluster (unused; always 0)
//     0xFC        2               Unicode character 12
//     0xFE        2               Unicode character 13
//
// For long filenames, entries are in reverse order - ie. end of string namefirst.
// The following entries are then the rest of the long filename.
// The end of the long filenamemarked by a short entry.
unsigned FAT_directoryList(SDDataBlock_t dataBlock[], DIR_t dir[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  char fileName[255];

  // Read directories
  while (FAT_readDirTableEntry(dataBlock, fileName, dir, p_sd_cmd, p_sd_clk, p_sd_dat))
  {
  }

  return 0;
}


// Read an item in the dir table - this may be multiple entries
// Modify entryAddress to point to this entry, and filename in fileName[]
unsigned FAT_readDirTableEntry(SDDataBlock_t dataBlock[], char fileName[], DIR_t dir[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  int i;
  int j;
  unsigned attributes;
  char tmp[10];
  char ext[5];
  unsigned clusterNum;
  unsigned fileSize;
  unsigned dirNameBuffPointer = 0;
  unsigned readNextEntry = 1;
  unsigned moreEntries = 1;

  currentDirSectorNum = 0;

  // if just opened the dir, read the current directory sector
  if (dir[0].entryNum == 0xFFFFFFFF)
  {
      SD_readSingleBlock(currentDirSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);
  }

  while (readNextEntry)
  {
    // check current entry
    if (dir[0].entryAddr >= 120)
    {
      // need the next block, possibly next cluster
      currentDirSectorAddr++;
      currentDirSectorNum++;

      // detect if passed this cluster
      if (currentDirSectorNum >= sectorsPerCluster)
      {
      }

      SD_readSingleBlock(currentDirSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

      dir[0].entryAddr = 0;
      readNextEntry = 1;
      moreEntries = 1;
    }
    else
    {
      // increment entryAddr if this isn't the first time we've called this func.
      if (dir[0].entryNum == 0xFFFFFFFF)
      {
        dir[0].entryNum = 0;
      }
      else
      {
        dir[0].entryAddr += 8;
      }

      if ((dataBlock[0].data[dir[0].entryAddr]>>24) != 0)
      {
        moreEntries = 1;
      }
      else
      {
        // No more entries
        readNextEntry = 0;
        moreEntries = 0;
      }
    }

    if (moreEntries)
    {
      if ((dataBlock[0].data[dir[0].entryAddr]>>24) != 0)   // DOS file name. Marks if entry is used.
      {
        attributes = dataBlock[0].data[dir[0].entryAddr+2] & 0xFF;

        // Long File Name entry
        if (attributes == 0xF)
        {
          if ((dataBlock[0].data[dir[0].entryAddr]>>24) == 0xE5)  // 0xE5 means dir has been deleted
          {
            readNextEntry = 1;
            dirNameBuffPointer = 0;
          }
        }

        // Normal (short) entry
        else if ((attributes == 0x01) || (attributes == 0x02) || (attributes == 0x04) || (attributes == 0x08) || (attributes == 0x10) || (attributes == 0x20) || (attributes == 0x40))
        {
          readNextEntry = 0;

          if ((dataBlock[0].data[dir[0].entryAddr]>>24) == 0xE5)  // 0xE5 means dir has been deleted
          {
            readNextEntry = 1;
          }
          else
          {

            tmp[0] = (dataBlock[0].data[dir[0].entryAddr]>>24) & 0xFF;
            tmp[1] = (dataBlock[0].data[dir[0].entryAddr]>>16) & 0xFF;
            tmp[2] = (dataBlock[0].data[dir[0].entryAddr]>>8)  & 0xFF;
            tmp[3] = (dataBlock[0].data[dir[0].entryAddr])     & 0xFF;
            tmp[4] = (dataBlock[0].data[dir[0].entryAddr+1]>>24) & 0xFF;
            tmp[5] = (dataBlock[0].data[dir[0].entryAddr+1]>>16) & 0xFF;
            tmp[6] = (dataBlock[0].data[dir[0].entryAddr+1]>>8)  & 0xFF;
            tmp[7] = (dataBlock[0].data[dir[0].entryAddr+1])     & 0xFF;
            tmp[8] =  '\0';

            ext[0] = (dataBlock[0].data[dir[0].entryAddr+2]>>24);
            ext[1] = (dataBlock[0].data[dir[0].entryAddr+2]>>16);
            ext[2] = (dataBlock[0].data[dir[0].entryAddr+2]>>8);
            ext[3] =  '\0';

              // SFN
              // copy short filename into long
              // work from end removing spaces
              for (i=7; i>=0; i--)
              {
                if (tmp[i] == ' ')
                  tmp[i] = 0;
              }

              // copy
              for (i=0; i<8; i++)
              {
                fileName[i] = tmp[i];
                if (tmp[i] == 0x0)
                  break;
              }

              fileName[i] = '.';
              i++;
              // append extension
              for (j=0; j<4; j++)
              {
                if (ext[j] == ' ')
                {
                  break;
                }
                fileName[i] = ext[j];
                i++;
              }

              fileName[i] = '\0';


            dir[0].entryNum++;

            clusterNum = ((dataBlock[0].data[dir[0].entryAddr+6] & 0xFF) << 8) | ((dataBlock[0].data[dir[0].entryAddr+6] >> 8) & 0xFF);
            fileSize = (((dataBlock[0].data[dir[0].entryAddr+7]>>24) & 0xFF)) | (((dataBlock[0].data[dir[0].entryAddr+7]>>16) & 0xFF) << 8)|
                       (((dataBlock[0].data[dir[0].entryAddr+7]>>8)  & 0xFF) << 16)| (((dataBlock[0].data[dir[0].entryAddr+7]   )  & 0xFF) << 24);

            safestrcpy(dir[0].name, fileName);
            dir[0].attributes = attributes;
          }
        }
      }
    }

  }

  return moreEntries;
}


// Read the FAT partition table
FAT16_RTN_t FAT_readPartitionTable(SDDataBlock_t dataBlock[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
    unsigned word;
    unsigned fileSystem;
    unsigned partition_numSectors = 0;
    unsigned partition_firstPartitionSector = 0;
    unsigned partition_lastPartitionSector = 0;

    FAT16_RTN_t returnCode = FAT16_SUCCESS;

    // Read the whole partition table
    SD_readSingleBlock(0, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

    // Partition Entry format is:
    //     Byte Pos    Length (bytes)  Description
    //     0x0         1               Boot descriptor: 0x00 - non bootable.
    //                                                  0x80 - bootable
    //     0x1         3               First partition sector - address of first sector
    //     0x4         1               File system descriptor:
    //                                     0 = Empty
    //                                     1 = DOS 12-bit FAT < 16MB
    //                                     4 = DOS 16-bit FAT < 32MB
    //                                     5 = Extended DOS
    //                                     6 = DOS 16-bit FAT >= 32MB
    //                                     0x10-0xFF = Free for other file systems
    //     0x5         3               Last partition sector
    //     0x8         4               First sector position relative to beginning of device.
    //                                     (Number of first sector - linear address)
    //     0xC         4               Number of sectors in partition.
    //
    // Note: All sector numbers are stored in LITTLE-ENDIAN (Least significant byte first).
    // First and last partition addresses are given in terms of heads, tracks and sectors, and
    // can therefore be ignored.  The position of the partition can be determined by the First
    // sector partition linear address and the number of sectors.

    word = (dataBlock[0].data[111] >> 8) & 0xFF;
    partition_firstPartitionSector = (((dataBlock[0].data[111]) & 0xFF) << 0) | (((dataBlock[0].data[112]>>24) & 0xFF) << 8) | (((dataBlock[0].data[112]>>16) & 0xFF) << 16);
    fileSystem = (dataBlock[0].data[112]>>8) & 0xFF;

    partition_lastPartitionSector = (((dataBlock[0].data[112]) & 0xFF) << 0) | (((dataBlock[0].data[113]>>24) & 0xFF) << 8) | (((dataBlock[0].data[113]>>16) & 0xFF) << 16);

    // First sector address - little endian
    partition_firstSectorBlockAddr = (((dataBlock[0].data[113] >> 8)  & 0xFF) << 0) | (((dataBlock[0].data[113]      ) & 0xFF) << 8) |
                                     (((dataBlock[0].data[114] >> 24) & 0xFF) << 16) | (((dataBlock[0].data[114] >> 16) & 0xFF) << 24);

    // Num sectors - little endian
    partition_numSectors = (((dataBlock[0].data[114] >> 8)  & 0xFF)) | (((dataBlock[0].data[114]     )  & 0xFF) << 8)  |
                           (((dataBlock[0].data[115] >> 24) & 0xFF) << 16) | (((dataBlock[0].data[115] >> 16) & 0xFF) << 24);

    return returnCode;
}


// Read the FAT partition boot sector and extract sector addresses for
// the File Access Tables, root dirs and data.
unsigned FAT_readFATPartition(SDDataBlock_t dataBlock[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
    unsigned numFATs;
    unsigned numRootDirEntries;
    unsigned numReservedSectors;
    unsigned numFATSectors;
    unsigned numRootDirSectors;
    unsigned sectorsPerFAT;
    unsigned partition_1stSectorBlockAddr = partition_firstSectorBlockAddr;

    SD_readSingleBlock(partition_1stSectorBlockAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

    // sectors per cluster
    sectorsPerCluster = (dataBlock[0].data[3]>>16) & 0xFF;

    // reserved sectors
    numReservedSectors = ((dataBlock[0].data[3] >> 8) & 0xFF) | ((dataBlock[0].data[3] & 0xFF) << 8);

    // number of FATs
    numFATs = (dataBlock[0].data[4] >> 24) & 0xFF;

    // number of root dir entries
    numRootDirEntries = ((dataBlock[0].data[4]) & (0xFF<<8)) | ((dataBlock[0].data[4] >> 16) & 0xFF);

    // sectors per FAT
    sectorsPerFAT = ((dataBlock[0].data[5] >> 8) & 0xFF) | ((dataBlock[0].data[5] & 0xFF) << 8);

    numFATSectors = numFATs * sectorsPerFAT;
    numRootDirSectors = 32;        // 512 dirs, 32 bits per dir.

    FATstartSector = partition_1stSectorBlockAddr + numReservedSectors;
    rootDirStartSector = FATstartSector + numFATSectors ;
    dataStartSector = rootDirStartSector + numRootDirSectors;

  return 0;
}

//
// Validate the filename, extracting base name and extension.
// shortens if length>8 and converts to uppercase.
//
unsigned FAT_validateFileName(char filename[], char shortfilename[], char ext[])
{
  int i;
  int length;
  int baseLength;
  length = safestrlen(filename);

  // convert to upper case
  for (i=0; i<length; i++)
  {
    if ((filename[i] >= 'a') && (filename[i] <= 'z'))
    {
      filename[i] -= 'a' - 'A';
    }
  }

  // work from end looking for '.'
  for (i=length-1; i>0; i--)
  {
    if (filename[i] == '.')
      break;
  }
  baseLength = i;
  i++;

  ext[0] = ' ';
  ext[1] = ' ';
  ext[2] = ' ';
  ext[3] = '\0';
  switch (length-i)
  {
    case 0:
    {
      break;
    }
    case 1:
    {
      ext[0] = filename[i];
      break;
    }
    case 2:
    {
      ext[0] = filename[i];
      ext[1] = filename[i+1];
      break;
    }
    default:
    {
      ext[0] = filename[i];
      ext[1] = filename[i+1];
      ext[2] = filename[i+2];
      break;
    }
  }

  // make short file name
  for (i=0; i<baseLength; i++)
  {
    shortfilename[i] = filename[i];
    if (i == 7)
    {
      break;
    }
  }
  // padd with whitespace
  while (i<8)
  {
    shortfilename[i] = ' ';
    i++;
  }

  if (baseLength >= 8)
  {
    shortfilename[6] = '~';
    shortfilename[7] = '1';
  }

  shortfilename[8] = '\0';

  return 0;
}


// Make a file with the given name in the current directory
// The parent directory sector the dirto be inserted into must be in SD_dataBlock
// fileNamea packed string of length 8 to match FAT short filename
unsigned FAT_newFile(SDDataBlock_t dataBlock[], FP_t fp[], char filename[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned directoryEntryAddr;
  unsigned clusterNum;
  unsigned word;
  unsigned dirSector;
  unsigned found;
  char ext[5];
  char shortfilename[10];

  // check if the file already exists
  found = FAT_find(dataBlock, fp, filename, p_sd_cmd, p_sd_clk, p_sd_dat);
  if (found)
  {
  }
  else
  {
    FAT_validateFileName(filename, shortfilename, ext);

    // Get Cluster Num - need to save the current sector num as get new cluster will load the FAT sector
    // so we will lose the dir sector
    dirSector = currentDirSectorAddr;
    clusterNum = FAT_getFreeCluster(dataBlock, 0, p_sd_cmd, p_sd_clk, p_sd_dat);
    SD_readSingleBlock(dirSector, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

    // find the last dir entry in the directory
    directoryEntryAddr = 0;
    while (((dataBlock[0].data[directoryEntryAddr] >> 24) & 0xFF) != 0)
    {
      directoryEntryAddr = directoryEntryAddr + 8;
      word = (dataBlock[0].data[directoryEntryAddr] >> 24) & 0xFF;
    }

    // set the fields for the entry

    // Short Name
    word = (shortfilename[0] << 24) | (shortfilename[1] << 16) | (shortfilename[2] << 8) | shortfilename[3];
    dataBlock[0].data[directoryEntryAddr] = word;

    word = (shortfilename[4] << 24) | (shortfilename[5] << 16) | (shortfilename[6] << 8) | shortfilename[7];
    dataBlock[0].data[directoryEntryAddr+1] = word;

    // Extension
    dataBlock[0].data[directoryEntryAddr+2] = (ext[0] << 24) | (ext[1] << 16) | (ext[2] << 8);

    // Attributes
    dataBlock[0].data[directoryEntryAddr+2] = dataBlock[0].data[directoryEntryAddr+2] | 0x20;

    // Update date/time

    // Creation date/time

    // Cluster Num
    word = (((clusterNum & 0xFF) << 8) | ((clusterNum >> 8) & 0xFF));
    dataBlock[0].data[directoryEntryAddr+6] = word;

    // File size
    dataBlock[0].data[directoryEntryAddr+7] = 0;

    fp[0].currentClusterNum = clusterNum;
    fp[0].currentSectorNum = 0;
    fp[0].currentBytePos = 0;
    fp[0].dirEntry_entryAddr  = directoryEntryAddr;
    fp[0].dirEntry_blockNum   = currentDirSectorAddr;
  }

  // write the next entry to be 0
  if (directoryEntryAddr < 120)
  {
    dataBlock[0].data[directoryEntryAddr+8] = 0;
  }

  SD_writeSingleBlock(currentDirSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

  return 0;
}


// Open the file with the given filename in the given mode.
// Modes are:
//     'r' : open the file for reading from the beginning of the file
//     'w' : open the file for writing from the beginning of the file
//     'a' : open the file for appending data - writing from the end of the file.
//
// Return 0 if the file could not be opened, or the file pointer initialised to
// the start of the file.
//
// filename: string of length 8 chars to match FATs short filename.
// Mode:     a packed string
//
// If the file doesn't exist:
//     'r' : error
//     'w' : create the file
//     'a' : error
//
// NB: This will not load any sectors for the file - the first sector will be loaded
// on the call to fread.
//
// Return 1 if the file is found, 0 otherwise
FAT16_RTN_t FAT_fopen(SDDataBlock_t dataBlock[], FP_t fp[], char filename[], char mode, port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned clusterNum;
  unsigned found;
  FAT16_RTN_t returnCode;

  returnCode = FAT16_SUCCESS;

  // find the requested short directory entry & get its
  // ClusterID
  returnCode = CheckFileNameRules(filename);
  if (returnCode != FAT16_SUCCESS)
    return returnCode;

  found = FAT_find(dataBlock, fp, filename, p_sd_cmd, p_sd_clk, p_sd_dat);

  if (mode == 'r')
  {
    if (!found)
    {
      fp[0].currentBytePos = 0;
      fp[0].size = 0;
      fp[0].attributes = 0;

      returnCode = FAT16_FAIL;
    }
    else
    {

      // get the cluster for the start of the file
      clusterNum = fp[0].currentClusterNum;

      fp[0].currentClusterNum = clusterNum;
      fp[0].currentSectorNum = 0;
      fp[0].currentBytePos = 0;
    }
  }
  else if (mode == 'w')
  {
    // if file doesn't exist - make it
    if (!found)
    {
      FAT_newFile(dataBlock, fp, filename, p_sd_cmd, p_sd_clk, p_sd_dat);
    }
    else
    {
      returnCode = FAT16_FAIL;
    }

    // get the cluster for the start of the file
    clusterNum = fp[0].currentClusterNum;

    fp[0].currentClusterNum = clusterNum;
    fp[0].currentSectorNum = 0;
    fp[0].currentBytePos = 0;
    fp[0].size = 0;

  }
  else
  {
    returnCode = FAT16_INVALID_PARA;
  }

  return returnCode;
}


// Close the given file pointer.
// Update its filesize in the FAT.
FAT16_RTN_t FAT_fclose(SDDataBlock_t dataBlock[], FP_t fp[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned entryAddr = 0;
  FAT16_RTN_t returnCode;

  returnCode = FAT16_SUCCESS;
  entryAddr = fp[0].dirEntry_entryAddr;

  SD_readSingleBlock(fp[0].dirEntry_blockNum, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

  // set the fields for the entry

  // Short Name
  // Extension
  // Attributes
  // Update date/time
  // Creation date/time

  // File size
  dataBlock[0].data[entryAddr+7] = ((fp[0].size >> 24) & 0xFF) | (((fp[0].size >> 16) & 0xFF) << 8) | (((fp[0].size >> 8)  & 0xFF) << 16) | (((fp[0].size >> 0)  & 0xFF) << 24);

  SD_writeSingleBlock(fp[0].dirEntry_blockNum, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

  fp[0].startAddr = 0xFFFFFFFF;
  fp[0].currentClusterNum = 0xFFFFFFFF;
  fp[0].currentSectorNum = 0xFFFFFFFF;
  fp[0].currentBytePos = 0xFFFFFFFF;

  return returnCode;
}


// Delete the file with the given name
// The parent directory sector must be in dataBlock
// dirNamea packed string of length 8 to match FAT short filename
FAT16_RTN_t FAT_fdelete(SDDataBlock_t dataBlock[], FP_t fp[], char filename[], port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned directoryEntry;
  unsigned found;
  FAT16_RTN_t returnCode;

  returnCode = CheckFileNameRules(filename);
  if (returnCode != FAT16_SUCCESS)
  {

    return returnCode;
  }

  returnCode = FAT16_FAIL;

  // check if the dir already exists
  found = FAT_find(dataBlock, fp, filename, p_sd_cmd, p_sd_clk, p_sd_dat);
  
  if (!found)
  {
  }
  else
  {
    returnCode = FAT16_SUCCESS;

    // mark dir entry as deleted
    directoryEntry = fp[0].dirEntry_entryAddr;
    dataBlock[0].data[directoryEntry] = (dataBlock[0].data[directoryEntry] & 0x00FFFFFF) | (0xE5 << 24);
    SD_writeSingleBlock(currentDirSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);
  }
  return returnCode;
}


// Copy Count elements of size bytes from the file pointer FP
// to array buf, starting at buf[0].  fread also advances the file pointer.
unsigned FAT_fread(SDDataBlock_t dataBlock[], FP_t fp[], char buf[], unsigned size, unsigned count, port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned lastByteAddr;
  unsigned bufPointer;
  unsigned blockNextWordAddr;
  unsigned word;
  unsigned clusterSectorAddr;
  unsigned currentWord;
  unsigned startBytePos;

  char tmpChar[5];

  //SDDataBlock_t block[1];
  //r1Response_t r1Response[1];

  tmpChar[1] = '\0';

  bufPointer = 0;
  word = 0;

  startBytePos = fp[0].currentBytePos;

  // read size*count bytes from the file, starting at the current position
  lastByteAddr = fp[0].currentBytePos + (size*count);

  // determine current word address within the block -
  // NB: should depend on blocksize but currently hardcoded to 512 bytes.
  blockNextWordAddr = (fp[0].currentBytePos >> 2) & 0x7F;

  // read word and align to current byte position
  currentWord = dataBlock[0].data[blockNextWordAddr];
  if (fp[0].currentBytePos & 0x1)
    currentWord = currentWord << 8;
  if (fp[0].currentBytePos & 0x2)
    currentWord = currentWord << 16;

  // if misaligned byte pos, next word addr already incremented
  if (fp[0].currentBytePos & 0x3)
    blockNextWordAddr++;

  // Read bytes from disk in blocks and store into byte array
  while (fp[0].currentBytePos < lastByteAddr)
  {
    // detect when past the end of the file
    if (fp[0].currentBytePos > fp[0].size)
    {
      fp[0].currentBytePos--;
      break;
    }


    // check word alignment - load new word if necessary
    if ((fp[0].currentBytePos & 0x3) == 0)
    {
      // check if past end of this block
      if ((blockNextWordAddr & 0x7F) == 0)
      {
        // load the first sector from a new cluster
        if (fp[0].currentSectorNum >= sectorsPerCluster)
        {
          fp[0].currentClusterNum = FAT_getNextCluster(dataBlock, fp[0].currentClusterNum, p_sd_cmd, p_sd_clk, p_sd_dat);

          if (fp[0].currentClusterNum == 0xFFFF)
          {
            break;
          }

          clusterSectorAddr = FAT_getClusterAddress(fp[0].currentClusterNum);
          fp[0].currentSectorNum = 0;
        }

        // load the next sector from this cluster
        else
        {
          clusterSectorAddr = FAT_getClusterAddress(fp[0].currentClusterNum);
          clusterSectorAddr = clusterSectorAddr + fp[0].currentSectorNum;
        }
        fp[0].currentSectorNum = fp[0].currentSectorNum + 1;
        word = SD_readSingleBlock(clusterSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);
        blockNextWordAddr = 0;
      }

      // read a word
      currentWord = dataBlock[0].data[blockNextWordAddr];
      blockNextWordAddr = blockNextWordAddr + 1;
    }

    buf[bufPointer] = (currentWord >> 24) & 0xFF;
    fp[0].currentBytePos = fp[0].currentBytePos + 1;
    bufPointer = bufPointer + 1;
    currentWord = currentWord << 8;
  }


  return fp[0].currentBytePos - startBytePos;
}


// Copy Count elements of size bytes from array buf, starting at buf[0] to
// the file pointer FP.  fwrite also advances the file pointer.
unsigned FAT_fwrite(SDDataBlock_t dataBlock[], FP_t fp[], char buf[], unsigned size, unsigned count, port p_sd_cmd, port p_sd_clk, port p_sd_dat)
{
  unsigned lastByteAddr;
  unsigned bufPointer;
  unsigned blockNextWordAddr;
  unsigned word;
  unsigned clusterSectorAddr;
  unsigned currentWord;
  unsigned nextClusterNum;
  unsigned startBytePos;

  bufPointer = 0;
  word = 0;

  startBytePos = fp[0].currentBytePos;

  // write size*count bytes to the file, starting at the current position
  lastByteAddr = fp[0].currentBytePos + (size*count);

  // determine current word address within the block -
  // NB: should depend on blocksize but currently hardcoded to 512 bytes.
  blockNextWordAddr = (fp[0].currentBytePos >> 2);

  blockNextWordAddr = blockNextWordAddr & 0x7F;

  // read word and align to current byte position
  currentWord = dataBlock[0].data[blockNextWordAddr];

  clusterSectorAddr = FAT_getClusterAddress(fp[0].currentClusterNum);
  clusterSectorAddr = clusterSectorAddr + fp[0].currentSectorNum;


  // Read bytes from byte array and store in blocks onto disk
  while (fp[0].currentBytePos < lastByteAddr)
  {
    blockNextWordAddr = (fp[0].currentBytePos >> 2) & 0x7F;
    currentWord = dataBlock[0].data[blockNextWordAddr];

    // insert byte
    if ((fp[0].currentBytePos & 0x3) == 0x0)
      currentWord = (currentWord & 0x00FFFFFF) | (buf[bufPointer] << 24);
    else if ((fp[0].currentBytePos & 0x3) == 0x1)
      currentWord = (currentWord & (0xFF00FFFF)) | (buf[bufPointer] << 16);
    else if ((fp[0].currentBytePos & 0x3) == 0x2)
      currentWord = (currentWord & (0xFFFF00FF)) | (buf[bufPointer] << 8);
    else
      currentWord = (currentWord & (0xFFFFFF00)) | (buf[bufPointer]);

    dataBlock[0].data[blockNextWordAddr] = currentWord;

    fp[0].currentBytePos = fp[0].currentBytePos + 1;
    bufPointer = bufPointer + 1;

    // check word alignment - write word if necessary
    if ((fp[0].currentBytePos & 0x3) == 0)
    {
      // check if past end of this block (addr is at start of a block and non zero)
      // - write block and initialise for next
      if ((fp[0].currentBytePos != 0) && (((fp[0].currentBytePos >> 2) & 0x7F) == 0))
      {
        SD_writeSingleBlock(clusterSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

        fp[0].currentSectorNum = fp[0].currentSectorNum + 1;

        // next sector is the first sector from a new cluster
        if (fp[0].currentSectorNum >= sectorsPerCluster)
        {
          nextClusterNum = FAT_getFreeCluster(dataBlock,fp[0].currentClusterNum, p_sd_cmd, p_sd_clk, p_sd_dat);

          // set the current cluster to point to the next cluster
          FAT_setNextCluster(dataBlock, fp[0].currentClusterNum, nextClusterNum, p_sd_cmd, p_sd_clk, p_sd_dat);
          fp[0].currentClusterNum = nextClusterNum;

          clusterSectorAddr = FAT_getClusterAddress(fp[0].currentClusterNum);
          fp[0].currentSectorNum = 0;
        }
        else // next sector from this cluster
        {
          clusterSectorAddr = FAT_getClusterAddress(fp[0].currentClusterNum);
          clusterSectorAddr = clusterSectorAddr + fp[0].currentSectorNum;
        }

        blockNextWordAddr = 0;
      }
      else
      {
        blockNextWordAddr = blockNextWordAddr + 1;
      }
    }

    fp[0].size += 1;
  }

    SD_writeSingleBlock(clusterSectorAddr, dataBlock, p_sd_cmd, p_sd_clk, p_sd_dat);

  return fp[0].currentBytePos - startBytePos;
}


FAT16_RTN_t CheckFileNameRules(char filename[])
{
  FAT16_RTN_t returnCode = FAT16_SUCCESS;

  int i=0;
  while(filename[i] != '\0')
  {
    if (((filename[i] >= 'A') && ((filename[i] <= 'Z'))) ||
        ((filename[i] >= '0') && ((filename[i] <= '9'))) ||
         (filename[i] == '.') ||
         (filename[i] == '~') ||
         (filename[i] == '_'))
    {}
    else
    {
      returnCode = FAT16_INVALID_PARA;
      break;
    }
    i++;
  }

  return returnCode;
}


