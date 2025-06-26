#!/bin/bash

# Script to compile kernel, copy files, and update riscv.cfg configuration
# Usage: ./build_spec06.sh <kernel_type>
# Example: ./build_spec06.sh sanitiser
export MAKEFLAGS=-j$(nproc)
. ./env.sh

if [ $# -eq 0 ]; then
    echo "Usage: $0 <kernel_type>"
    echo "Available kernel types: none, pmc, perf, sanitiser, minesweeper, ss, ss_mc"
    exit 1
fi

KERNEL_TYPE=$1
# Since this script is now in spec06-benchmark directory, adjust paths accordingly
SPEC06_DIR="/home/zhejiang/FireGuard_V2/Software/linux/spec06/spec06-benchmark"
KERNELS_DIR="/home/zhejiang/FireGuard_V2/Software/linux/kernels"
CONFIG_FILE="$SPEC06_DIR/riscv.cfg"

echo "Building kernel type: $KERNEL_TYPE"

# Check if RISC-V compiler is available
if ! command -v riscv64-unknown-linux-gnu-gcc &> /dev/null; then
    echo "Error: RISC-V cross-compiler not found!"
    echo "Please install the RISC-V toolchain (riscv64-unknown-linux-gnu-gcc)"
    echo "You may need to:"
    echo "  1. Install the toolchain package"
    echo "  2. Add the toolchain to your PATH"
    echo "  3. Source the appropriate environment setup script"
    exit 1
fi

echo "RISC-V compiler found: $(which riscv64-unknown-linux-gnu-gcc)"

# Clean up previous builds
echo "Cleaning up previous builds..."

# Remove any existing .riscv files from spec06-benchmark directory
echo "Removing previous .riscv files from spec06-benchmark directory..."
rm -f "$SPEC06_DIR"/*.riscv

# Change to kernels directory for compilation
cd "$KERNELS_DIR" || {
    echo "Error: Cannot access kernels directory: $KERNELS_DIR"
    exit 1
}

# Clean previous builds in kernels directory
echo "Running make clean in kernels directory..."
make clean || {
    echo "Warning: make clean failed, but continuing..."
}

echo "Compiling initialisation_${KERNEL_TYPE}..."
make initialisation_${KERNEL_TYPE} || {
    echo "Error: Failed to compile initialisation_${KERNEL_TYPE}"
    exit 1
}

echo "Compiling gc_main_${KERNEL_TYPE}..."
make gc_main_${KERNEL_TYPE} || {
    echo "Error: Failed to compile gc_main_${KERNEL_TYPE}"
    exit 1
}

# Check if the compiled files exist
if [ ! -f "initialisation_${KERNEL_TYPE}.riscv" ]; then
    echo "Error: initialisation_${KERNEL_TYPE}.riscv not found"
    exit 1
fi

if [ ! -f "gc_main_${KERNEL_TYPE}.o" ]; then
    echo "Error: gc_main_${KERNEL_TYPE}.o not found"
    exit 1
fi

echo "Copying initialisation_${KERNEL_TYPE}.riscv to spec06-benchmark directory..."
cp "initialisation_${KERNEL_TYPE}.riscv" "$SPEC06_DIR/" || {
    echo "Error: Failed to copy initialisation_${KERNEL_TYPE}.riscv"
    exit 1
}

# Get the absolute path of the gc_main object file
GC_MAIN_PATH="$KERNELS_DIR/gc_main_${KERNEL_TYPE}.o"

echo "Updating riscv.cfg with correct paths..."

# Create a backup of the original config file
cp "$CONFIG_FILE" "$CONFIG_FILE.backup"

# Update the config file with the correct path for all optimization flags
sed -i "s|gc_main_[a-zA-Z_]*.o|gc_main_${KERNEL_TYPE}.o|g" "$CONFIG_FILE" || {
    echo "Error: Failed to update riscv.cfg"
    echo "Restoring backup..."
    mv "$CONFIG_FILE.backup" "$CONFIG_FILE"
    exit 1
}

cd "$SPEC06_DIR"

rm "$CONFIG_FILE.backup"

pwd

./gen_binaries.sh --compile --copy
mv initialisation_${KERNEL_TYPE}.riscv ./riscv-spec-ref/


echo "Successfully completed all tasks:"
echo "  - Compiled initialisation_${KERNEL_TYPE} and gc_main_${KERNEL_TYPE}"
echo "  - Copied initialisation_${KERNEL_TYPE}.riscv to $SPEC06_DIR"
echo "  - Updated riscv.cfg to use kernel type: ${KERNEL_TYPE}"
echo "  - Backup of original riscv.cfg saved as riscv.cfg.backup"

echo "Current optimization flags in riscv.cfg now point to:"
grep "OPTIMIZE.*=" "$CONFIG_FILE" | head -3 