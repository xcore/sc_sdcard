/*!
 * @file sdcard_com.S
 * @author Benjamin Balga
 *
 * @brief SD Card helper functions (4-bit protocol)
 *
 *  Created on: 11 janv. 2015
 *      Author: bbenj
 */

#include <xs1.h>

.text


/*!
 * @fn void pulse_clock_8(out port Clk)
 * @brief Send 8 clocks on Clk port.
 *
 * @param Clk Clock port
 * @return None
 */
.extern pulse_clock_8
.globl pulse_clock_8.nstackwords
.globl pulse_clock_8.maxchanends
.globl pulse_clock_8.maxtimers
.globl pulse_clock_8.maxthreads

.linkset pulse_clock_8.nstackwords, 0
.linkset pulse_clock_8.maxchanends, 0
.linkset pulse_clock_8.maxtimers, 0
.linkset pulse_clock_8.maxthreads, 0

.globl pulse_clock_8
.cc_top pulse_clock_8.func, pulse_clock_8
.text

/* void
 *  pulse_clock_8(
 *    clkPort       r0  Clock port
 *  )
 */
//void pulse_clock_8(out port Clk);
pulse_clock_8:
    ldc r11, 8
    ldc r1,  0x0
    ldc r2,  0x1

pulse_clock_8_loop:
    out res[r0], r1
    sub r11, r11, 1
    out res[r0], r2

    bt r11, pulse_clock_8_loop
    retsp 0

.cc_bottom pulse_clock_8.func





 /*!
  * @fn void clock_outsh_data(unsigned int &data, out port Clk, port Cmd)
  * @brief Pulse clock with data (data is shifted).
  *
  * @param data Word to send. 'data' is shifted after each output.
  * @param Clk Clock port
  * @param Cmd Command port
  * @return None
  */
.extern clock_outsh_data
.globl clock_outsh_data.nstackwords
.globl clock_outsh_data.maxchanends
.globl clock_outsh_data.maxtimers
.globl clock_outsh_data.maxthreads

.linkset clock_outsh_data.nstackwords, 0
.linkset clock_outsh_data.maxchanends, 0
.linkset clock_outsh_data.maxtimers, 0
.linkset clock_outsh_data.maxthreads, 0

.globl clock_outsh_data
.cc_top clock_outsh_data.func, clock_outsh_data
.text

/* void
 *  clock_outsh_data(
 *    data			r0	Data address
 *    objectID		r1  Clk port
 *    dataSize      r2  Cmd port
 *  )
 */
//void clock_outsh_data(unsigned int &data, out port Clk, port Cmd);
clock_outsh_data:
	ldc r11, 0x0
	out res[r1], r11
	ldw r3, r0[0]
	outshr res[r2], r3
	ldc r11, 0x1
	out res[r1], r11
	stw r3, r0[0]
	retsp 0

.cc_bottom clock_outsh_data.func




/*!
 * @fn void clock_outsh_data_8(unsigned int &data, out port Clk, port Dat)
 * @brief Send 8 clock pulses with data shifted
 *
 * @param data Word to send. 'data' is shifted after each output.
 * @param Clk Clock port
 * @param Dat Data port
 * @return None
 */
.extern clock_outsh_data_8
.globl clock_outsh_data_8.nstackwords
.globl clock_outsh_data_8.maxchanends
.globl clock_outsh_data_8.maxtimers
.globl clock_outsh_data_8.maxthreads

#define clock_outsh_data_8_STACK 3
.linkset clock_outsh_data_8.nstackwords, clock_outsh_data_8_STACK
.linkset clock_outsh_data_8.maxchanends, 0
.linkset clock_outsh_data_8.maxtimers, 0
.linkset clock_outsh_data_8.maxthreads, 0

.globl clock_outsh_data_8
.cc_top clock_outsh_data_8.func, clock_outsh_data_8
.text

/* void
 *  clock_outsh_data_8(
 *    data			r0	Data address
 *    clkPort		r1  Clock block
 *    dataPort      r2  Data input port
 *  )
 */
//void clock_outsh_data_8(unsigned int &data, out port Clk, port Dat);
clock_outsh_data_8:
    entsp clock_outsh_data_8_STACK
    stw r4, sp[1]
    stw r5, sp[2]

	ldc r4,  0x0   // out
	ldc r5,  0x1   // out
	ldc r3,  8     // Counter
	ldw r11, r0[0] // Data

clock_outsh_data_8_loop:
	out res[r1], r4

	outshr res[r2], r11

	out res[r1], r5

	// Decrement and loop if not 0.
	sub r3, r3, 0x1
	bt r3, clock_outsh_data_8_loop

	stw r11, r0[0]

    ldw r4, sp[1]
    ldw r5, sp[2]
	retsp clock_outsh_data_8_STACK

.cc_bottom clock_outsh_data_8.func





/*!
 * @fn void clock_in_data_512(unsigned int &data, out port Clk, port Dat, unsigned int &byteCount, unsigned char buff[])
 * @brief Clock 512 bytes into buff
 *
 * @param data Data address
 * @param Clk Clock port
 * @param Dat Data port
 * @param byteCount Byte count
 * @param buff Byte buffer
 * @return None
 */
.extern clock_in_data_512
.globl clock_in_data_512.nstackwords
.globl clock_in_data_512.maxchanends
.globl clock_in_data_512.maxtimers
.globl clock_in_data_512.maxthreads

#define clock_in_data_512_STACK 7
.linkset clock_in_data_512.nstackwords, clock_in_data_512_STACK
.linkset clock_in_data_512.maxchanends, 0
.linkset clock_in_data_512.maxtimers, 0
.linkset clock_in_data_512.maxthreads, 0

