---------------------------------------------------------------------------------
-- Solar Fox by Dar (darfpga@aol.fr) (19/10/2019)
-- http://darfpga.blogspot.fr
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
--  (22/11/2019)    use merged sprite 8bits roms (make it easier to externalize)
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

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity solarfox is
port(
 clock_40     : in std_logic;
 reset        : in std_logic;
 tv15Khz_mode   : in std_logic;
 video_r        : out std_logic_vector(3 downto 0);
 video_g        : out std_logic_vector(3 downto 0);
 video_b        : out std_logic_vector(3 downto 0);
 video_clk      : out std_logic;
 video_csync    : out std_logic;
 video_blankn   : out std_logic;
 video_hs       : out std_logic;
 video_vs       : out std_logic;
 
 separate_audio : in  std_logic;
 audio_out_l    : out std_logic_vector(15 downto 0);
 audio_out_r    : out std_logic_vector(15 downto 0);
  
 coin1          : in std_logic;
 coin2          : in std_logic;
 fast1          : in std_logic;
 fast2          : in std_logic;
 fire1          : in std_logic;
 fire2          : in std_logic;
 up1            : in std_logic;
 down1          : in std_logic;
 left1          : in std_logic;
 right1         : in std_logic;
 up2            : in std_logic;
 down2          : in std_logic;
 left2          : in std_logic;
 right2         : in std_logic;

 service        : in std_logic;
  
 dbg_cpu_addr : out std_logic_vector(15 downto 0)
 );
end solarfox;

architecture struct of solarfox is

 signal reset_n   : std_logic;
 signal clock_vid : std_logic;
 signal clock_vidn: std_logic;
 signal clock_cnt : std_logic_vector(3 downto 0) := "0000";

 signal hcnt    : std_logic_vector(9 downto 0) := (others=>'0'); -- horizontal counter
 signal vcnt    : std_logic_vector(9 downto 0) := (others=>'0'); -- vertical counter
 signal vflip   : std_logic_vector(9 downto 0) := (others=>'0'); -- vertical counter flip
 
 signal hs_cnt, vs_cnt :std_logic_vector(9 downto 0) ;
 signal hsync0, hsync1, hsync2, hsync3, hsync4 : std_logic;
 signal top_frame : std_logic := '0';
 
 signal pix_ena     : std_logic;
 signal cpu_ena     : std_logic;

 signal cpu_addr    : std_logic_vector(15 downto 0);
 signal cpu_di      : std_logic_vector( 7 downto 0);
 signal cpu_do      : std_logic_vector( 7 downto 0);
 signal cpu_wr_n    : std_logic;
 signal cpu_rd_n    : std_logic;
 signal cpu_mreq_n  : std_logic;
 signal cpu_ioreq_n : std_logic;
 signal cpu_irq_n   : std_logic;
 signal cpu_m1_n    : std_logic;
 
 signal ctc_controler_we  : std_logic;
 signal ctc_controler_do  : std_logic_vector(7 downto 0);
 signal ctc_int_ack       : std_logic;

 signal ctc_counter_0_we  : std_logic;
-- signal ctc_counter_0_trg : std_logic;
 signal ctc_counter_0_do  : std_logic_vector(7 downto 0);
 signal ctc_counter_0_int : std_logic;

 signal ctc_counter_1_we  : std_logic;
-- signal ctc_counter_1_trg : std_logic;
 signal ctc_counter_1_do  : std_logic_vector(7 downto 0);
 signal ctc_counter_1_int : std_logic;
 
 signal ctc_counter_2_we  : std_logic;
