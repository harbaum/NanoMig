/*
  nanomig.cpp 

  NanoMig verilator environment. This is being used to test certain
  aspects of NanoMig in verilator. Since Minimig itself is pretty
  mature this is mainly used to test things that have been changed for
  NanoMig which mainly is the fx68k CPU integration, RAM and ROM
  handling and especially the floppy disk handling-

  This code is an ugly mess as it's just written on the fly to test
  certain things. It's not meant to be nice or clean. But maybe
  someone find this useful anyway.
 */

#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <iomanip>

// define which rom to load into emulated ram/rom
#define KICK "kick13.rom" 
// #define KICK "DiagROM/DiagROM"
// #define KICK "test_rom/test_rom.bin"

// enable various simulation options
// #define UART_ONLY
#define VIDEO   // enable for SDL video
// #define FDC_TEST    // test floppy disk interface
// #define FDC_RAM_TEST_VERIFY   // verify track data against minimigs original firmware fdd.c. only works with ram_test rom

#ifdef FDC_TEST
#define FLOPPY_ADF  "wb13.adf"
#endif

#ifdef VIDEO
#include <SDL.h>
#endif

#include "Vnanomig.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

static Vnanomig *tb;
static VerilatedVcdC *trace;
static double simulation_time;

#define TICKLEN   (0.5/28375160)

// specfiy simulation runtime and from which point in time a trace should
// be written. Not defining this will run the simulation forever which e.g.
// may be useful when running with SDL video emulation enabled
#define TRACESTART   0.4
#define TRACEEND     (TRACESTART + 0.2)   // 0.1s ~ 1G

static uint64_t GetTickCountMs() {
  struct timespec ts;
  
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)(ts.tv_nsec / 1000000) + ((uint64_t)ts.tv_sec * 1000ull);
}

unsigned short kickrom[256*1024];  // 2*256 kBytes = 256k words
#define SWAP16(a)   ((((a)&0x00ff)<<8)|(((a)&0xff00)>>8))

unsigned char ram[512*1024];   // 512k ram

#ifdef VIDEO

#define H_RES   456
#define V_RES   313

SDL_Window*   sdl_window   = NULL;
SDL_Renderer* sdl_renderer = NULL;
SDL_Texture*  sdl_texture  = NULL;

typedef struct Pixel {  // for SDL texture
    uint8_t a;  // transparency
    uint8_t b;  // blue
    uint8_t g;  // green
    uint8_t r;  // red
} Pixel;

Pixel screenbuffer[H_RES*V_RES];

void init_video(void) {
  if (SDL_Init(SDL_INIT_VIDEO) < 0) {
    printf("SDL init failed.\n");
    return;
  }
  
  sdl_window = SDL_CreateWindow("Nanomig", SDL_WINDOWPOS_CENTERED,
	SDL_WINDOWPOS_CENTERED, H_RES, V_RES, SDL_WINDOW_SHOWN);
  if (!sdl_window) {
    printf("Window creation failed: %s\n", SDL_GetError());
    return;
  }
  
  sdl_renderer = SDL_CreateRenderer(sdl_window, -1,
	    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (!sdl_renderer) {
    printf("Renderer creation failed: %s\n", SDL_GetError());
    return;
  }
  
  sdl_texture = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_RGBA8888,
	  SDL_TEXTUREACCESS_TARGET, H_RES, V_RES);
  if (!sdl_texture) {
    printf("Texture creation failed: %s\n", SDL_GetError());
    return;
  }
}

void capture_video(void) {
  static int last_hs_n = -1;
  static int last_vs_n = -1;
  static int sx = 0;
  static int sy = 0;
  static int frame = 0;

  // store pixel
  if(sx/2 < H_RES && sy/2 < V_RES && sx&1 && sy&1) {  
    Pixel* p = &screenbuffer[(sy/2)*H_RES + sx/2];
    p->a = 0xFF;  // transparency
    p->b = tb->blue<<4;
    p->g = tb->green<<4;
    p->r = tb->red<<4;
  }
  sx++;
    
  if(tb->hs_n != last_hs_n) {
    last_hs_n = tb->hs_n;

    if(tb->hs_n) {
      if(!(sy & 15)) {      
	SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, H_RES*sizeof(Pixel));
      
	SDL_RenderClear(sdl_renderer);
	SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
	SDL_RenderPresent(sdl_renderer);
      }
      sx = 0;
      sy++;
    }    
  }

  if(tb->vs_n != last_vs_n) {
    last_vs_n = tb->vs_n;

    if(tb->vs_n) {
      // write frame to disk
      char name[32];
      sprintf(name, "screenshots/frame%04d.raw", frame);
      FILE *f = fopen(name, "wb");
      fwrite(screenbuffer, sizeof(Pixel), H_RES*V_RES, f);
      fclose(f);
      
#ifndef UART_ONLY
      printf("Frame %d @ %.3fms\n", frame, simulation_time*1000);
#endif

      frame++;
      sy = 0;
    }    
  }
}
#endif

