/*
  nanomig_aga_tb.cpp 

  NanoMig verilator environment. This is being used to test certain
  aspects of NanoMig in verilator. Since Minimig itself is pretty
  mature this is mainly used to test things that have been changed for
  NanoMig which mainly is the fx68k CPU integration, RAM and ROM
  handling and especially the floppy disk handling-

  This code is an ugly mess as it's just written on the fly to test
  certain things. It's not meant to be nice or clean. But maybe
  someone find this useful anyway.
 */

#ifdef VIDEO
#include <SDL.h>
#include <SDL_image.h>
// one frame is 20.0326ms
#endif

#include "Vnanomig_tb.h"
#include "verilated.h"
#include "verilated_vcd_c.h"

#define KICK "kick13.rom" 
// #define KICK "kick12.rom" 
// #define KICK "../src/ram_test/ram_test.bin"

#define FDC_TEST

#ifdef FDC_TEST
#define FLOPPY_ADF  "df0.adf"
// #define FLOPPY_ADF  "random.adf"

// #define FDC_RAM_TEST_VERIFY   // verify track data against minimigs original firmware fdd.c. only works with ram_test rom
FILE *adf_fd = NULL;
#endif

static Vnanomig_tb *tb;
static VerilatedVcdC *trace;
static double simulation_time;

#define TICKLEN   (0.5/28375160)

// specfiy simulation runtime and from which point in time a trace should
// be written
//#define TRACESTART   0.0 // 4.2
//#define TRACEEND     (TRACESTART + 0.1)   // 0.1s ~ 1G

// kick13 events:
// 80ms -> hardware is out of sysctrl reset
// 330ms -> screen darkgrey
// 1540ms -> screen lightgrey
// 2489ms -> power led on
// 2500ms -> screen white
// 4235ms -> first fdd selection
// 4256ms -> first fdd read attempt
// 4560ms -> floppy/hand if no disk
// 6000ms -> second floppy access if first one was successful
// 10750ms -> workbench 1.3 draws blue AmigaDOS window
// 22000ms -> no clock found
// 54000ms -> workbench opens

/* =============================== video =================================== */

#ifdef VIDEO

// This is the max texture size we can handle. The actual size at 28Mhz sampling rate
// and without scan doubler will be 1816x313 since the actual pixel clock is only 7Mhz.
// With scandoubler it will be 908x626. The aspect ratio will be adjusted to the
// window and thus the image will not looked stretched.
#define MAX_H_RES   2048
#define MAX_V_RES   1024

SDL_Window*   sdl_window   = NULL;
SDL_Renderer* sdl_renderer = NULL;
SDL_Texture*  sdl_texture  = NULL;
int sdl_cancelled = 0;

typedef struct Pixel {  // for SDL texture
    uint8_t a;  // transparency
    uint8_t b;  // blue
    uint8_t g;  // green
    uint8_t r;  // red
} Pixel;

Pixel screenbuffer[MAX_H_RES*MAX_V_RES];

void init_video(void) {
  if (SDL_Init(SDL_INIT_VIDEO) < 0) {
    printf("SDL init failed.\n");
    return;
  }

  // start with a 454x313 or scandoubed 908x626screen
  sdl_window = SDL_CreateWindow("Nanomig", SDL_WINDOWPOS_CENTERED,
        SDL_WINDOWPOS_CENTERED, 2*454, 2*313, SDL_WINDOW_RESIZABLE | SDL_WINDOW_SHOWN);
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
}