-- signal ctc_counter_2_trg : std_logic;
 signal ctc_counter_2_do  : std_logic_vector(7 downto 0);
 signal ctc_counter_2_int : std_logic;
 
 signal ctc_counter_3_we  : std_logic;
 signal ctc_counter_3_trg : std_logic;
 signal ctc_counter_3_do  : std_logic_vector(7 downto 0);
 signal ctc_counter_3_int : std_logic;
 
 signal cpu_rom_do : std_logic_vector( 7 downto 0);
 
 signal wram_we    : std_logic;
 signal wram_do    : std_logic_vector( 7 downto 0);

 signal bg_ram_addr: std_logic_vector(9 downto 0);
 signal bg_ram_we  : std_logic;
 signal bg_ram_cpu_access  : std_logic;
 signal bg_ram_do  : std_logic_vector(7 downto 0);

 signal bg_code_line    : std_logic_vector(11 downto 0);
 signal bg_graphx1_do   : std_logic_vector(7 downto 0);
 signal bg_graphx2_do   : std_logic_vector(7 downto 0);
 signal bg_vid          : std_logic_vector(3 downto 0);
 signal bg_palette_addr : std_logic_vector(3 downto 0);
 
 signal sp_ram_cache_addr       : std_logic_vector(8 downto 0);
 signal sp_ram_cache_we         : std_logic;
 signal sp_ram_cache_cpu_access : std_logic;
 signal sp_ram_cache_do         : std_logic_vector(7 downto 0);
 
 signal move_buf          : std_logic;
 signal sp_ram_addr       : std_logic_vector(8 downto 0);
 signal sp_ram_we         : std_logic;
 signal sp_ram_do         : std_logic_vector(7 downto 0);

 signal sp_cnt          : std_logic_vector(6 downto 0);
 signal sp_code         : std_logic_vector( 7 downto 0);
 signal sp_input_phase  : std_logic_vector( 5 downto 0);

 signal sp_done         : std_logic;
 signal sp_vcnt         : std_logic_vector( 9 downto 0);
 signal sp_line         : std_logic_vector( 4 downto 0);
 signal sp_hcnt         : std_logic_vector( 8 downto 0); -- lsb used to mux rd/wr line buffer
 signal sp_on_line      : std_logic;
 signal sp_on_line_r    : std_logic;
 signal sp_byte_cnt     : std_logic_vector( 1 downto 0);
 signal sp_code_line    : std_logic_vector(12 downto 0);
 signal sp_code_line_mux: std_logic_vector(14 downto 0);
 signal sp_hflip        : std_logic_vector( 1 downto 0);
 signal sp_vflip        : std_logic_vector( 4 downto 0);
 
 signal sp_graphx_do    : std_logic_vector( 7 downto 0); 
 signal sp_mux_roms     : std_logic_vector( 1 downto 0);
 signal sp_graphx_flip  : std_logic_vector( 7 downto 0);
 
 signal sp_buffer_ram1_addr : std_logic_vector(7 downto 0);
 signal sp_buffer_ram1_we   : std_logic;
 signal sp_buffer_ram1_di   : std_logic_vector(7 downto 0);
 signal sp_buffer_ram1_do   : std_logic_vector(7 downto 0);
 signal sp_buffer_ram1_do_r : std_logic_vector(7 downto 0);
 
 signal sp_buffer_ram2_addr : std_logic_vector(7 downto 0);
 signal sp_buffer_ram2_we   : std_logic;
 signal sp_buffer_ram2_di   : std_logic_vector(7 downto 0);
 signal sp_buffer_ram2_do   : std_logic_vector(7 downto 0);
 signal sp_buffer_ram2_do_r : std_logic_vector(7 downto 0);
 
 signal sp_buffer_sel       : std_logic;
 
 signal sp_vid              : std_logic_vector(3 downto 0);
 
 signal palette_addr        : std_logic_vector(3 downto 0);
 signal palette_F4_we       : std_logic; 
 signal palette_F8_we       : std_logic;

 signal bg_palette_red_we   : std_logic;
 signal bg_palette_red_do   : std_logic_vector(3 downto 0);
 signal bg_palette_green_we : std_logic;
 signal bg_palette_green_do : std_logic_vector(3 downto 0);
 signal bg_palette_blue_we  : std_logic;
 signal bg_palette_blue_do  : std_logic_vector(3 downto 0);
 
 signal sp_palette_red_we   : std_logic;
 signal sp_palette_red_do   : std_logic_vector(3 downto 0);
 signal sp_palette_green_we : std_logic;
 signal sp_palette_green_do : std_logic_vector(3 downto 0);
 signal sp_palette_blue_we  : std_logic;
 signal sp_palette_blue_do  : std_logic_vector(3 downto 0);

 signal ssio_iowe    : std_logic;
 signal ssio_do      : std_logic_vector(7 downto 0);
 
 signal input_0       : std_logic_vector(7 downto 0);
 signal input_1       : std_logic_vector(7 downto 0);
 signal input_2       : std_logic_vector(7 downto 0);
 signal input_3       : std_logic_vector(7 downto 0);
 
begin

clock_vid  <= clock_40;
clock_vidn <= not clock_40;
reset_n    <= not reset;

-- debug 
process (reset, clock_vid)
begin
 if rising_edge(clock_vid) and cpu_ena ='1' and cpu_mreq_n ='0' then
   dbg_cpu_addr<= "000000000000000"&service; --cpu_addr;
 end if;