#ifdef FDC_TEST
// code taken from minimig firmware fdd.c
#define TRACK_SIZE 12668
#define HEADER_SIZE 0x40
#define DATA_SIZE 0x400
#define SECTOR_SIZE (HEADER_SIZE + DATA_SIZE)
#define SECTOR_COUNT 11
#define LAST_SECTOR (SECTOR_COUNT - 1)
#define GAP_SIZE (TRACK_SIZE - SECTOR_COUNT * SECTOR_SIZE)

unsigned char track_buffer[TRACK_SIZE];

void SPI(int data) {
  static int cnt = 0;

  if(data == -1) {
    printf("resetting buffer\n");
    cnt=0;
    return;
  }
  
  // we may receive more than a full track. This happens if the software
  // requests more than 12668 bytes. The track then wraps and starts
  // transmitting from the track start again ...
  // We ignore this data on minimig size and wrap accordingly during
  // comparison
  if(cnt >= TRACK_SIZE) {
    // printf("Track buffer overflow by %d\n", cnt - TRACK_SIZE);
    cnt++;
    return;
  }
  
  track_buffer[cnt++] = data;  
  if(cnt == TRACK_SIZE)
    printf("Minimig: complete firmware generated track in buffer\n");
}

void SendSector(unsigned char *pData, unsigned char sector, unsigned char track,
		unsigned char dsksynch, unsigned char dsksyncl) {
    unsigned char header_checksum[4];
    unsigned char data_checksum[4];
    unsigned short i;
    unsigned char x;
    unsigned char *p;

    // preamble
    SPI(0xAA);
    SPI(0xAA);
    SPI(0xAA);
    SPI(0xAA);

    // synchronization
    SPI(dsksynch);
    SPI(dsksyncl);
    SPI(dsksynch);
    SPI(dsksyncl);

    // odd bits of header
    x = 0x55;
    header_checksum[0] = x;
    SPI(x);
    x = track >> 1 & 0x55;
    header_checksum[1] = x;
    SPI(x);
    x = sector >> 1 & 0x55;
    header_checksum[2] = x;
    SPI(x);
    x = 11 - sector >> 1 & 0x55;
    header_checksum[3] = x;
    SPI(x);

    // even bits of header
    x = 0x55;
    header_checksum[0] ^= x;
    SPI(x);
    x = track & 0x55;
    header_checksum[1] ^= x;
    SPI(x);
    x = sector & 0x55;
    header_checksum[2] ^= x;
    SPI(x);
    x = 11 - sector & 0x55;
    header_checksum[3] ^= x;
    SPI(x);

    // sector label and reserved area (changes nothing to checksum)
    i = 0x20;
    while (i--)
        SPI(0xAA);

    // send header checksum
    SPI(0xAA);
    SPI(0xAA);
    SPI(0xAA);
    SPI(0xAA);
    SPI(header_checksum[0] | 0xAA);
    SPI(header_checksum[1] | 0xAA);
    SPI(header_checksum[2] | 0xAA);
    SPI(header_checksum[3] | 0xAA);

    // calculate data checksum
    data_checksum[0] = 0;
    data_checksum[1] = 0;
    data_checksum[2] = 0;
    data_checksum[3] = 0;
    p = pData;
    i = DATA_SIZE / 2 / 4;
    while (i--)
    {
        x = *p++;
        data_checksum[0] ^= x ^ x >> 1;
        x = *p++;
        data_checksum[1] ^= x ^ x >> 1;
        x = *p++;
        data_checksum[2] ^= x ^ x >> 1;
        x = *p++;
        data_checksum[3] ^= x ^ x >> 1;
    }

    // send data checksum
    SPI(0xAA);
    SPI(0xAA);
    SPI(0xAA);
    SPI(0xAA);
    SPI(data_checksum[0] | 0xAA);
    SPI(data_checksum[1] | 0xAA);
    SPI(data_checksum[2] | 0xAA);
    SPI(data_checksum[3] | 0xAA);

    // odd bits of data field
    i = DATA_SIZE / 2;
    p = pData;
    while (i--)
        SPI(*p++ >> 1 | 0xAA);

    // even bits of data field
    i = DATA_SIZE / 2;
    p = pData;
    while (i--)
      SPI(*p++ | 0xAA);

#if 1
    printf("header checksum: %02x/%02x/%02x/%02x\n",
           header_checksum[0] | 0xAA,header_checksum[1] | 0xAA,
           header_checksum[2] | 0xAA,header_checksum[3] | 0xAA);
    
    printf("data checksum: %02x/%02x/%02x/%02x\n",
           data_checksum[0] | 0xAA,data_checksum[1] | 0xAA,
           data_checksum[2] | 0xAA,data_checksum[3] | 0xAA);   
#endif
}

