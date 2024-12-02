---------------------------------------------------------------------------------
-- DE10_lite Top level for Solar Fox (Midway MCR) by Dar (darfpga@aol.fr) (19/10/2019)
-- http://darfpga.blogspot.fr
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
-- Use solarfox_de10_lite.sdc to compile (Timequest constraints)
-- /!\
-- Don't forget to set device configuration mode with memory initialization 
--  (Assignments/Device/Pin options/Configuration mode)
---------------------------------------------------------------------------------
--
-- release rev 01 : add TV 15kHz mode
--                  use merged sprite 8bits roms (make it easier to externalize)
--
-- release rev 00 : initial release
--
--
-- Main features :
--  PS2 keyboard input @gpio pins 35/34 (beware voltage translation/protection) 
--  Audio pwm output   @gpio pins 1/3 (beware voltage translation/protection) 
--
--  Video         : VGA 31Khz/60Hz and TV 15kHz
--  Cocktail mode : NO
--  Sound         : OK
-- 
-- For hardware schematic see my other project : NES
--
-- Uses 1 pll 40MHz from 50MHz to make 20MHz and 8Mhz 
--
-- Board key :
--   0 : reset game
--
-- Keyboard players inputs :
--
--   F1 : Add coin
--   F2 : Start 1 players / Fast 1
--   F5 : Separate audio
--   F7 : toggle service mode ON/OFF
--   F8 : toggle 15KHz/31kHz

--   RIGHT arrow : move right
--   LEFT  arrow : move left
--   UP    arrow : move up
--   DOWN  arrow : move down
--   SPACE       : fire        
--
-- Other details : see solar_fox.vhd
-- For USB inputs and SGT5000 audio output see my other project: xevious_de10_lite
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
-- gen_ram.vhd & io_ps2_keyboard
-------------------------------- 
-- Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
-- http://www.syntiac.com/fpga64.html
---------------------------------------------------------------------------------
-- T80/T80se - Version : 304
-----------------------------
-- Z80 compatible microprocessor core
-- Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
---------------------------------------------------------------------------------
-- YM2149 (AY-3-8910)
-- Copyright (c) MikeJ - Jan 2005
---------------------------------------------------------------------------------
-- Educational use only
-- Do not redistribute synthetized file with roms
-- Do not redistribute roms whatever the form
-- Use at your own risk
---------------------------------------------------------------------------------
--
-- release rev 01 : add TV 15kHz mode
--  (21/11/2019)    use merged sprite 8bits roms (make it easier to externalize)
--
-- release rev 00 : initial release
--
--
--  Features :
--   Video        : VGA 31Khz/60Hz and TV 15kHz
--   Coctail mode : NO
--   Sound        : OK

--  Use with MAME roms from solarfox.zip
--
--  Use make_solar_fox_proms.bat to build vhd file from binaries
--  (CRC list included)

--  Solar Fox (midway mcr) Hardware caracteristics :
--
--  VIDEO : 1xZ80@3MHz CPU accessing its program rom, working ram,
--    sprite data ram, I/O, sound board register and trigger.
--		  24Kx8bits program rom
--
--    One char/background tile map 30x32
--      2x4Kx8bits graphics rom 4bits/pixel
--      rbg programmable ram palette 16 colors 12bits : 4red 4green 4blue
--
--    128 sprites, up to ~15/line, 32x32 with flip H/V
--      4x4Kx8bits graphics rom 4bits/pixel
--      rbg programmable ram palette 16 colors 12bits : 4red 4green 4blue 
--
--    Working ram : 2Kx8bits
--    video (char/background) ram  : 1Kx8bits
--    Sprites ram : 512x8bits + 512x8bits cache buffer

--    Sprites line buffer rams : 1 scan line delay flip/flop 2x256x8bits
--
--  SOUND : see solarfox_sound_board.vhd

---------------------------------------------------------------------------------
--  Schematics remarks :
--
--		Display is 512x480 pixels  (video 635x525 lines @ 20MHz )

