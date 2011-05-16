// Copyright (c) 2011, XMOS Ltd., All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

// Originally taken from FatFs - FAT file system module  R0.08b (C)ChaN, 2011
// Copyright (C) 2011, ChaN, all right reserved.

//  Bitbanging MMCv3/SDv1/SDv2 (in SPI mode) control module
// Features and Limitations:
// * Very Easy to Port - It uses only 4-6 bit of GPIO port. No interrupt, no SPI port is used.
// * Platform Independent - You need to modify only a few macros to control GPIO ports.
// * Low Speed - The data transfer rate will be several times slower than hardware SPI.
// * No Media Change Detection - Application program must re-mount the volume after media change or it results a hard error.

#include <print.h>
#include "diskio.h"		/* Common include file for FatFs and disk I/O layer */
#include "sd_io.h"		/* Include device specific declareation file here */

// Platform dependent macros and functions needed to be modified
#define	INIT_PORT()	init_port()	/* Initialize MMC control port (CS/CLK/DI:output, DO/WP/INS:input) */
#define DLY_US(n)	dly_us(n)	/* Delay n microseconds */

#define	CS_H()		cs_h()		/* Set MMC CS "high" */
#define CS_L()		cs_l()		/* Set MMC CS "low" */
#define CK_H()		ck_h()		/* Set MMC SCLK "high" */
#define	CK_L()		ck_l()		/* Set MMC SCLK "low" */
#define DI_H()		mosi_h()	/* Set MMC DI "high" */
#define DI_L()		mosi_l()	/* Set MMC DI "low" */

#define	INS			(1)			/* Card is inserted (yes:true, no:false, default:true) */
#define	WP			(0)			/* Card is write protected (yes:true, no:false, default:false) */

//   Module Private Functions

/* MMC/SD command (SPI mode) */
#define CMD0	(0)			/* GO_IDLE_STATE */
#define CMD1	(1)			/* SEND_OP_COND */
#define	ACMD41	(0x80+41)	/* SEND_OP_COND (SDC) */
#define CMD8	(8)			/* SEND_IF_COND */
#define CMD9	(9)			/* SEND_CSD */
#define CMD10	(10)		/* SEND_CID */
#define CMD12	(12)		/* STOP_TRANSMISSION */
#define ACMD13	(0x80+13)	/* SD_STATUS (SDC) */
#define CMD16	(16)		/* SET_BLOCKLEN */
#define CMD17	(17)		/* READ_SINGLE_BLOCK */
#define CMD18	(18)		/* READ_MULTIPLE_BLOCK */
#define CMD23	(23)		/* SET_BLOCK_COUNT */
#define	ACMD23	(0x80+23)	/* SET_WR_BLK_ERASE_COUNT (SDC) */
#define CMD24	(24)		/* WRITE_BLOCK */
#define CMD25	(25)		/* WRITE_MULTIPLE_BLOCK */
#define CMD41	(41)		/* SEND_OP_COND (ACMD) */
#define CMD55	(55)		/* APP_CMD */
#define CMD58	(58)		/* READ_OCR */

/* Card type flags (CardType) */
#define CT_MMC		0x01		/* MMC ver 3 */
#define CT_SD1		0x02		/* SD ver 1 */
#define CT_SD2		0x04		/* SD ver 2 */
#define CT_SDC		(CT_SD1|CT_SD2)	/* SD */
#define CT_BLOCK	0x08		/* Block addressing */

static DSTATUS Stat = STA_NOINIT;	/* Disk status */

static BYTE CardType;			/* b0:MMC, b1:SDv1, b2:SDv2, b3:Block addressing */


/* Transmit bytes to the MMC (bitbanging)                                */
/* Data to be sent */
/* Number of bytes to send */
static void xmit_mmc ( const BYTE* buff, UINT bc )
{
	BYTE d;

	do
	{
		d = *buff++;	/* Get a byte to be sent */
		byte_out(d);
	} while (--bc);
}


