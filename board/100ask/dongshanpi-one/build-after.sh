#!/bin/sh
BOARD_DIR="$(dirname $0)"

# For debug
echo "Target binary dir $BOARD_DIR"

# Rename file name
cp $BINARIES_DIR/uImage.xz -rfvd  $BINARIES_DIR/kernel
cp $BINARIES_DIR/u-boot_spinand.xz.img.bin -rfvd  $BINARIES_DIR/uboot_s.bin

# Copy Files to BINARY
#cp $BOARD_DIR/pack_tools/* -rfvd  $BINARIES_DIR

# make sd emmc
$BOARD_DIR/pack_tools/make_sd_upgrade_sigmastar.sh  
