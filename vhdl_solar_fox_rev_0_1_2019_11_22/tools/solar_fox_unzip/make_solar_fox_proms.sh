#copy /B sfcpu.3b + sfcpu.4b + sfcpu.5b + sfcpu.4d + sfcpu.5d + sfcpu.6d + sfcpu.7d solar_fox_cpu.bin
#make_vhdl_prom solar_fox_cpu.bin solar_fox_cpu.vhd
#
#copy /B sfsnd.7a + sfsnd.8a + sfsnd.9a solar_fox_sound_cpu.bin
#make_vhdl_prom solar_fox_sound_cpu.bin solar_fox_sound_cpu.vhd
#
#
#make_vhdl_prom sfcpu.4g solar_fox_bg_bits_1.vhd
#make_vhdl_prom sfcpu.5g solar_fox_bg_bits_2.vhd 
#
#rem make_vhdl_prom sfvid.1e solar_fox_sp_bits_1.vhd
#rem make_vhdl_prom sfvid.1d solar_fox_sp_bits_2.vhd
#rem make_vhdl_prom sfvid.1b solar_fox_sp_bits_3.vhd
#rem make_vhdl_prom sfvid.1a solar_fox_sp_bits_4.vhd
#
#copy /B sfvid.1a + sfvid.1b + sfvid.1d + sfvid.1e solar_fox_sp_bits.bin
#
#make_vhdl_prom solar_fox_sp_bits.bin solar_fox_sp_bits.vhd
#
#make_vhdl_prom midssio_82s123.12d midssio_82s123.vhd
#
#rem midssio_82s123.12d CRC e1281ee9
#
#rem sfcpu.3b CRC 8c40f6eb
#rem sfcpu.4b CRC 4d47bd7e
#rem sfcpu.5b CRC b52c3bd5
#rem sfcpu.4d CRC bd5d25ba
#rem sfcpu.5d CRC dd57d817
#rem sfcpu.6d CRC bd993cd9
#rem sfcpu.7d CRC 8ad8731d
#
#rem sfsnd.7a CRC cdecf83a
#rem sfsnd.8a CRC cb7788cb
#rem sfsnd.9a CRC 304896ce
#
#rem sfcpu.4g CRC ba019a60
#rem sfcpu.5g CRC 7ff0364e
#
#rem sfvid.1a CRC 9d9b5d7e
#rem sfvid.1b CRC 78801e83
#rem sfvid.1d CRC 4d8445cf
#rem sfvid.1e CRC 3da25495

cat sfcpu.3b sfcpu.4b sfcpu.5b sfcpu.4d sfcpu.5d sfcpu.6d sfcpu.7d > solar_fox_cpu.bin
./make_vhdl_prom solar_fox_cpu.bin solar_fox_cpu.vhd

cat sfsnd.7a sfsnd.8a sfsnd.9a > solar_fox_sound_cpu.bin
./make_vhdl_prom solar_fox_sound_cpu.bin solar_fox_sound_cpu.vhd

./make_vhdl_prom sfcpu.4g solar_fox_bg_bits_1.vhd
./make_vhdl_prom sfcpu.5g solar_fox_bg_bits_2.vhd 

#rem ./make_vhdl_prom sfvid.1e solar_fox_sp_bits_1.vhd
#rem ./make_vhdl_prom sfvid.1d solar_fox_sp_bits_2.vhd
#rem ./make_vhdl_prom sfvid.1b solar_fox_sp_bits_3.vhd
#rem ./make_vhdl_prom sfvid.1a solar_fox_sp_bits_4.vhd

cat sfvid.1a sfvid.1b sfvid.1d sfvid.1e > solar_fox_sp_bits.bin

./make_vhdl_prom solar_fox_sp_bits.bin solar_fox_sp_bits.vhd

./make_vhdl_prom 82s123.12d midssio_82s123.vhd