void SendGap(void) {
  unsigned short i = GAP_SIZE;
  while (i--)
    SPI(0xAA);
}

static unsigned char sector_buffer[11][512];

void build_track_buffer(int sector, unsigned char *data) {
  static int last_track = -1;
  
  int track_sec = sector % 11;   // sector within track

  if(sector/11 != last_track) {
    printf("track now %d\n", sector/11);
    last_track = sector/11;
    SPI(-1);
  }

  printf("Loading sector track %d, sector %d\n",
	 sector/11, sector%11);
  
  if(!data) {
    FILE *f = fopen(FLOPPY_ADF, "rb");
    if(!f) { perror("open file"); return; }

    fseek(f, sector*512, SEEK_SET);
    if(fread(sector_buffer[track_sec], 1, 512, f) != 512) {  perror("read error"); return; }
    fclose(f);
  } else
    memcpy(sector_buffer[track_sec], data, 512);

  SendSector(sector_buffer[track_sec], track_sec, sector/11, 0x44, 0x89);

  // send GAP after last sector
  if(track_sec == 10)
    SendGap();
}
#endif

// The ram_test programs the hardware to sync onto 0x4489. This
// will result in the first 6 bytes not being written to ram
#define FDC_SKIP 6

#ifdef SD_EMU
#ifndef FDC_TEST
#error SD_EMU enabled but FDC_TEST not. Disable SD_EMU in Makefile
#endif

// Calculate CRC7
// It's a 7 bit CRC with polynomial x^7 + x^3 + 1
// input:
//   crcIn - the CRC before (0 for first step)
//   data - byte for CRC calculation
// return: the new CRC7
uint8_t CRC7_one(uint8_t crcIn, uint8_t data) {
  const uint8_t g = 0x89;
  uint8_t i;

  crcIn ^= data;
  for (i = 0; i < 8; i++) {
    if (crcIn & 0x80) crcIn ^= g;
    crcIn <<= 1;
  }
  
  return crcIn;
}

// Calculate CRC16 CCITT
// It's a 16 bit CRC with polynomial x^16 + x^12 + x^5 + 1
// input:
//   crcIn - the CRC before (0 for rist step)
//   data - byte for CRC calculation
// return: the CRC16 value
uint16_t CRC16_one(uint16_t crcIn, uint8_t data) {
  crcIn  = (uint8_t)(crcIn >> 8)|(crcIn << 8);
  crcIn ^=  data;
  crcIn ^= (uint8_t)(crcIn & 0xff) >> 4;
  crcIn ^= (crcIn << 8) << 4;
  crcIn ^= ((crcIn & 0xff) << 4) << 1;
  
  return crcIn;
}

uint8_t getCRC(unsigned char cmd, unsigned long arg) {
  uint8_t CRC = CRC7_one(0, cmd);
  for (int i=0; i<4; i++) CRC = CRC7_one(CRC, ((unsigned char*)(&arg))[3-i]);
  return CRC;
}

uint8_t getCRC_bytes(unsigned char *data, int len) {
  uint8_t CRC = 0;
  while(len--) CRC = CRC7_one(CRC, *data++);
  return CRC;  
}