end process;

-- make enables clock from clock_vid
process (clock_vid, reset)
begin
	if reset='1' then
		clock_cnt <= (others=>'0');
	else 
		if rising_edge(clock_vid) then
			if clock_cnt = "1111" then  -- divide by 16
				clock_cnt <= (others=>'0');
			else
				clock_cnt <= clock_cnt + 1;
			end if;
		end if;
	end if;   		
end process;
--
cpu_ena <= '1' when clock_cnt = "1111" else '0'; -- (2.5MHz)
pix_ena <= '1' when (clock_cnt(1 downto 0) = "11" and tv15Khz_mode = '1') or         -- (10MHz)
						  (clock_cnt(0) = '1'           and tv15Khz_mode = '0') else '0';  -- (20MHz)

-----------------------------------
-- Video scanner  634x525 @20Mhz --
-- display 512x480               --
-----------------------------------
process (reset, clock_vid)
begin
	if reset='1' then
		hcnt  <= (others=>'0');
		vcnt  <= (others=>'0');
		top_frame <= '0';
	else 
		if rising_edge(clock_vid) then
			if pix_ena = '1' then
		
				hcnt <= hcnt + 1;
				if hcnt = 633 then
					hcnt <= (others=>'0');
					vcnt <= vcnt + 1;
					if (vcnt = 524 and tv15Khz_mode = '0') or (vcnt = 263 and tv15Khz_mode = '1') then
						vcnt <= (others=>'0');
						top_frame <= not top_frame;
					end if;
				end if;
			
				if tv15Khz_mode = '0' then 
							--	progessive mode
				
				if vcnt = 490-1 then video_vs <= '0'; end if; -- front porch 10
				if vcnt = 492-1 then video_vs <= '1'; end if; -- sync pulse   2
																			 -- back porch  33 
																		 
				if hcnt = 512+13-8 then video_hs <= '0'; end if;  -- front porch 16/25*20 = 13
				if hcnt = 512+90-8 then video_hs <= '1'; end if;  -- sync pulse  96/25*20 = 77
																				  -- back porch  48/25*20 = 38
				video_blankn <= '0';
				if hcnt >= 2 and  hcnt < 514 and
					vcnt >= 2 and  vcnt < 481 then video_blankn <= '1';end if;
				
				else    -- interlaced mode
				 
				if hcnt = 530 then 
					hs_cnt <= (others => '0');
					if (vcnt = 242) then
						vs_cnt <= (others => '0');
					else
						vs_cnt <= vs_cnt +1;
					end if;
				else 
					hs_cnt <= hs_cnt + 1;
				end if;
				
				video_blankn <= '0';				
				if hcnt >= 2 and  hcnt < 514 and
					vcnt >= 1 and  vcnt < 241 then video_blankn <= '1';end if;
				
				
				if    hs_cnt =  0 then hsync0 <= '0';
				elsif hs_cnt = 47 then hsync0 <= '1';
				end if;

				if    hs_cnt =      0  then hsync1 <= '0';
				elsif hs_cnt =     23  then hsync1 <= '1';
				elsif hs_cnt = 317+ 0  then hsync1 <= '0';
				elsif hs_cnt = 317+23  then hsync1 <= '1';
				end if;
		
				if    hs_cnt =      0  then hsync2 <= '0';
				elsif hs_cnt = 317-47  then hsync2 <= '1';
				elsif hs_cnt = 317     then hsync2 <= '0';
				elsif hs_cnt = 634-47  then hsync2 <= '1';
				end if;

				
				if    hs_cnt =      0  then hsync3 <= '0';
				elsif hs_cnt =     23  then hsync3 <= '1';
				elsif hs_cnt = 317     then hsync3 <= '0';
				elsif hs_cnt = 634-47  then hsync3 <= '1';
				end if;

				if    hs_cnt =      0  then hsync4 <= '0';
				elsif hs_cnt = 317-47  then hsync4 <= '1';
				elsif hs_cnt = 317     then hsync4 <= '0';
				elsif hs_cnt = 317+23  then hsync4 <= '1';
				end if;
				
				
				if     vs_cnt =  1 then video_csync <= hsync1;
				elsif  vs_cnt =  2 then video_csync <= hsync1;
				elsif  vs_cnt =  3 then video_csync <= hsync1;
				elsif  vs_cnt =  4 and top_frame = '1' then video_csync <= hsync3;
				elsif  vs_cnt =  4 and top_frame = '0' then video_csync <= hsync1;
				elsif  vs_cnt =  5 then video_csync <= hsync2;
				elsif  vs_cnt =  6 then video_csync <= hsync2;
				elsif  vs_cnt =  7 and  top_frame = '1' then video_csync <= hsync4;
				elsif  vs_cnt =  7 and  top_frame = '0' then video_csync <= hsync2;
				elsif  vs_cnt =  8 then video_csync <= hsync1;
				elsif  vs_cnt =  9 then video_csync <= hsync1;
				elsif  vs_cnt = 10 then video_csync <= hsync1;
				elsif  vs_cnt = 11 then video_csync <= hsync0;
				else                    video_csync <= hsync0;
				end if;
				
				
				end if;
				
			end if;
		end if;
	end if;