// https://stackoverflow.com/questions/34255820/save-sdl-texture-to-file
void save_texture(SDL_Renderer *ren, SDL_Texture *tex, const char *filename) {
    SDL_Texture *ren_tex = NULL;
    SDL_Surface *surf = NULL;
    int w, h;
    int format = SDL_PIXELFORMAT_RGBA32;;
    void *pixels = NULL;

    /* Get information about texture we want to save */
    int st = SDL_QueryTexture(tex, NULL, NULL, &w, &h);
    if (st != 0) { SDL_Log("Failed querying texture: %s\n", SDL_GetError()); goto cleanup; }

    // adjust aspect ratio
    while(w > 2*h) w/=2;
    
    ren_tex = SDL_CreateTexture(ren, format, SDL_TEXTUREACCESS_TARGET, w, h);
    if (!ren_tex) { SDL_Log("Failed creating render texture: %s\n", SDL_GetError()); goto cleanup; }

    /* Initialize our canvas, then copy texture to a target whose pixel data we can access */
    st = SDL_SetRenderTarget(ren, ren_tex);
    if (st != 0) { SDL_Log("Failed setting render target: %s\n", SDL_GetError()); goto cleanup; }

    SDL_SetRenderDrawColor(ren, 0x00, 0x00, 0x00, 0x00);
    SDL_RenderClear(ren);

    st = SDL_RenderCopy(ren, tex, NULL, NULL);
    if (st != 0) { SDL_Log("Failed copying texture data: %s\n", SDL_GetError()); goto cleanup; }

    /* Create buffer to hold texture data and load it */
    pixels = malloc(w * h * SDL_BYTESPERPIXEL(format));
    if (!pixels) { SDL_Log("Failed allocating memory\n"); goto cleanup; }

    st = SDL_RenderReadPixels(ren, NULL, format, pixels, w * SDL_BYTESPERPIXEL(format));
    if (st != 0) { SDL_Log("Failed reading pixel data: %s\n", SDL_GetError()); goto cleanup; }

    /* Copy pixel data over to surface */
    surf = SDL_CreateRGBSurfaceWithFormatFrom(pixels, w, h, SDL_BITSPERPIXEL(format), w * SDL_BYTESPERPIXEL(format), format);
    if (!surf) { SDL_Log("Failed creating new surface: %s\n", SDL_GetError()); goto cleanup; }

    /* Save result to an image */
    st = IMG_SavePNG(surf, filename);
    if (st != 0) { SDL_Log("Failed saving image: %s\n", SDL_GetError()); goto cleanup; }
    
    // SDL_Log("Saved texture as PNG to \"%s\" sized %dx%d\n", filename, w, h);

cleanup:
    SDL_FreeSurface(surf);
    free(pixels);
    SDL_DestroyTexture(ren_tex);
}