/* Receive bytes from the MMC (bitbanging)                               */
/* Pointer to read buffer */
/* Number of bytes to receive */
static void rcvr_mmc ( BYTE *buff, UINT bc )
{
	BYTE r;

	/* Send  out0xFF */
	DI_H();

	do
	{
		r = byte_in();
		*buff++ = r;			/* Store a received byte */
	} while (--bc);
}


/* Wait for card ready                                                   */
/* 1:OK, 0:Timeout */
static int wait_ready (void)
{
	BYTE d;
	UINT tmr;

	/* Wait for ready in timeout of 500ms */
	for (tmr = 0; tmr < 500; tmr++)
	{
		rcvr_mmc(&d, 1);

		if (d == 0xFF)
		{
			return 1;
		}

		// Wait for 1ms
		DLY_US(1000);
	}

	return 0;
}


/* Deselect the card and release SPI bus                                 */
static void deselect (void)
{
	CS_H();
}


/* Select the card and wait for ready                                    */
/* 1:OK, 0:Timeout */
static int select (void)
{
	CS_L();

	if (!wait_ready())
	{
		deselect();
		return 0;
	}

	return 1;
}


/* Receive a data packet from MMC                                        */
/* 1:OK, 0:Failed */
/* Data buffer to store received data */
/* Byte count */
static int rcvr_datablock (	BYTE *buff, UINT btr )
{
	BYTE d[2];
	UINT tmr;

	/* Wait for data packet in timeout of 100ms */
	for (tmr = 0; tmr < 100; tmr++)
	{
		rcvr_mmc(d, 1);
		if (d[0] != 0xFF)
		{
			break;
		}

		DLY_US(1000);
	}

	if (d[0] != 0xFE) return 0;		/* If not valid data token, retutn with error */

	rcvr_mmc(buff, btr);			/* Receive the data block into buffer */
	rcvr_mmc(d, 2);					/* Discard CRC */

	return 1;						/* Return with success */
}


/* Send a data packet to MMC                                             */
/* 1:OK, 0:Failed */
/* 512 byte data block to be transmitted */
/* Data/Stop token */
static int xmit_datablock (	const BYTE *buff, BYTE token )
{
	BYTE d[2];

	if (!wait_ready()) return 0;

	d[0] = token;
	xmit_mmc(d, 1);				/* Xmit a token */

	if (token != 0xFD) {		/* Is it data token? */
		xmit_mmc(buff, 512);	/* Xmit the 512 byte data block to MMC */
		rcvr_mmc(d, 2);			/* Dummy CRC (FF,FF) */
		rcvr_mmc(d, 1);			/* Receive data response */
		if ((d[0] & 0x1F) != 0x05)	/* If not accepted, return with error */
			return 0;
	}

	return 1;
}


/* Send a command packet to MMC                                          */
/* Returns command response (bit7==1:Send failed) */
/* Command byte */
/* Argument */
static BYTE send_cmd ( BYTE cmd, DWORD arg )
{
	BYTE n, d, buf[6];

	/* ACMD<n> is the command sequense of CMD55-CMD<n> */
	if (cmd & 0x80)
	{
		cmd &= 0x7F;
		n = send_cmd(CMD55, 0);
		if (n > 1) return n;
	}

	/* Select the card and wait for ready */
	deselect();

	if (!select())
	{
		return 0xFF;
	}

	/* Send a command packet */
	buf[0] = 0x40 | cmd;			/* Start + Command index */
	buf[1] = (BYTE)(arg >> 24);		/* Argument[31..24] */
	buf[2] = (BYTE)(arg >> 16);		/* Argument[23..16] */
	buf[3] = (BYTE)(arg >> 8);		/* Argument[15..8] */
	buf[4] = (BYTE)arg;				/* Argument[7..0] */
	n = 0x01;						/* Dummy CRC + Stop */
	if (cmd == CMD0) n = 0x95;		/* (valid CRC for CMD0(0)) */
	if (cmd == CMD8) n = 0x87;		/* (valid CRC for CMD8(0x1AA)) */
	buf[5] = n;
	xmit_mmc(buf, 6);

	/* Receive command response */
	if (cmd == CMD12) rcvr_mmc(&d, 1);	/* Skip a stuff byte when stop reading */
	n = 10;								/* Wait for a valid response in timeout of 10 attempts */

	do
	{
		rcvr_mmc(&d, 1);
	}
	while ((d & 0x80) && --n);

	return d;			/* Return with the response value */
}