end process;

--------------------
-- players inputs --
--------------------
-- '1' for test & tilt  
input_0 <= not service & '1' &  '1' & not fire1 & not fast2 & not fast1 & not coin2 & not coin1;
input_1 <= not up2 & not down2 & not left2 & not right2 & not up1 & not down1 & not left1 & not right1; 
input_2 <= "1111111" & not fire2; 
input_3 <= x"FF";

------------------------------------------
-- cpu data input with address decoding --
------------------------------------------
cpu_di <= cpu_rom_do   		when cpu_mreq_n = '0' and cpu_addr(15 downto 12) < X"7" else      -- 0000-6FFF
			 wram_do     		when cpu_mreq_n = '0' and cpu_addr(15 downto 12) = X"7" else      -- 7000-7FFF
			 sp_ram_cache_do  when cpu_mreq_n = '0' and cpu_addr(15 downto  9) = "1111000" else -- sprite ram  0xF000-0xF1FF
			 bg_ram_do        when cpu_mreq_n = '0' and cpu_addr(15 downto 10) = "111111"  else -- video ram   0xFC00-0xFFFF
			 ctc_controler_do when cpu_ioreq_n = '0' and cpu_m1_n = '0'                    else -- ctc ctrl (interrupt vector)
			 ssio_do          when cpu_ioreq_n = '0' and cpu_addr(7 downto 4) = X"0"  else
 			 ctc_counter_3_do when cpu_ioreq_n = '0' and cpu_addr(7 downto 0) = X"F3" else
 			 ctc_counter_2_do when cpu_ioreq_n = '0' and cpu_addr(7 downto 0) = X"F2" else
 			 ctc_counter_1_do when cpu_ioreq_n = '0' and cpu_addr(7 downto 0) = X"F1" else
 			 ctc_counter_0_do when cpu_ioreq_n = '0' and cpu_addr(7 downto 0) = X"F0" else
   		 X"FF";
		 
------------------------------------------------------------------------
-- Misc registers : ctc write enable / interrupt acknowledge
------------------------------------------------------------------------
ctc_counter_3_trg <= '1' when (vcnt = 246 and tv15Khz_mode = '1') or (vcnt = 493 and tv15Khz_mode = '0')else '0';
ctc_counter_3_we  <= '1' when cpu_wr_n = '0' and cpu_ioreq_n = '0' and cpu_addr(7 downto 0) = X"F3" else '0';
ctc_counter_2_we  <= '1' when cpu_wr_n = '0' and cpu_ioreq_n = '0' and cpu_addr(7 downto 0) = X"F2" else '0';
ctc_counter_1_we  <= '1' when cpu_wr_n = '0' and cpu_ioreq_n = '0' and cpu_addr(7 downto 0) = X"F1" else '0';
ctc_counter_0_we  <= '1' when cpu_wr_n = '0' and cpu_ioreq_n = '0' and cpu_addr(7 downto 0) = X"F0" else '0';
ctc_controler_we  <= '1' when cpu_wr_n = '0' and cpu_ioreq_n = '0' and cpu_addr(7 downto 0) = X"F0" else '0'; -- only channel 0 receive int vector
ctc_int_ack       <= '1' when cpu_ioreq_n = '0' and cpu_m1_n = '0' else '0';