--       635/20e6  = 31.75us per line  (31.750KHz)
--       31.75*525 = 16.67ms per frame (59.99Hz)
--        
--    Original video is interlaced 240 display lines per 1/2 frame
--
--       H0 and V0 are not use for background => each bg tile is 16x16 pixel but 
--			background graphics is 2x2 pixels defintion.
--
--			Sprite are 32x32 pixels with 1x1 pixel definition, 16 lines for odd 1/2
--       frame and 16 lines for even 2/2 frame thanks to V8 on sprite rom ROMAD2
--       (look at 74ls86 G1 pin 9 on video genration board schematics)
--
--    *H and V stand for Horizontal en Vertical counter (Hcnt, Vcnt in VHDL code)
--
--    /!\ For VHDL port interlaced video mode is replaced with progressive video 
--        mode.
--
--    Sprite data are stored first by cpu into a 'cache' buffer (staging ram at
--    K6/L6) this buffer is read and write for cpu. After visible display, cache
--    buffer (512x8) is moved to actual sprite ram buffer (512x8). Actual sprite
--    buffer is access by transfer address counter during 2 scanlines after 
--    visible area and only by sprite machine during visible area.
--
--    Thus cpu can read and update sprites position during entire frame except
--    during 2 lines.
-- 
--    Sprite data are organised (as seen by cpu F000-F1FF) into 128 * 4bytes.
--    bytes #1 : Vertical position
--    bytes #2 : code and attribute
--    bytes #3 : Horizontal position
--    bytes #4 : not used
--
--		Athough 1x1 pixel defintion sprite position horizontal/vertical is made on
--    on a 2x2 grid (due to only 8bits for position data)
--
--    Z80-CTC : interruption ar managed by CTC chip. ONly channel 3 is trigered
--    by hardware signal line 493. channel 0 to 2 are in timer mode. Schematic 
--    show zc/to of channel 0 connected to clk/trg of channel 1. This seems to be
--    unsued for that (Kick) game. 
--
--     CPU programs 4 interuptions : (Vector D0)
--
--     IT ch 3 : triggered by line 493  : once per frame : start @00D8
--               set timer ch0 to launch interrupt around line 20
--               set timer ch1 to launch interrupt around line 240
--
--     IT ch 0 : triggered by timer ch 0  : once per frame : start @017E
--               stop timer 0
--
--     IT ch 1 : triggered by timer ch 1  : once per frame : start @0192
--               stop timer 1
--
--     IT ch 2 : trigged by timer ch 2 : once every ~105 scanlines : start @04E1
--               read angle decoder
--
--    Z80-CTC VHDL port keep separated interrupt controler and each counter so 
--    one can use them on its own. Priority daisy-chain is not done (not used in
--    that game). clock polarity selection is not done since it has no meaning
--    with digital clock/enable (e.g cpu_ena signal) method.
--
--    Angle (spin) decoder : Original design is a simple Up/Down 4 bits counter.
--    Replacement is proposed in kick_de10_lite.vhd as a 10bits counter allowing
--    more stable speed. It make use of CTC zc_to channel 2 signal to avoid
--    aliasing problems. Despite speed selection (faster/slower) is available 
--    from keyboard key it hardly simulate a real spinner.
--
--    Ressource : input clock 40MHz is chosen to allow easy making of 20MHz for
--    pixel clock and 8MHz signal for amplitude modulation circuit of ssio board
--    
--
--  TODO :
--    Working ram could be initialized to set initial difficulty level and
--    initial bases (live) number. Otherwise one can set it up by using service
--    menu at each power up.
--
---------------------------------------------------------------------------------
+----------------------------------------------------------------------------------+
; Fitter Summary                                                                   ;
+------------------------------------+---------------------------------------------+
; Fitter Status                      ; Successful - Fri Nov 22 07:30:28 2019       ;
; Quartus Prime Version              ; 18.1.0 Build 625 09/12/2018 SJ Lite Edition ;
; Revision Name                      ; kick_de10_lite                              ;
; Top-level Entity Name              ; solarfox_de10_lite                          ;
; Family                             ; MAX 10                                      ;
; Device                             ; 10M50DAF484C6GES                            ;
; Timing Models                      ; Preliminary                                 ;
; Total logic elements               ; 7,181 / 49,760 ( 14 % )                     ;
;     Total combinational functions  ; 6,794 / 49,760 ( 14 % )                     ;
;     Dedicated logic registers      ; 2,105 / 49,760 ( 4 % )                      ;
; Total registers                    ; 2105                                        ;
; Total pins                         ; 105 / 360 ( 29 % )                          ;
; Total virtual pins                 ; 0                                           ;
; Total memory bits                  ; 700,416 / 1,677,312 ( 42 % )                ;
; Embedded Multiplier 9-bit elements ; 0 / 288 ( 0 % )                             ;
; Total PLLs                         ; 1 / 4 ( 25 % )                              ;
; UFM blocks                         ; 0 / 1 ( 0 % )                               ;
; ADC blocks                         ; 0 / 2 ( 0 % )                               ;
+------------------------------------+---------------------------------------------+