.globl clock_in_data_512
.cc_top clock_in_data_512.func, clock_in_data_512
.text

/* void
 *  clock_in_data_512(
 *    data          r0  Data address
 *    clkPort       r1  Clock port
 *    dataPort      r2  Data input port
 *    byteCount     r3  Byte count address
 *    buff          sp[#1]
 *    buff.bound    sp[#2]
 *  )
 */
//void clock_in_data_512(unsigned int &data, out port Clk, port Dat, unsigned int &byteCount, unsigned char buff[]);
clock_in_data_512:
    entsp clock_in_data_512_STACK
    stw r4,  sp[1] // 0x0 (out)
    stw r5,  sp[2] // 0x1 (out)
    stw r6,  sp[3] // 512 (modulo)
    stw r7,  sp[4] // buff
    stw r8,  sp[5] // ByteCount
    stw r9,  sp[6] // Data in

    ldc r4, 0x0
    ldc r5, 0x1
    ldc r6, 512
    ldw r7, sp[1+clock_in_data_512_STACK] // load buff ptr address
    ldw r8, r3[0]   // load byteCount value
    ldw r9, r0[0]

clock_in_data_512_loop:
    remu r11, r8, r6    // r11 = r8 % r6 (512)
    bf r11, clock_in_data_512_ret

    // Clock data in
    out res[r1], r4
    out res[r1], r5

    nop
    nop

    inshr r9, res[r2]

    out res[r1], r4
    out res[r1], r5

    nop
    nop

    inshr r9, res[r2]
    bitrev r11, r9

    // Store into buffer
    st8 r11, r7[r8] // buff[byteCount] = r11 (data)
    add r8, r8, 1   // increment byteCount value

    bu clock_in_data_512_loop

clock_in_data_512_ret:
    stw r8, r3[0]   // Store byteCount value
    stw r9, r0[0]   // Store data value

    ldw r4,  sp[1]
    ldw r5,  sp[2]
    ldw r6,  sp[3]
    ldw r7,  sp[4]
    ldw r8,  sp[5]
    ldw r9,  sp[6]

    retsp clock_in_data_512_STACK

.cc_bottom clock_in_data_512.func





/*!
 * @fn void send_crc(out port Clk, port Dat, unsigned int crc0, unsigned int crc1, unsigned int crc2, unsigned int crc3)
 * @brief Send CRC bytes
 *
 * @param Clk Clock port
 * @param Dat Data port
 * @param crc0 CRC0
 * @param crc1 CRC1
 * @param crc2 CRC2
 * @param crc3 CRC3
 * @return None
 */
.extern send_crc
.globl send_crc.nstackwords
.globl send_crc.maxchanends
.globl send_crc.maxtimers
.globl send_crc.maxthreads

#define send_crc_STACK 8
.linkset send_crc.nstackwords, send_crc_STACK
.linkset send_crc.maxchanends, 0
.linkset send_crc.maxtimers, 0
.linkset send_crc.maxthreads, 0

.globl send_crc
.cc_top send_crc.func, send_crc
.text

/* void
 *  send_crc(
 *    clkPort       r0  Clock port
 *    dataPort      r1  Data port
 *    crc0          r2  CRC0
 *    crc1          r3  CRC1
 *    crc2          sp[#1]  CRC2
 *    crc3          sp[#2]  CRC3
 *  )
 */
//void send_crc(out port Clk, port Dat, unsigned int crc0, unsigned int crc1, unsigned int crc2, unsigned int crc3);
send_crc:
    entsp send_crc_STACK
    stw r4,  sp[1] // CRC2
    stw r5,  sp[2] // CRC3
    stw r6,  sp[3] // 1 (mask)
    stw r7,  sp[4] // counter
    stw r8,  sp[5] // 0x0 (out)
    stw r9,  sp[6] // 0x1 (out)
    stw r10, sp[7]


    ldw r4, sp[1+send_crc_STACK]    // CRC2
    ldw r5, sp[2+send_crc_STACK]    // CRC3
    ldc r6, 0x1
    ldc r7, 16
    ldc r8, 0x0
    ldc r9, 0x1


send_crc_loop:
    //Dat = (Crc3 & 1) | ((Crc2 & 1) << 1) | ((Crc1 & 1) << 2) | ((Crc0 & 1) << 3);
    // CRC3&1
    and r5, r5, r6
    or  r11, r11, r5
    // CRC2&1
    and r10, r4, r6
    shl r10, r10, 1
    or  r11, r11, r10
    // CRC1&1
    and r10, r3, r6
    shl r10, r10, 2
    or  r11, r11, r10
    // CRC0&1
    and r10, r2, r6
    shl r10, r10, 3
    or  r11, r11, r10


    // Clock out
    out res[r0], r8
    out res[r1], r11
    out res[r0], r9

    // Shift
    shr r2, r2, 1   // CRC0
    shr r3, r3, 1   // CRC1
    shr r4, r4, 1   // CRC2
    shr r5, r5, 1   // CRC3


    // Decrement and loop if not 0.
    sub r7, r7, 0x1
    bt  r7, send_crc_loop
// End of loop

    // End data block
    ldc r11, 0xF
    out res[r0], r8
    out res[r1], r11
    out res[r0], r9


    ldw r4,  sp[1]
    ldw r5,  sp[2]
    ldw r6,  sp[3]
    ldw r7,  sp[4]
    ldw r8,  sp[5]
    ldw r9,  sp[6]
    ldw r10,  sp[7]
    retsp send_crc_STACK

.cc_bottom send_crc.func