unsigned long long reply(unsigned char cmd, unsigned long arg) {
  unsigned long r = 0;
  r |= ((unsigned long long)cmd) << 40;
  r |= ((unsigned long long)arg) << 8;
  r |= getCRC(cmd, arg);
  r |= 1;
  return r;
}

#define OCR  0xc0ff8000  // not busy, CCS=1(SDHC card), all voltage, not dual-voltage card
#define RCA  0x0013

// total cid respose is 136 bits / 17 bytes
unsigned char cid[17] = "\x3f" "\x02TMS" "A08G" "\x14\x39\x4a\x67" "\xc7\x00\xe4";

void sd_handle()  {
  static int last_sdclk = -1;
  static unsigned long sector = 0xffffffff;
  static unsigned long long flen;
  static FILE *fd = NULL;
  static uint8_t sector_data[520];   // 512 bytes + four 16 bit crcs
  static long long cmd_in = -1;
  static long long cmd_out = -1;
  static unsigned char *cmd_ptr = 0;
  static int cmd_bits = 0;
  static unsigned char *dat_ptr = 0;
  static int dat_bits = 0;
  static int last_was_acmd = 0;
  
  if(tb->sdclk != last_sdclk) {
    // rising sd card clock edge
    if(tb->sdclk) {
      cmd_in = ((cmd_in << 1) | tb->sdcmd) & 0xffffffffffffll;

      // sending 4 data bits
      if(dat_ptr && dat_bits) {
        if(dat_bits == 128*8 + 16 + 1 + 1) {
          // card sends start bit
          tb->sddat_in = 0;
          printf("READ-4 START\n");
        } else if(dat_bits > 1) {
          if(dat_bits == 128*8 + 16 + 1) printf("READ DATA START\n");
          if(dat_bits == 1) printf("READ DATA END\n");
          int nibble = dat_bits&1;   // 1: high nibble, 0: low nibble
          if(nibble) tb->sddat_in = (*dat_ptr >> 4)&15;
          else       tb->sddat_in = *dat_ptr++ & 15;
        } else
	  tb->sddat_in = 15;
	
        dat_bits--;
      }
      
      if(cmd_ptr && cmd_bits) {
        int bit = 7-((cmd_bits-1) & 7);
        tb->sdcmd_in = (*cmd_ptr & (0x80>>bit))?1:0;
        if(bit == 7) cmd_ptr++;
        cmd_bits--;
      } else {      
        tb->sdcmd_in = (cmd_out & (1ll<<47))?1:0;
        cmd_out = (cmd_out << 1)|1;
      }
      
      // check if bit 47 is 0, 46 is 1 and 0 is 1
      if( !(cmd_in & (1ll<<47)) && (cmd_in & (1ll<<46)) && (cmd_in & (1ll<<0))) {
        unsigned char cmd  = (cmd_in >> 40) & 0x7f;
        unsigned long arg  = (cmd_in >>  8) & 0xffffffff;
        unsigned char crc7 = cmd_in & 0xfe;
	
        // r1 reply:
        // bit 7 - 0
        // bit 6 - parameter error
        // bit 5 - address error
        // bit 4 - erase sequence error
        // bit 3 - com crc error
        // bit 2 - illegal command
        // bit 1 - erase reset
        // bit 0 - in idle state

        if(crc7 == getCRC(cmd, arg)) {
          printf("%cCMD %2d, ARG %08lx\n", last_was_acmd?'A':' ', cmd & 0x3f, arg);
          switch(cmd & 0x3f) {
          case 0:  // Go Idle State
            break;
          case 8:  // Send Interface Condition Command
            cmd_out = reply(8, arg);
            break;
          case 55: // Application Specific Command
            cmd_out = reply(55, 0);
            break;
          case 41: // Send Host Capacity Support
            cmd_out = reply(63, OCR);
            break;
          case 2:  // Send CID
            cid[16] = getCRC_bytes(cid, 16) | 1;  // Adjust CRC
            cmd_ptr = cid;
            cmd_bits = 136;
            break;
           case 3:  // Send Relative Address
            cmd_out = reply(3, (RCA<<16) | 0);  // status = 0
            break;
          case 7:  // select card
            cmd_out = reply(7, 0);    // may indicate busy          
            break;
          case 6:  // set bus width
            printf("Set bus width to %ld\n", arg);
            cmd_out = reply(6, 0);
            break;
          case 16: // set block len (should be 512)
            printf("Set block len to %ld\n", arg);
            cmd_out = reply(16, 0);    // ok
            break;
          case 17:  // read block
            printf("Request to read single block %ld\n", arg);
            cmd_out = reply(17, 0);    // ok

            // load sector
            {
	      // check for floppy data request
	      if(!fd) {
		fd = fopen(FLOPPY_ADF, "rb");
		if(!fd) { perror("OPEN ERROR"); exit(-1); }
		fseek(fd, 0, SEEK_END);
		flen = ftello(fd);
		printf("Image size is %lld\n", flen);
		fseek(fd, 0, SEEK_SET);
	      }
	      
              fseek(fd, 512 * arg, SEEK_SET);
              int items = fread(sector_data, 2, 256, fd);
              if(items != 256) perror("fread()");

	      // trigger minimig MFM encoding for comparison
	      build_track_buffer(arg, sector_data);
            }
            {
              unsigned short crc[4] = { 0,0,0,0 };
              unsigned char dbits[4];
              for(int i=0;i<512;i++) {
                // calculate the crc for each data line seperately
                for(int c=0;c<4;c++) {
                  if((i & 3) == 0) dbits[c] = 0;
                  dbits[c] = (dbits[c] << 2) | ((sector_data[i]&(0x10<<c))?2:0) | ((sector_data[i]&(0x01<<c))?1:0);      
                  if((i & 3) == 3) crc[c] = CRC16_one(crc[c], dbits[c]);
                }
              }

              printf("SDC CRC = %04x/%04x/%04x/%04x\n", crc[0], crc[1], crc[2], crc[3]);

              // append crc's to sector_data
              for(int i=0;i<8;i++) sector_data[512+i] = 0;
              for(int i=0;i<16;i++) {
                int crc_nibble =
                  ((crc[0] & (0x8000 >> i))?1:0) +
                  ((crc[1] & (0x8000 >> i))?2:0) +
                  ((crc[2] & (0x8000 >> i))?4:0) +
                  ((crc[3] & (0x8000 >> i))?8:0);

                sector_data[512+i/2] |= (i&1)?(crc_nibble):(crc_nibble<<4);
              }
            }
            dat_ptr = sector_data;
            dat_bits = 128*8 + 16 + 1 + 1;
	    break;
            
          default:
            printf("unexpected command\n");
          }

          last_was_acmd = (cmd & 0x3f) == 55;
          
          cmd_in = -1;
        } else
          printf("CMD %02x, ARG %08lx, CRC7 %02x != %02x!!\n", cmd, arg, crc7, getCRC(cmd, arg));         
      }      
    }      
    last_sdclk = tb->sdclk;     
  }
}      
#endif