void capture_video(void) {
  static int last_hs_n = -1;
  static int last_vs_n = -1;
  static int sx = 0;
  static int sy = 0;
  static int frame = 0;
  static int frame_line_len = 0;
  
  // store pixel
  if(sx < MAX_H_RES && sy < MAX_V_RES) {  
    Pixel* p = &screenbuffer[sy*MAX_H_RES + sx];
    p->a = 0xFF;  // transparency
    p->b = tb->blue<<4;
    p->g = tb->green<<4;
    p->r = tb->red<<4;
  }
  sx++;
    
  if(tb->hs_n != last_hs_n) {
    last_hs_n = tb->hs_n;

    // trigger on rising hs edge
    if(tb->hs_n) {
      // no line in this frame detected, yet
      if(frame_line_len >= 0) {
	if(frame_line_len == 0)
	  frame_line_len = sx;
	else {
	  if(frame_line_len != sx) {
	    printf("frame line length unexpectedly changed from %d to %d\n", frame_line_len, sx);
	    frame_line_len = -1;	  
	  }
	}
      }
      
      sx = 0;
      sy++;
    }    
  }

  if(tb->vs_n != last_vs_n) {
    last_vs_n = tb->vs_n;

    // trigger on rising vs edge
    if(tb->vs_n) {
      // draw frame if valid
      if(frame_line_len > 0) {
	
	// check if current texture matches the frame size
	if(sdl_texture) {
	  int w=-1, h=-1;
	  SDL_QueryTexture(sdl_texture, NULL, NULL, &w, &h);
	  if(w != frame_line_len || h != sy) {
	    SDL_DestroyTexture(sdl_texture);
	    sdl_texture = NULL;
	  }
	}
	  
	if(!sdl_texture) {
	  sdl_texture = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_RGBA8888,
					  SDL_TEXTUREACCESS_TARGET, frame_line_len, sy);
	  if (!sdl_texture) {
	    printf("Texture creation failed: %s\n", SDL_GetError());
	    sdl_cancelled = 1;
	  }
	}
	
	if(sdl_texture) {	
	  SDL_UpdateTexture(sdl_texture, NULL, screenbuffer, MAX_H_RES*sizeof(Pixel));
	  
	  SDL_RenderClear(sdl_renderer);
	  SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
	  SDL_RenderPresent(sdl_renderer);

	  //	  SDL_Texture* target = SDL_GetRenderTarget(renderer);
	  //	  SDL_SetRenderTarget(renderer, texture);
	  char name[32];
	  sprintf(name, "screenshots/frame%04d.png", frame);
	  save_texture(sdl_renderer, sdl_texture, name);
	}
      }
	
      // process SDL events
      SDL_Event event;
      while( SDL_PollEvent( &event ) ){
	if(event.type == SDL_QUIT)
	  sdl_cancelled = 1;
	
	if(event.type == SDL_KEYDOWN && event.key.keysym.sym == SDLK_ESCAPE)
	    sdl_cancelled = 1;
      }
#if 0    
      // write frame to disk
      char name[32];
      sprintf(name, "screenshots/frame%04d.raw", frame);
      FILE *f = fopen(name, "wb");
      fwrite(screenbuffer, sizeof(Pixel), H_RES*V_RES, f);
      fclose(f);
#endif
      
#ifndef UART_ONLY
      printf("%.3fms frame %d is %dx%d\n", simulation_time*1000, frame, frame_line_len, sy);
#endif

      frame++;
      frame_line_len = 0;
      sy = 0;
    }    
  }
}
#endif

static uint64_t GetTickCountMs() {
  struct timespec ts;
  
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)(ts.tv_nsec / 1000000) + ((uint64_t)ts.tv_sec * 1000ull);
}

unsigned short ram[8*512*1024];  // 8 Megabytes

void load_kick(void) {
  printf("Loading kick into last 512k of 8MB ram\n");
  FILE *fd = fopen(KICK, "rb");
  if(!fd) { perror("load kick"); exit(-1); }
  
  int len = fread(ram+(0x780000/2), 1024, 512, fd);
  if(len != 512) {
    if(len != 256) {
      printf("256/512k kick read failed\n");
    } else {
      // just read a second image
      fseek(fd, 0, SEEK_SET);
      len = fread(ram+(0x780000/2)+128*1024, 1024, 256, fd);
      if(len != 256) { printf("2nd read failed\n"); exit(-1); }
    }
  }
  fclose(fd);
}

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
  if(cnt == TRACK_SIZE) {
    printf("Minimig: complete firmware generated track in buffer\n");
#if 0
    // dump a single sector and header split into data and clock
    for(int i=0;i<SECTOR_SIZE;i) {
      printf("%04x:", i);
#if 0
      // print hex words
      for(int j=0;j<8;j++,i+=2) {
	unsigned short w = 256*track_buffer[i]+track_buffer[i+1];	
	printf(" %04x", w);
      }
#else
      // print data split clock and data bytes
      for(int j=0;j<8;j++,i+=2) {
	unsigned short w = 256*track_buffer[i]+track_buffer[i+1];
	unsigned char b =
	  ((w&0x8000)>>8)|((w&0x2000)>>7)|((w&0x0800)>>6)|((w&0x0200)>>5)|
	  ((w&0x0080)>>4)|((w&0x0020)>>3)|((w&0x0008)>>2)|((w&0x0002)>>1);	
	printf(" %02x", b);
      }

      printf(" ");
      i-=16;
      
      for(int j=0;j<8;j++,i+=2) {
	unsigned short w = 256*track_buffer[i]+track_buffer[i+1];
	unsigned char b =
	  ((w&0x4000)>>7)|((w&0x1000)>>6)|((w&0x0400)>>5)|((w&0x0100)>>4)|
	  ((w&0x0040)>>3)|((w&0x0100)>>2)|((w&0x0004)>>1)|((w&0x0001)>>0);	
	printf(" %02x", b);
      }
#endif      
      printf("\n");
    }    
#endif
  }
}

