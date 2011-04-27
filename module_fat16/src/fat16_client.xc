// Copyright (c) 2011, XMOS Ltd, All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

/*
 * @ModuleName FAT16_Client
 * @Author Ali Dixon
 * @Date 07/06/2008
 * @Version 1.0
 * @Description: Client side functions for SD_FAT16
 *
*/ 

#include <xs1.h>
#include <string.h>
#include "fat16_client.h"
#include "fat16_def.h"

#define READ_WRITE_BUFFER_SIZE 512


// Initialise the card and file system
FAT16_RTN_t FAT16_Clnt_initialise(chanend server)
{
  unsigned returnCode;
  master
  {
    server <: (int)FAT16_CMD_initialise;
    server <: (int)0;  // argc
  }
  
  slave
  {
    server :> returnCode;
  }
    
  return returnCode;
}


// Open a file
FAT16_RTN_t FAT16_Clnt_fopen(chanend server, FP_t fp[], char filename[], char mode)
{
  unsigned i;
  unsigned returnCode;
  
  i=0;  

  master 
  { 
    server <: (unsigned)FAT16_CMD_fopen;
    server <: (unsigned) 2;   // argc
    i=0;
    
    while (filename[i] != '\0')
    {
      server <: (char)filename[i];
      i++;
    }
    
    server <: (char)'\0';
    server <: (char)mode;
    server <: (char)'\0';    
  }  
  
  slave 
  {    
    server :> returnCode;
    server :> fp[0];
  }    
  return returnCode;
}

// Close a file
FAT16_RTN_t FAT16_Clnt_fclose(chanend server, FP_t fp[])
{
  unsigned returnCode;
  master 
  { 
    server <: (unsigned)FAT16_CMD_fclose;
    server <: (unsigned) 0;   // argc    
  }  
  
  // send args
  master
  {
    server <: fp[0];
  }
  
  // receive args
  slave
  {
    server :> returnCode;
    server :> fp[0];
  }
  
  return returnCode;
}


// Read from an open file
unsigned FAT16_Clnt_fread(chanend server, FP_t fp[], char buffer[], unsigned size, unsigned count)
{
  unsigned i;
  unsigned numBytesRead = 0;
     
  if ((size * count) <= READ_WRITE_BUFFER_SIZE)
  { 
    master 
    { 
      server <: (unsigned)FAT16_CMD_fread;
      server <: (unsigned) 0;   // argc
      i=0;
    }   
    
    // send specific args
    master
    {
      server <: fp[0];
      server <: size;
      server <: count;  
    } 
      
    slave
    {
      // data count
      server :> numBytesRead;      
      if (numBytesRead > 0)
      { 
        // receive data 
        for (unsigned i=0; i<numBytesRead; i++)
        {
          server :> buffer[i];
        }  
        server :> fp[0];
      } 
    }     
  }   
  return numBytesRead;
}


// Write to an open file
unsigned FAT16_Clnt_fwrite(chanend server, FP_t fp[], char buffer[], unsigned size, unsigned count)
{
  unsigned numBytesWritten = 0;
  unsigned i;
  
  if ((size * count) <= READ_WRITE_BUFFER_SIZE)
  {
      
    master 
    { 
      server <: (unsigned)FAT16_CMD_fwrite;
      server <: (unsigned) 0;   // argc
      i=0;    
    }    
      
    master
    {
      server <: fp[0];
      server <: size;
      server <: count;
          
      // send data 
      for (unsigned i=0; i<count; i++)
      {
        server <: (char)buffer[i];
      } 
    }
  
    // return args
    slave
    {
      server :> numBytesWritten;
      server :> fp[0];
    }   
  }
    
  return numBytesWritten;
}


// Open the dir with the given name
FAT16_RTN_t FAT16_Clnt_opendir(chanend server, char name[], DIR_t dir[])
{
  unsigned returnCode;
  master
  {
    server <: FAT16_CMD_opendir;
    server <: 0;  // argc
  }
  
  // send current dir
  master 
  {
    server <: dir[0];  
  }
  
  // return args
  slave 
  {  
    server :> returnCode;
    server :> dir[0];  
  }
    
  return FAT16_SUCCESS;
}


// Close the given dir
FAT16_RTN_t FAT16_Clnt_closedir(chanend server, DIR_t dir[])
{
  unsigned returnCode;
  master
  {
    server <: FAT16_CMD_closedir;
    server <: 0;  // argc
  }
  
  // send current dir
  master 
  {
    server <: dir[0];  
  }
  
  // return args
  slave 
  {  
    server :> returnCode;
    server :> dir[0];  
  }  
  return FAT16_SUCCESS;
}


// readdir
unsigned FAT16_Clnt_readdir(chanend server, DIR_t dir[])
{
  unsigned returnCode;
  master
  {
    server <: FAT16_CMD_readdir;
    server <: 0;  // argc
  }
  
  // send current dir
  master 
  {
    server <: dir[0];  
  }
  
  // return args
  slave 
  {  
    server :> returnCode;
    server :> dir[0];  
  }
  
  return returnCode;
}


// List current directory (uses xlog)
FAT16_RTN_t FAT16_Clnt_ls(chanend server)
{
  unsigned returnCode;
  master
  {
    server <: FAT16_CMD_ls;
    server <: 0;  // argc
  }
  
  // return args
  slave 
  {  
    server :> returnCode;
  }
  
  return returnCode;
}


// Delete a file
FAT16_RTN_t FAT16_Clnt_rm(chanend server, FP_t fp[], char filename[])
{
  unsigned i;
  unsigned returnCode;
  
  i=0;  

  master 
  { 
    server <: (unsigned)FAT16_CMD_rm;
    server <: (unsigned) 1;   // argc
    i=0;
    
    while (filename[i] != '\0')
    {
      server <: (char)filename[i];
      i++;
    }
    
    server <: (char)'\0';
  }  
  
  // return args
  slave 
  {    
    server :> returnCode;
  }
    
  return returnCode;
}


// Close the server
FAT16_RTN_t FAT16_Clnt_finish(chanend server)
{
  unsigned i;
  unsigned returnCode;
  
  i=0;  

  master 
  { 
    server <: (unsigned)FAT16_CMD_finish;
    server <: (unsigned) 0;   // argc
    i=0;    
  }  
  
  // return args
  slave 
  {    
    server :> returnCode;
  }
    
  return returnCode;
}