---------------
VHDL File list 
---------------

de10_lite/max10_pll_40M.vhd        Pll 40MHz from 50MHz altera mf

rtl_dar/solarfox_de10_lite.vhd     Top level for de10_lite board
rtl_dar/solarfox.vhd               Main CPU and video boards logic
rtl_dar/solarfox_sound_board.vhd   Main sound board logic
rtl_dar/ctc_controler.vhd          Z80-CTC controler 
rtl_dar/ctc_counter.vhd            Z80-CTC counter

rtl_mikej/YM2149_linmix.vhd        Copyright (c) MikeJ - Jan 2005

rtl_T80_304/T80se.vhdT80               Copyright (c) 2001-2002 Daniel Wallner (jesus@opencores.org)
rtl_T80_304/T80_Reg.vhd
rtl_T80_304/T80_Pack.vhd
rtl_T80_304/T80_MCode.vhd
rtl_T80_304/T80_ALU.vhd
rtl_T80_304/T80.vhd

rtl_dar/kbd_joystick.vhd           Keyboard key to player/coin input
rtl_dar/io_ps2_keyboard.vhd        Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
rtl_dar/gen_ram.vhd                Generic RAM (Peter Wendrich + DAR Modification)
rtl_dar/decodeur_7_seg.vhd         7 segments display decoder

rtl_dar/proms/solar_fox_cpu.vhd         CPU board PROMS
rtl_dar/proms/solar_fox_bg_bits_2.vhd
rtl_dar/proms/solar_fox_bg_bits_1.vhd

rtl_dar/proms/solar_fox_sp_bits.vhd     Video board PROMS

rtl_dar/proms/solar_fox_sound_cpu.vhd   Sound board PROMS
rtl_dar/proms/midssio_82s123.vhd

----------------------
Quartus project files
----------------------
de10_lite/solarfox_de10_lite.sdc   Timequest constraints file
de10_lite/solarfox_de10_lite.qsf   de10_lite settings (files,pins...) 
de10_lite/solarfox_de10_lite.qpf   de10_lite project

-----------------------------
Required ROMs (Not included)
-----------------------------
You need the following 17 ROMs binary files from solarfox.zip and midssio.zip(MAME)

sfcpu.3b CRC 8c40f6eb
sfcpu.4b CRC 4d47bd7e
sfcpu.5b CRC b52c3bd5
sfcpu.4d CRC bd5d25ba
sfcpu.5d CRC dd57d817
sfcpu.6d CRC bd993cd9
sfcpu.7d CRC 8ad8731d

sfsnd.7a CRC cdecf83a
sfsnd.8a CRC cb7788cb
sfsnd.9a CRC 304896ce

sfcpu.4g CRC ba019a60
sfcpu.5g CRC 7ff0364e

sfvid.1a CRC 9d9b5d7e
sfvid.1b CRC 78801e83
sfvid.1d CRC 4d8445cf
sfvid.1e CRC 3da25495

midssio_82s123.12d CRC e1281ee9

------
Tools 
------
You need to build vhdl files from the binary file :
 - Unzip the roms file in the tools/solar__fox_unzip directory
 - Double click (execute) the script tools/make_solar_fox_proms.bat to get the following 9 files

solar_fox_cpu.vhd
solar_fox_bg_bits_2.vhd
solar_fox_bg_bits_1.vhd
solar_fox_sp_bits_.vhd
solar_fox_sound_cpu.vhd
midssio_82s123.vhd

*DO NOT REDISTRIBUTE THESE FILES*

VHDL files are needed to compile and include roms into the project 

The script make_kick_proms.bat uses make_vhdl_prom executables delivered both in linux and windows version. The script itself is delivered only in windows version (.bat) but should be easily ported to linux.

Source code of make_vhdl_prom.c is also delivered.

---------------------------------
Compiling for de10_lite
---------------------------------
You can build the project with ROM image embeded in the sof file.
*DO NOT REDISTRIBUTE THESE FILES*

3 steps

 - put the VHDL ROM files (.vhd) into the rtl_dar/proms directory
 - build solarfox_de10_lite
 - program solarfox_de10_lite.sof

------------------------
------------------------
End of file
------------------------
