#!/bin/sh
BOARD_DIR="$(dirname $0)"


# For debug
echo "Target binary dir $BOARD_DIR"

# Copy some system bins.
cp $BOARD_DIR/ssd202_bin/* -rfvd  $BINARIES_DIR

