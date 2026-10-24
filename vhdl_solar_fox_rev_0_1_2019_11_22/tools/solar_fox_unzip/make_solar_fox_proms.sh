#!/bin/bash
# Port of make_solar_fox_proms.bat for the Basys3 build. Run from this
# directory (the unzipped solarfox.zip) by contrib/tools/roms.sh, which sets:
#   MAKE_VHDL_PROM  path of the compiled make_vhdl_prom
#   PROM_DIR        output directory for the PROM VHDL
# make_vhdl_prom names the entity after its output argument, so it runs inside
# PROM_DIR with bare output file names. The SSIO color PROM is read under its
# MAME name 82s123.12d (the .bat: midssio_82s123.12d, same CRC e1281ee9).

set -euo pipefail

: "${MAKE_VHDL_PROM:?}" "${PROM_DIR:?}"
roms="$(pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat sfcpu.3b sfcpu.4b sfcpu.5b sfcpu.4d sfcpu.5d sfcpu.6d sfcpu.7d > "$tmp/solar_fox_cpu.bin"
cat sfsnd.7a sfsnd.8a sfsnd.9a > "$tmp/solar_fox_sound_cpu.bin"
cat sfvid.1a sfvid.1b sfvid.1d sfvid.1e > "$tmp/solar_fox_sp_bits.bin"

cd "$PROM_DIR"
"$MAKE_VHDL_PROM" "$tmp/solar_fox_cpu.bin"       solar_fox_cpu.vhd
"$MAKE_VHDL_PROM" "$tmp/solar_fox_sound_cpu.bin" solar_fox_sound_cpu.vhd
"$MAKE_VHDL_PROM" "$roms/sfcpu.4g"               solar_fox_bg_bits_1.vhd
"$MAKE_VHDL_PROM" "$roms/sfcpu.5g"               solar_fox_bg_bits_2.vhd
"$MAKE_VHDL_PROM" "$tmp/solar_fox_sp_bits.bin"   solar_fox_sp_bits.vhd
"$MAKE_VHDL_PROM" "$roms/82s123.12d"             midssio_82s123.vhd