void SendSector(unsigned char *pData, unsigned char sector, unsigned char track,
		unsigned char dsksynch, unsigned char dsksyncl)
{
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

  printf("Loading sector track %d, sector %d\n", sector/11, sector%11);
  
  if(!data) {
    fseek(adf_fd, sector*512, SEEK_SET);
    if(fread(sector_buffer[track_sec], 1, 512, adf_fd) != 512) {  perror("read error"); return; }
  } else
    memcpy(sector_buffer[track_sec], data, 512);

  SendSector(sector_buffer[track_sec], track_sec, sector/11, 0x44, 0x89);

  // send GAP after last sector
  if(track_sec == 10)
    SendGap();
}

// The ram_test programs the hardware to sync onto 0x4489. This
// will result in the first 6 bytes not being written to ram
#define FDC_SKIP 6

#endif
 
// proceed simulation by one tick
void tick(int c) {
  static uint64_t ticks = 0;
  static int sector_tx = 0;
  static int sector_tx_cnt = 512;

  tb->clk = c;

  if(c && !tb->reset) {
    
    // check for power led
    static int pwr_led = -1;
    if(tb->pwr_led != pwr_led) {
      printf("%.3fms Power LED = %s\n", simulation_time*1000, tb->pwr_led?"ON":"OFF");
      pwr_led = tb->pwr_led;
    }
    
    // check for fdd led
    static int fdd_led = -1;
    if(tb->fdd_led != fdd_led) {
      printf("%.3fms FDD LED = %s\n", simulation_time*1000, tb->fdd_led?"ON":"OFF");
      fdd_led = tb->fdd_led;
    }

#ifdef FDC_TEST
    /* ----------------- sdc interface ---------------- */

    // send bytes into sdc buffer
    tb->sdc_byte_in_strobe = 0;
    static int sub_cnt = 0;
    if(sub_cnt++ == 8) {
      sub_cnt = 0;
      
      // without SD card emulation we drive the floppy's sector io directly
      tb->sdc_done = 0;
	
      // push requested sector data into core
      if(tb->sdc_busy) {
	if(sector_tx_cnt < 512) {
	  // printf("Send %d/%d\n", sector_tx, sector_tx_cnt);
	  
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

    if(tb->clk7n_en) {    
#ifdef FDC_RAM_TEST_VERIFY
      static int ram_cnt = 0;
      
      if(!tb->_ram_we && ((tb->ram_address<<1) >= 0x10000)) {
	int adr = (tb->ram_address <<1) - 0x10000 + FDC_SKIP;
	
       	ram_cnt++;
	// printf("Written: %d\n", ram_cnt);	

	// the track data should wrap when more than the a complete track is being read
	while(adr >= TRACK_SIZE) adr -= TRACK_SIZE;
	
	unsigned short mm_orig = track_buffer[adr+1] + 256*track_buffer[adr];
		printf("MFM WR %d (%d/%d) = %04x (%04x)\n", adr,
		       adr/SECTOR_SIZE, (adr%SECTOR_SIZE)/2, tb->ram_data, mm_orig);

	// verify with mfm data generated from the original
	// minimig firmware code
	if(tb->ram_data != mm_orig) {
	  tb->trigger = 1;
	  printf("MFM mismatch %d (sector %d/word %d) is %04x, expected %04x\n",
		 adr, adr/SECTOR_SIZE, (adr%SECTOR_SIZE)/2,
		 tb->ram_data, mm_orig);
	}

      }
#endif

      static int sdc_rd = -1;
      if(tb->sdc_rd != sdc_rd) {
	printf("%.3fms sdc_rd %d\n", simulation_time*1000, tb->sdc_rd);
	sdc_rd = tb->sdc_rd;
	
	if(tb->sdc_rd == 1) {
	  tb->sdc_busy = 1;
	  printf("%.3fms SD request, sector %d (tr %d, sd %d, sec %d)\n",
		 simulation_time*1000, tb->sdc_sector, tb->sdc_sector/22,
		 (tb->sdc_sector/11)&1, tb->sdc_sector%11);
	  
	  // this triggers two things:
	  // - the track is read into a track buffer using the minimig MFM encoder
	  // - the sectors are sent into Paula/Floppy as raw sectors
	  build_track_buffer(tb->sdc_sector, NULL);
	  sector_tx_cnt = 0;
	  sector_tx = tb->sdc_sector%11;
	}
      }
    }
#endif
    
    /* ----------------- simulate ram/kick ---------------- */

    // ram works on falling 7mhz edge
    if(tb->clk7n_en) {
      unsigned char *ram_b = (unsigned char*)(ram+tb->ram_address);
	
      if(!tb->_ram_oe) {
	// big edian read
	tb->ramdata_in = 256*ram_b[0] + ram_b[1];
	
	// printf("%.3fms MEM RD ADDR %08x = %04x\n", simulation_time*1000, tb->ram_address << 1, tb->ramdata_in);
      }
      if(!tb->_ram_we) {
	// printf("%.3fms MEM WR ADDR %08x = %04x\n", simulation_time*1000, tb->ram_address << 1, tb->ram_data);
	// exit(-1);
	// ram[tb->ram_address] = tb->ram_data;


	// TODO: check for corrent ble/bhe
	
	// big edian write
	if(!tb->_ram_bhe) ram_b[0] = tb->ram_data>>8;
	if(!tb->_ram_ble) ram_b[1] = tb->ram_data&0xff;
      }
    }

  }
  

  tb->eval();

#ifdef VIDEO
  if(c) capture_video();
#endif

  if(simulation_time == 0)
    ticks = GetTickCountMs();
  
  // after one simulated millisecond calculate real time */
  if(simulation_time >= 0.001 && ticks) {
    ticks = GetTickCountMs() - ticks;
    printf("Speed factor = %lu\n", ticks);
    ticks = 0;
  }
  
  // trace after
#ifdef TRACESTART
  if(simulation_time > TRACESTART) trace->dump(1000000000000 * simulation_time);
#endif
  simulation_time += TICKLEN;
}

int main(int argc, char **argv) {
  // Initialize Verilators variables
  Verilated::commandArgs(argc, argv);
  // Verilated::debug(1);
  Verilated::traceEverOn(true);
  trace = new VerilatedVcdC;
  trace->spTrace()->set_time_unit("1ns");
  trace->spTrace()->set_time_resolution("1ps");
  simulation_time = 0;
  
  load_kick();

#ifdef VIDEO
  init_video();
#endif

  // Create an instance of our module under test
  tb = new Vnanomig_tb;
  tb->trace(trace, 99);
  trace->open("nanomig.vcd");
  
#ifdef FDC_TEST
  // check for af image size and insert it
  adf_fd = fopen(FLOPPY_ADF, "rb");
  if(!adf_fd) { perror("open adf file"); return -1; }
  fseek(adf_fd, 0, SEEK_END);
  tb->sdc_img_size = ftello(adf_fd);
  tb->sdc_img_mounted = 0;
  tb->sdc_busy = 0;
 
  printf("%s image size %d\n", FLOPPY_ADF, tb->sdc_img_size);
#endif
  
  tb->reset = 1;
  for(int i=0;i<10;i++) {
    tick(1);
    tick(0);

#ifdef FDC_TEST
    // activate "mount" signal
    tb->sdc_img_mounted = (i>4 && i<8)?1:0;
#endif
  }
  
  tb->reset = 0;

  /* run for a while */
  while(
#ifdef TRACEEND
	simulation_time<TRACEEND &&
#endif
#ifdef VIDEO 
	!sdl_cancelled &&
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

#ifdef FDC_TEST
  if(adf_fd) fclose(adf_fd);
#endif
}