// proceed simulation by one tick
void tick(int c) {
  static uint64_t ticks = 0;
  static int sector_tx = 0;
  static int sector_tx_cnt = 512;
  
  tb->clk = c;

  tb->eval();

#ifdef VIDEO
  if(c) capture_video();
#endif

#ifdef FDC_TEST
  // check for disk led
  static int floppy_led_D = -1;
  if(tb->floppy_led != floppy_led_D) {
    printf("Floppy LED = %s at %.3fms\n", tb->floppy_led?"ON":"OFF", simulation_time*1000);
    floppy_led_D = tb->floppy_led;
  }
    
#ifdef SD_EMU
  // full sd card emulation enabled
  sd_handle();
#endif
  {
    // ram_test floppy test writes the received data to $10000
    // analyzing this allows to verify the MFM encoding

#ifndef SD_EMU
    if(c) {
      tb->sdc_byte_in_strobe = 0;
      static int sub_cnt = 0;
      if(sub_cnt++ == 8) {
	sub_cnt = 0;
      
	// without SD card emulation we drive the floppy's sector io directly
	tb->sdc_done = 0;
	
	// push requested sector data into core
	if(tb->sdc_busy) {
	  if(sector_tx_cnt < 512) {
	    tb->sdc_byte_in_strobe = 1;
	    tb->sdc_byte_in_data = sector_buffer[sector_tx][sector_tx_cnt];
	    tb->sdc_byte_in_addr = sector_tx_cnt++;
	    
	    if(sector_tx_cnt == 512) {
	      tb->sdc_done = 1;
	      tb->sdc_busy = 0;
	    }
	  }
	}
      }
    }
#endif
          
    static int last_clk_7m;
    // falling edge of clk_7m
    if(!tb->clk_7m && last_clk_7m) {
#ifdef FDC_RAM_TEST_VERIFY
      static int ram_cnt = 0;
      
      if(!tb->ram_we && (tb->ram_bank&1) &&
	 (((tb->ram_a & 0xfffff)<<1) >= 0x10000)) {
	int adr = ((tb->ram_a & 0xfffff)<<1) - 0x10000 + FDC_SKIP;
	
       	ram_cnt++;
	// printf("Written: %d\n", ram_cnt);	

	// the track data should wrap when more than the a complete track is being read
	while(adr >= TRACK_SIZE) adr -= TRACK_SIZE;
	
	unsigned short mm_orig = track_buffer[adr+1] + 256*track_buffer[adr];
	//	printf("MFM WR %d (%d/%d) = %04x (%04x)\n", adr,
	//	       adr/SECTOR_SIZE, (adr%SECTOR_SIZE)/2, tb->ram_dout, mm_orig);

	// verify with mfm data generated from the original
	// minimig firmware code
	if(tb->ram_dout != mm_orig) {
	  tb->trigger = 1;
	  printf("MFM mismatch %d (sector %d/word %d) is %04x, expected %04x\n",
		 adr, adr/SECTOR_SIZE, (adr%SECTOR_SIZE)/2,
		 tb->ram_dout, mm_orig);
	}

      }
#endif

#ifndef SD_EMU      
      // react on sdc_rd
      if(tb->sdc_rd & 1) {
	tb->sdc_busy = 1;

	printf("SD request, sector %d (tr %d, sd %d, sec %d)\n",
	       tb->sdc_sector, tb->sdc_sector/22, (tb->sdc_sector/11)&1, tb->sdc_sector%11);

	// this triggers two things:
	// - the track is read into a track buffer using the minimig MFM encoder
	// - the sectors are sent into Paula/Floppy as raw sectors
	build_track_buffer(tb->sdc_sector, NULL);
	sector_tx_cnt = 0;
	sector_tx = tb->sdc_sector%11;
      }
#endif
    }
    last_clk_7m = tb->clk_7m;
  }
#endif
  
  // analyze uart output (for diag rom)
  if(c) {
    static int tx_data = tb->uart_tx;
    static double tx_last = simulation_time;
    static int tx_byte = 0xffff;

    // data changed
    if(tb->uart_tx != tx_data) {
      // save new value      
      tx_data = tb->uart_tx;

      // and synchronize to the arrival time of this bit
      tx_last = simulation_time - (0.5/9600);
    }

    // sample every 105us (9600 bit/s)
    if(simulation_time-tx_last >= (1.0/9600)) {
      // printf("SAMPLE %s\n", tx_data?"Hi":"LOW");

      // shift "from top" as uart sends LSB first
      tx_byte = (tx_byte >> 1)&0x1ff;
      if(tx_data) tx_byte |= 0x200;

      // printf("DATA %s now %02x\n", tx_data?"H":"L", tx_byte);

      // start bit?
      if((tx_byte & 0x01) == 0) {
	if(!(tx_byte & 0x200)) {
	  printf("----> broken stop bit!!!!!!!!!!!\n");
	}
	else {
#ifndef UART_ONLY
	  printf("UART(%02x %c)\n", (tx_byte >> 1)&0xff, (tx_byte >> 1)&0xff);
#else
	  printf("%c", (tx_byte >> 1)&0xff);
	  fflush(stdout);
#endif
	}
	tx_byte = 0xffff;
      }
      
      tx_last = simulation_time;
    }
  }
  
  // ce[0] == 0 -> chip0
  // ce[1] == 0 -> kick
  
  // ram io shortly after falling edge of clk7
  static int last_clk_7m_x = 0;
  static int ram_trigger = 0;
  ram_trigger <<= 1;
  if(!tb->clk_7m && last_clk_7m_x) ram_trigger |= 1;
  last_clk_7m_x = tb->clk_7m;

  // ram access three 28Mhz events (both edges) after clk7 falling edge
  if(ram_trigger & 8) {
    if(!tb->ram_we) {
      // we only allow chipram write
      if(tb->ram_bank != 1) {
	printf("unsupported ram write bank %d addr %08x = %04x\n",
	       tb->ram_bank, 2*tb->ram_a, tb->ram_dout);	
	exit(-1);
      }
	
      // ram_a is actually the word address
      int addr = (tb->ram_a<<1) & ((512*1024)-1);
      
      // printf("WR RAM %08x = %04x\n", tb->ram_a<<1, tb->ram_dout);
      
      if(!(tb->ram_be & 1)) ram[addr+0] = tb->ram_dout>>8;
      if(!(tb->ram_be & 2)) ram[addr+1] = tb->ram_dout&0xff;
    }
  
    if(!tb->ram_oe) {
      // ram is actually read on the falling edge of clk7. It's then delayed
      // by two clk28 cycles to deliver data "late"
      
      if(tb->ram_bank & 8) {
	// kickrom usually is 256k, but can be 512k. So there's a mirror
	// in the 256k case	
	tb->ram_din = SWAP16(kickrom[tb->ram_a & 0x3ffff]);
	// printf("RD KICK %08x = %04x\n", tb->ram_a<<1, tb->ram_din);      
      } else if(tb->ram_bank & 1) {
	// printf("Chip Read addr %08x\n", 2*(tb->ram_a & 0x3ffff));
	tb->ram_din = SWAP16(((unsigned short*)ram)[tb->ram_a & 0x3ffff]);
	// printf("RD RAM %08x = %04x\n", tb->ram_a<<1, tb->ram_din);
      } else {
	printf("Unknown Read bank %d, addr %08x\n", tb->ram_bank, tb->ram_a);
	exit(-1);	
      }
    }
  }
  
  if(simulation_time == 0)
    ticks = GetTickCountMs();
  
  // after one simulated millisecond calculate real time */
  if(simulation_time >= 0.001 && ticks) {
    ticks = GetTickCountMs() - ticks;
    printf("Simulation speed factor is 1:%lu\n", ticks);
    ticks = 0;
  }

  // trace after
#ifdef TRACESTART
  if(simulation_time > TRACESTART) trace->dump(1000000000000 * simulation_time);
#endif
  simulation_time += TICKLEN;

}