------------------------------------------
-- write enable / ram access from CPU --
------------------------------------------
wram_we                 <= '1' when cpu_mreq_n = '0' and cpu_wr_n = '0' and cpu_addr(15 downto 12) = X"7" else '0';
sp_ram_cache_we         <= '1' when cpu_mreq_n = '0' and cpu_wr_n = '0' and cpu_addr(15 downto  9) = "1111000" else '0';
bg_ram_we               <= '1' when cpu_mreq_n = '0' and cpu_wr_n = '0' and cpu_addr(15 downto 10) = "111111" else '0';
sp_ram_cache_cpu_access <= '1' when cpu_mreq_n = '0' and (cpu_wr_n = '0' or cpu_rd_n = '0') and cpu_addr(15 downto  9) = "1111000" else '0';
bg_ram_cpu_access       <= '1' when cpu_mreq_n = '0' and (cpu_wr_n = '0' or cpu_rd_n = '0') and cpu_addr(15 downto 10) = "111111" else '0';

ssio_iowe <= '1' when cpu_wr_n = '0' and cpu_ioreq_n = '0' else '0';

----------------------
--- sprite machine ---
----------------------

vflip <= (240-vcnt(8 downto 0)) & top_frame when tv15Khz_mode = '1' else 480-vcnt; -- apply mirror flip

sp_buffer_sel <= vflip(1) when tv15Khz_mode = '1' else vflip(0);

process (clock_vid)
begin
	if rising_edge(clock_vid) then
	
	if pix_ena = '1' then 
		if hcnt = 0 then
			sp_cnt <= (others => '0');
			sp_input_phase <= (others => '0');
			sp_on_line <= '0';
			sp_done <= '0';
		end if;
			
		if sp_done = '0' then
			sp_input_phase <= sp_input_phase + 1 ;
			sp_hcnt <= sp_hcnt + 1;
			case sp_input_phase is
				when "000000" => 
					if sp_vcnt(8 downto 5) = x"F" then
						sp_line <= sp_vcnt(4 downto 0);
					else
						sp_input_phase <= (others => '0');
						sp_cnt <= sp_cnt + 1;
						if sp_cnt = "1111111" then sp_done <= '1'; end if;
					end if;
					sp_byte_cnt <= (others => '0');
				when "000001" => 
					sp_code <= sp_ram_do;
				when "000010" => 
					sp_hcnt <= sp_ram_do & '0';
					sp_on_line <= '1';
				when "001001"|"010001"|"011001" => 
					sp_byte_cnt <= sp_byte_cnt + 1;
				when "100001" => 
					sp_on_line <= '0';
					sp_input_phase <= (others => '0');
					sp_cnt <= sp_cnt + 1;
					if sp_cnt = "1111111" then sp_done <= '1'; end if;
				when others =>
					null;
			end case;
			sp_mux_roms <= sp_input_phase(2 downto 1);
		end if;
		
		if hcnt(0) = '0' then
			sp_buffer_ram1_do_r <= sp_buffer_ram1_do;
			sp_buffer_ram2_do_r <= sp_buffer_ram2_do;
		end if;

	end if;

	end if;
end process;	

sp_ram_cache_addr <= cpu_addr(8 downto 0) when sp_ram_cache_cpu_access = '1' else sp_ram_addr;


move_buf    <= '1' when (vcnt(8 downto 1) = 250 and tv15Khz_mode = '0') or (vcnt(7 downto 1) = 125 and tv15Khz_mode = '1') else '0'; -- line 500-501

sp_ram_addr <= vcnt(0) & hcnt(8 downto 1) when move_buf = '1' else sp_cnt & sp_input_phase(1 downto 0);
sp_ram_we   <= hcnt(0) when move_buf = '1' else '0';

sp_vcnt <= vflip + (sp_ram_do & '0'); -- valid when sp_input_phase = 0

sp_hflip <= (others => sp_code(6));
sp_vflip <= (others => sp_code(7));

sp_code_line <= sp_code(5 downto 0) & (sp_line xor sp_vflip) & (sp_byte_cnt xor sp_hflip); -- sprite graphics roms addr

sp_code_line_mux <= "00" & sp_code_line when (sp_hflip(0) = '0' and sp_mux_roms = "01") or
												(sp_hflip(0) = '1' and sp_mux_roms = "00") else
					     "01" & sp_code_line when (sp_hflip(0) = '0' and sp_mux_roms = "10") or
												(sp_hflip(0) = '1' and sp_mux_roms = "11") else
					     "10" & sp_code_line when (sp_hflip(0) = '0' and sp_mux_roms = "11") or
												(sp_hflip(0) = '1' and sp_mux_roms = "10") else
					     "11" & sp_code_line when (sp_hflip(0) = '0' and sp_mux_roms = "00") or
												(sp_hflip(0) = '1' and sp_mux_roms = "01") ;
												
sp_graphx_flip <= sp_graphx_do when sp_hflip(0) = '0' else
						sp_graphx_do(3 downto 0) & sp_graphx_do(7 downto 4);		