// Public Functions
/* Get Disk Status                                                       */
/* Drive number (0) */
DSTATUS disk_status ( BYTE drv )
{
	DSTATUS s = Stat;


	if (drv || !INS) {
		s = STA_NODISK | STA_NOINIT;
	} else {
		s &= ~STA_NODISK;
		if (WP)
			s |= STA_PROTECT;
		else
			s &= ~STA_PROTECT;
	}
	Stat = s;

	return s;
}



// Initialize Disk Drive
/* Physical drive nmuber (0) */
DSTATUS disk_initialize ( BYTE drv )
{
	BYTE n, ty, cmd, buf[4];
	UINT tmr;
	DSTATUS s;

	INIT_PORT();				/* Initialize control port */

	s = disk_status(drv);		/* Check if card is in the socket */
	if (s & STA_NODISK) return s;

	CS_H();

	for (n = 0; n < 10; n++)
	{
		rcvr_mmc(buf, 1);	/* 80 dummy clocks */
	}

	ty = 0;

	/* Enter Idle state */
	if (send_cmd(CMD0, 0) == 1)
	{
		//printstrln("CMD0 OK");

		/* SDv2? */
		if (send_cmd(CMD8, 0x1AA) == 1)
		{
			rcvr_mmc(buf, 4);							/* Get trailing return value of R7 resp */
			if (buf[2] == 0x01 && buf[3] == 0xAA) {		/* The card can work at vdd range of 2.7-3.6V */
				for (tmr = 1000; tmr; tmr--) {			/* Wait for leaving idle state (ACMD41 with HCS bit) */
					if (send_cmd(ACMD41, 1UL << 30) == 0) break;
					DLY_US(1000);
				}
				if (tmr && send_cmd(CMD58, 0) == 0) {	/* Check CCS bit in the OCR */
					rcvr_mmc(buf, 4);
					ty = (buf[0] & 0x40) ? CT_SD2 | CT_BLOCK : CT_SD2;	/* SDv2 */
				}
			}
		} else {							/* SDv1 or MMCv3 */
			if (send_cmd(ACMD41, 0) <= 1) 	{
				ty = CT_SD1; cmd = ACMD41;	/* SDv1 */
			} else {
				ty = CT_MMC; cmd = CMD1;	/* MMCv3 */
			}
			for (tmr = 1000; tmr; tmr--) {			/* Wait for leaving idle state */
				if (send_cmd(ACMD41, 0) == 0) break;
				DLY_US(1000);
			}
			if (!tmr || send_cmd(CMD16, 512) != 0)	/* Set R/W block length to 512 */
				ty = 0;
		}
	}
	CardType = ty;
	if (ty)		/* Initialization succeded */
		s &= ~STA_NOINIT;
	else		/* Initialization failed */
		s |= STA_NOINIT;
	Stat = s;

	deselect();

	return s;
}