int main(int argc, char **argv) {
  FILE *fd = fopen(KICK, "rb");
  if(!fd) { perror("load kick"); exit(-1); }
  
  int len = fread(kickrom, 1024, 512, fd);
  if(len != 512) {
    if(len != 256) {
      printf("256/512k kick read failed\n");
    } else {
      // just read a second image
      fseek(fd, 0, SEEK_SET);
      len = fread(kickrom+128*1024, 1024, 256, fd);
      if(len != 256) { printf("2nd read failed\n"); exit(-1); }
    }
  }
  fclose(fd);

#if 0
  // patch initial delay loop
  kickrom[0xda/2] = SWAP16(0x0000);
  kickrom[0xdc/2] = SWAP16(0x0010);
#endif
  
#ifdef VIDEO
  init_video();
#endif

  // Initialize Verilators variables
  Verilated::commandArgs(argc, argv);
  Verilated::traceEverOn(true);
  trace = new VerilatedVcdC;
  trace->spTrace()->set_time_unit("1ns");
  trace->spTrace()->set_time_resolution("1ps");
  simulation_time = 0;
  
  // Create an instance of our module under test
  tb = new Vnanomig;
  tb->trace(trace, 99);
  trace->open("nanomig.vcd");
  
#ifdef SD_EMU
  tb->sdcmd_in = 1; tb->sddat_in = 15;  // inputs of sd card
#endif
  
  tb->reset = 1;
  for(int i=0;i<10;i++) {
    tick(1);
    tick(0);
  }
  
  tb->reset = 0;

  /* run for a while */
  while(
#ifdef TRACEEND
	simulation_time<TRACEEND &&
#endif
	1) {
#ifdef TRACEEND
    // do some progress outout
    int percentage = 100 * simulation_time / TRACEEND;
    static int last_perc = -1;
    if(percentage != last_perc) {
#ifndef UART_ONLY
      printf("progress: %d%%\n", percentage);
#endif
      last_perc = percentage;
    }
#endif
    tick(1);
    tick(0);
  }
  
  printf("stopped after %.3fms\n", 1000*simulation_time);
  
  trace->close();
}