sp_buffer_ram1_di   <= sp_buffer_ram1_do or sp_graphx_flip       when sp_buffer_sel = '1' else "00000000";
sp_buffer_ram1_addr <= sp_hcnt(8 downto 1)                       when sp_buffer_sel = '1' else hcnt(8 downto 1) - X"03";
sp_buffer_ram1_we   <= not sp_hcnt(0) and sp_on_line and pix_ena when sp_buffer_sel = '1' else hcnt(0);

sp_buffer_ram2_di   <= sp_buffer_ram2_do or sp_graphx_flip       when sp_buffer_sel = '0' else "00000000";
sp_buffer_ram2_addr <= sp_hcnt(8 downto 1)                       when sp_buffer_sel = '0' else hcnt(8 downto 1) - X"03";
sp_buffer_ram2_we   <= not sp_hcnt(0) and sp_on_line and pix_ena when sp_buffer_sel = '0' else hcnt(0);

sp_vid <= sp_buffer_ram1_do_r(7 downto 4) when (sp_buffer_sel = '0') and (hcnt(0) = '1') else
		    sp_buffer_ram1_do_r(3 downto 0) when (sp_buffer_sel = '0') and (hcnt(0) = '0') else
		    sp_buffer_ram2_do_r(7 downto 4) when (sp_buffer_sel = '1') and (hcnt(0) = '1') else
			 sp_buffer_ram2_do_r(3 downto 0) when (sp_buffer_sel = '1') and (hcnt(0) = '0');			  

--------------------
--- char machine ---
--------------------
bg_ram_addr <= cpu_addr(9 downto 0) when bg_ram_cpu_access = '1' else vflip(8 downto 4) & hcnt(8 downto 4);
bg_code_line <=  bg_ram_do & vflip(3 downto 1) & hcnt(3);

process (clock_vid)
begin
	if rising_edge(clock_vid) then
		
		if hcnt(0) = '1' then
			case hcnt(2 downto 1) is
				when "00"   => bg_palette_addr <= bg_graphx2_do(7 downto 6) & bg_graphx1_do(7 downto 6);
				when "01"   => bg_palette_addr <= bg_graphx2_do(5 downto 4) & bg_graphx1_do(5 downto 4);
				when "10"   => bg_palette_addr <= bg_graphx2_do(3 downto 2) & bg_graphx1_do(3 downto 2);
				when others => bg_palette_addr <= bg_graphx2_do(1 downto 0) & bg_graphx1_do(1 downto 0);
			end case;
		end if;

	end if;
end process;
	
bg_vid <= bg_palette_addr;
	
---------------------------
-- mux char/sprite video --
---------------------------
palette_F4_we <= '1' when cpu_mreq_n = '0' and cpu_wr_n = '0' and cpu_addr(15 downto 8) = X"F4" else '0'; -- 0xF400-F4FF
palette_F8_we <= '1' when cpu_mreq_n = '0' and cpu_wr_n = '0' and cpu_addr(15 downto 8) = X"F8" else '0'; -- 0xF800-F8FF

palette_addr <= cpu_addr(3 downto 0) when (palette_F4_we = '1' or palette_F8_we = '1') else bg_vid when sp_vid = "0000" else sp_vid;

bg_palette_red_we    <= '1' when palette_F8_we = '1' and cpu_addr(4) = '0' else '0'; -- 0xF800-0F d0-d3 (G11)
bg_palette_green_we  <= '1' when palette_F4_we = '1' and cpu_addr(4) = '0' else '0'; -- 0xF400-0F d0-d3 ( G9)
bg_palette_blue_we   <= '1' when palette_F4_we = '1' and cpu_addr(4) = '0' else '0'; -- 0xF400-0F d4-d7 (F11)

sp_palette_red_we    <= '1' when palette_F8_we = '1' and cpu_addr(4) = '1' else '0'; -- 0xF810-1F d0-d3 (G10)
sp_palette_green_we  <= '1' when palette_F4_we = '1' and cpu_addr(4) = '1' else '0'; -- 0xF410-1F d0-d3 ( G8)
sp_palette_blue_we   <= '1' when palette_F4_we = '1' and cpu_addr(4) = '1' else '0'; -- 0xF410-1F d4-d7 (F10)