/* Read Sector(s)                                                        */
/* Physical drive nmuber (0) */
/* Pointer to the data buffer to store read data */
/* Start sector number (LBA) */
/* Sector count (1..128) */
DRESULT disk_read ( BYTE drv, BYTE *buff, DWORD sector, BYTE count )
{
	DSTATUS s;

	s = disk_status(drv);
	if (s & STA_NOINIT) return RES_NOTRDY;
	if (!count) return RES_PARERR;
	if (!(CardType & CT_BLOCK)) sector *= 512;	/* Convert LBA to byte address if needed */

	if (count == 1) {	/* Single block read */
		if ((send_cmd(CMD17, sector) == 0)	/* READ_SINGLE_BLOCK */
			&& rcvr_datablock(buff, 512))
			count = 0;
	}
	else {				/* Multiple block read */
		if (send_cmd(CMD18, sector) == 0) {	/* READ_MULTIPLE_BLOCK */
			do {
				if (!rcvr_datablock(buff, 512)) break;
				buff += 512;
			} while (--count);
			send_cmd(CMD12, 0);				/* STOP_TRANSMISSION */
		}
	}
	deselect();

	return count ? RES_ERROR : RES_OK;
}


/* Write Sector(s)                                                       */
/* Physical drive nmuber (0) */
/* Pointer to the data to be written */
/* Start sector number (LBA) */
/* Sector count (1..128) */
DRESULT disk_write ( BYTE drv, const BYTE *buff, DWORD sector, BYTE count )
{
	DSTATUS s;


	s = disk_status(drv);
	if (s & STA_NOINIT) return RES_NOTRDY;
	if (s & STA_PROTECT) return RES_WRPRT;
	if (!count) return RES_PARERR;
	if (!(CardType & CT_BLOCK)) sector *= 512;	/* Convert LBA to byte address if needed */

	if (count == 1) {	/* Single block write */
		if ((send_cmd(CMD24, sector) == 0)	/* WRITE_BLOCK */
			&& xmit_datablock(buff, 0xFE))
			count = 0;
	}
	else {				/* Multiple block write */
		if (CardType & CT_SDC) send_cmd(ACMD23, count);
		if (send_cmd(CMD25, sector) == 0) {	/* WRITE_MULTIPLE_BLOCK */
			do {
				if (!xmit_datablock(buff, 0xFC)) break;
				buff += 512;
			} while (--count);
			if (!xmit_datablock(0, 0xFD))	/* STOP_TRAN token */
				count = 1;
		}
	}
	deselect();

	return count ? RES_ERROR : RES_OK;
}


/* Miscellaneous Functions                                               */
/* Physical drive nmuber (0) */
/* Control code */
/* Buffer to send/receive control data */
DRESULT disk_ioctl ( BYTE drv, BYTE ctrl, void *buff )
{
	DRESULT res;
	BYTE n, csd[16];
	WORD cs;


	if (disk_status(drv) & STA_NOINIT)					/* Check if card is in the socket */
		return RES_NOTRDY;

	res = RES_ERROR;
	switch (ctrl) {
		case CTRL_SYNC :		/* Make sure that no pending write process */
			if (select()) {
				deselect();
				res = RES_OK;
			}
			break;

		case GET_SECTOR_COUNT :	/* Get number of sectors on the disk (DWORD) */
			if ((send_cmd(CMD9, 0) == 0) && rcvr_datablock(csd, 16)) {
				if ((csd[0] >> 6) == 1) {	/* SDC ver 2.00 */
					cs= csd[9] + ((WORD)csd[8] << 8) + 1;
					*(DWORD*)buff = (DWORD)cs << 10;
				} else {					/* SDC ver 1.XX or MMC */
					n = (csd[5] & 15) + ((csd[10] & 128) >> 7) + ((csd[9] & 3) << 1) + 2;
					cs = (csd[8] >> 6) + ((WORD)csd[7] << 2) + ((WORD)(csd[6] & 3) << 10) + 1;
					*(DWORD*)buff = (DWORD)cs << (n - 9);
				}
				res = RES_OK;
			}
			break;

		case GET_BLOCK_SIZE :	/* Get erase block size in unit of sector (DWORD) */
			*(DWORD*)buff = 128;
			res = RES_OK;
			break;

		default:
			res = RES_PARERR;
	}

	deselect();

	return res;
}

