// Copyright (c) 2011, XMOS Ltd., All rights reserved
// This software is freely distributable under a derivative of the
// University of Illinois/NCSA Open Source License posted in
// LICENSE.txt and at <http://github.xcore.com/>

// Functions to interface to the SD Card
#include <xs1.h>
#include <platform.h>
#include <print.h>
#include "sd_io.h"

// Structure for the ports to access the SD Card
typedef struct sd_interface_t
{
	out port p_ss;
	out port p_mosi;
	out port p_sclk;
	in port p_miso;
	clock clk1;
	clock clk2;
} sd_interface_t;

sd_interface_t p = { XS1_PORT_1A, XS1_PORT_1B, XS1_PORT_1C, XS1_PORT_1D, XS1_CLKBLK_1, XS1_CLKBLK_2 };

// Ports that mark the in and out byte functions for the logic analyser
out port my_trig_out = XS1_PORT_1E;
out port my_trig_in = XS1_PORT_1F;

// Set the initial clock period = 400kHz - it's actually half a clock period
#define CLK_PERIOD (100000000 / (400000 * 2) )

// Set CS high
void cs_h ( void )
{
	p.p_ss <: 1;
}

// Set CS low
void cs_l ( void )
{
	p.p_ss <: 0;
}

// Set SCLK high
void ck_h ( void )
{
	p.p_sclk <: 1;
}

// Set SCLK low
void ck_l ( void )
{
	p.p_sclk <: 0;
}

// Set MOSI high
void mosi_h ( void )
{
	p.p_mosi <: 1;
}

// Set MOSI low
void mosi_l ( void )
{
	p.p_mosi <: 0;
}

// Initialise the ports
void init_port( void )
{
	// Set the output ports to their default values
	p.p_ss <: 1;
	p.p_sclk <: 0;
	p.p_mosi <: 1;

	#ifdef TRIGGER_LOGIC
		my_trig_out <: 0;
		my_trig_in <: 0;
	#endif
}

// Delay by n x us
void dly_us ( unsigned int n )
{
	unsigned int time;
	timer t;

	t :> time;
	t when timerafter( time + (100 * n) ) :> time;
}

// Send a byte out to the SD Card
void byte_out ( unsigned char c )
{
	unsigned int data = (unsigned int) c;
	unsigned int time;
	timer t;

	#ifdef TRIGGER_LOGIC
		my_trig_out <: 1;
	#endif

	// Intitialise the time
	t :> time;

	// Loop through all 8 bits
	#pragma loop unroll
	for ( int i = 0; i < 8; i++ )
	{
		// Send the data out MSB first bit order - SPI standard
		p.p_mosi <: ( data >> (7 - i));

		// Send the clock high
		p.p_sclk <: 1;
		t when timerafter ( time + CLK_PERIOD ) :> time;

		// Send the clock low
		p.p_sclk <: 0;
		t when timerafter ( time + CLK_PERIOD ) :> time;
	}

	#ifdef PRINT_BYTES
		printchar('0');
		printuintln(data);
	#endif

	#ifdef TRIGGER_LOGIC
		my_trig_out <: 0;
	#endif
}


// Receive a byte from the SD Card
unsigned char byte_in ( void )
{
	unsigned int temp;
	unsigned char data = 0;
	unsigned int time;
	timer t;

	#ifdef TRIGGER_LOGIC
		my_trig_in <: 1;
	#endif

	// Intitialise the time
	t :> time;

	// Loop through all 8 bits
	#pragma loop unroll
	for ( int i = 0; i < 8; i++)
	{
		// Send the clock high
		p.p_sclk <: 1;

		// Wait half a high cycle to sample in the middle of the window
		t when timerafter ( time + (CLK_PERIOD>>1) ) :> time;

		// Get the data MSB first bit order - SPI standard
		p.p_miso :> temp;
		data = (data << 1) + temp;

		// Now wait the rest of the cycle
		t when timerafter ( time + (CLK_PERIOD>>1) ) :> time;

		// Send the clock low
		p.p_sclk <: 0;
		t when timerafter ( time + CLK_PERIOD ) :> time;
	}

	#ifdef PRINT_BYTES
		printchar('I');
		printuintln(data);
	#endif

	#ifdef TRIGGER_LOGIC
		my_trig_in <: 0;
	#endif

	return data;
}