process (clock_vid)
begin
	if rising_edge(clock_vid) then
		if sp_vid = "0000" then 
			video_r <= bg_palette_red_do;
			video_g <= bg_palette_green_do;
			video_b <= bg_palette_blue_do;
		else
			video_r <= sp_palette_red_do;
			video_g <= sp_palette_green_do;
			video_b <= sp_palette_blue_do;
		end if;
	end if;
end process;		
		
------------------------------
-- components & sound board --
------------------------------

-- microprocessor Z80
cpu : entity work.T80se
generic map(Mode => 0, T2Write => 1, IOWait => 1)
port map(
  RESET_n => reset_n,
  CLK_n   => clock_vid,
  CLKEN   => cpu_ena,
  WAIT_n  => '1',
  INT_n   => cpu_irq_n,
  NMI_n   => '1', --cpu_nmi_n,
  BUSRQ_n => '1',
  M1_n    => cpu_m1_n,
  MREQ_n  => cpu_mreq_n,
  IORQ_n  => cpu_ioreq_n,
  RD_n    => cpu_rd_n,
  WR_n    => cpu_wr_n,
  RFSH_n  => open,
  HALT_n  => open,
  BUSAK_n => open,
  A       => cpu_addr,
  DI      => cpu_di,
  DO      => cpu_do
);

-- CTC interrupt controler Z80-CTC (MK3882)
ctc_controler : entity work.ctc_controler
port map(
 clock     => clock_vid,
 clock_ena => cpu_ena,
 reset     => reset,
 
 d_in      => cpu_do,
 load_data => ctc_controler_we,
 int_ack   => ctc_int_ack,

 int_pulse_0 => ctc_counter_0_int,
 int_pulse_1 => ctc_counter_1_int,
 int_pulse_2 => ctc_counter_2_int,
 int_pulse_3 => ctc_counter_3_int,
 
 d_out     => ctc_controler_do,
 int_n     => cpu_irq_n
);

ctc_counter_0 : entity work.ctc_counter
port map(
 clock     => clock_vid,
 clock_ena => cpu_ena,
 reset     => reset,
 
 d_in      => cpu_do,
 load_data => ctc_counter_0_we,
 
 clk_trg   => '0',
 
 d_out     => ctc_counter_0_do,
 zc_to     => open, -- zc/to #0 (pin 7) connected to clk_trg #1 (pin 22) on schematics (seems to be not used)
 int_pulse => ctc_counter_0_int
 
);

ctc_counter_1 : entity work.ctc_counter
port map(
 clock     => clock_vid,
 clock_ena => cpu_ena,
 reset     => reset,
 
 d_in      => cpu_do,
 load_data => ctc_counter_1_we,
 
 clk_trg   => '0',
 
 d_out     => ctc_counter_1_do,
 zc_to     => open,
 int_pulse => ctc_counter_1_int
 
);

ctc_counter_2 : entity work.ctc_counter
port map(
 clock     => clock_vid,
 clock_ena => cpu_ena,
 reset     => reset,
 
 d_in      => cpu_do,
 load_data => ctc_counter_2_we,
 
 clk_trg   => '0',
 
 d_out     => ctc_counter_2_do,
 zc_to     => open,
 int_pulse => ctc_counter_2_int
 
);

ctc_counter_3 : entity work.ctc_counter
port map(
 clock     => clock_vid,
 clock_ena => cpu_ena,
 reset     => reset,
 
 d_in      => cpu_do,
 load_data => ctc_counter_3_we,
 
 clk_trg   => ctc_counter_3_trg,
 
 d_out     => ctc_counter_3_do,
 zc_to     => open,
 int_pulse => ctc_counter_3_int
 
);

-- cpu program ROM 0x0000-0x6FFF
rom_cpu : entity work.solar_fox_cpu
port map(
 clk  => clock_vidn,
 addr => cpu_addr(14 downto 0),
 data => cpu_rom_do
);

-- working RAM   0x7000-0x77FF
wram : entity work.cmos_ram
generic map( dWidth => 8, aWidth => 11)
port map(
 clk  => clock_vidn,
 we   => wram_we,
 addr => cpu_addr(10 downto 0),
 d    => cpu_do,
 q    => wram_do
);

-- video RAM   0xFC00-0xFFFF
video_ram : entity work.gen_ram
generic map( dWidth => 8, aWidth => 10)
port map(
 clk  => clock_vidn,
 we   => bg_ram_we,
 addr => bg_ram_addr,
 d    => cpu_do,
 q    => bg_ram_do
);

-- sprite RAM (no cpu access)
sprite_ram : entity work.gen_ram
generic map( dWidth => 8, aWidth => 9)
port map(
 clk  => clock_vidn,
 we   => sp_ram_we,
 addr => sp_ram_addr,
 d    => sp_ram_cache_do,
 q    => sp_ram_do
);

-- sprite RAM  0xF000-0xF1FF
sprites_ram_cache : entity work.gen_ram
generic map( dWidth => 8, aWidth => 9)
port map(
 clk  => clock_vidn,
 we   => sp_ram_cache_we,
 addr => sp_ram_cache_addr,
 d    => cpu_do,
 q    => sp_ram_cache_do
);

-- sprite line buffer 1
sprlinebuf1 : entity work.gen_ram
generic map( dWidth => 8, aWidth => 8)
port map(
 clk  => clock_vidn,
 we   => sp_buffer_ram1_we,
 addr => sp_buffer_ram1_addr,
 d    => sp_buffer_ram1_di,
 q    => sp_buffer_ram1_do
);

-- sprite line buffer 2
sprlinebuf2 : entity work.gen_ram
generic map( dWidth => 8, aWidth => 8)
port map(
 clk  => clock_vidn,
 we   => sp_buffer_ram2_we,
 addr => sp_buffer_ram2_addr,
 d    => sp_buffer_ram2_di,
 q    => sp_buffer_ram2_do
);

-- background graphics ROM G4
bg_graphics_1 : entity work.solar_fox_bg_bits_1
port map(
 clk  => clock_vidn,
 addr => bg_code_line,
 data => bg_graphx1_do
);

-- background graphics ROM G5
bg_graphics_2 : entity work.solar_fox_bg_bits_2
port map(
 clk  => clock_vidn,
 addr => bg_code_line,
 data => bg_graphx2_do
);

-- sprite graphics ROM 1A/1B/1D/1E
sprite_graphics : entity work.solar_fox_sp_bits
port map(
 clk  => clock_vidn,
 addr => sp_code_line_mux,
 data => sp_graphx_do
);

--kick_sound_board 
sound_board : entity work.solarfox_sound_board
port map(
 clock_40    => clock_40,
 reset       => reset,
 
 main_cpu_addr => cpu_addr(7 downto 0),
 
 ssio_iowe => ssio_iowe,
 ssio_di   => cpu_do,
 ssio_do   => ssio_do,
 
 input_0 => input_0,
 input_1 => input_1,
 input_2 => input_2,
 input_3 => input_3,
 
 separate_audio => separate_audio,
 audio_out_l    => audio_out_l,
 audio_out_r    => audio_out_r,
 
 dbg_cpu_addr => open --dbg_cpu_addr
);
 
-- background palette red
bg_palette_red : entity work.gen_ram
generic map( dWidth => 4, aWidth => 4)
port map(
 clk  => clock_vidn,
 we   => bg_palette_red_we,
 addr => palette_addr,
 d    => cpu_do(3 downto 0),
 q    => bg_palette_red_do
);

-- background palette green
bg_palette_green : entity work.gen_ram
generic map( dWidth => 4, aWidth => 4)
port map(
 clk  => clock_vidn,
 we   => bg_palette_green_we,
 addr => palette_addr,
 d    => cpu_do(3 downto 0),
 q    => bg_palette_green_do
);

-- background palette blue
bg_palette_blue : entity work.gen_ram
generic map( dWidth => 4, aWidth => 4)
port map(
 clk  => clock_vidn,
 we   => bg_palette_blue_we,
 addr => palette_addr,
 d    => cpu_do(7 downto 4),
 q    => bg_palette_blue_do
);

-- sprite palette red
bg_sprite_red : entity work.gen_ram
generic map( dWidth => 4, aWidth => 4)
port map(
 clk  => clock_vidn,
 we   => sp_palette_red_we,
 addr => palette_addr,
 d    => cpu_do(3 downto 0),
 q    => sp_palette_red_do
);

-- sprite palette green
bg_sprite_green : entity work.gen_ram
generic map( dWidth => 4, aWidth => 4)
port map(
 clk  => clock_vidn,
 we   => sp_palette_green_we,
 addr => palette_addr,
 d    => cpu_do(3 downto 0),
 q    => sp_palette_green_do
);

-- sprite palette blue
bg_sprite_blue : entity work.gen_ram
generic map( dWidth => 4, aWidth => 4)
port map(
 clk  => clock_vidn,
 we   => sp_palette_blue_we,
 addr => palette_addr,
 d    => cpu_do(7 downto 4),
 q    => sp_palette_blue_do
);

end struct;