#!/bin/bash
set -e

# Initialize Submodules if they're not initialized

if [ -f .gitmodules ]; then
  UNINITIALIZED_SUBMODULES=$(git submodule status | grep '^-' || true)

  if [ -n "$UNINITIALIZED_SUBMODULES" ]; then
    echo "The following submodules are missing or uninitialized:"
    echo "$UNINITIALIZED_SUBMODULES"
    echo "Initializing and cloning submodules..."
    git submodule update --init --recursive
    if [ $? -eq 0 ]; then
      echo "Submodules initialized and cloned successfully."
    else
      echo "Failed to clone submodules. Please check your repository configuration."
      exit 1
    fi
  else
    echo "All submodules are already initialized."
  fi
else
  echo "No submodules found in this repository."
fi

# Prompt function for cleaner code
prompt() {
    echo "=============================================="
    echo "$1"
    echo "=============================================="
    shift
    for option in "$@"; do
        echo "$option"
    done
    echo "=============================================="
}

# Build paths. Must be defined before anything else
PRODUCT_OUT=$(pwd)/out
KERNEL_DIR=$(pwd)
BUILD_ROOT_DIR=$KERNEL_DIR/..
KERNEL_OUT_DIR=$PRODUCT_OUT

CLANG_PATH="${HOME}/clang-r563880"
KERNEL_ARCH=arm64
PATH="${CLANG_PATH}/bin:${PATH}"
KERNEL_LLVM_BIN="${CLANG_PATH}/bin/clang"
KERNEL_MAKE_PARAM="LLVM=1 DTC_OVERLAY_TEST_EXT=$KERNEL_DIR/tools/ufdt_apply_overlay"
KERNEL_DEFCONFIG="vendor/m23xq_eur_open_defconfig"
BUILD_JOB_NUMBER=8

FUNC_BUILD_KERNEL() {
    local __dts_dir="${KERNEL_OUT_DIR}/arch/${KERNEL_ARCH}/boot/dts"

    echo ""
    echo "=============================================="
    echo "BUILDING KERNEL"
    echo "=============================================="
    echo ""

    # Using AOSP LLVM
    make -C "$KERNEL_DIR" O="$KERNEL_OUT_DIR" $KERNEL_MAKE_PARAM ARCH="$KERNEL_ARCH" \
        $KERNEL_DEFCONFIG \

    make -C "$KERNEL_DIR" O="$KERNEL_OUT_DIR" -j8 $KERNEL_MAKE_PARAM ARCH="$KERNEL_ARCH"

    echo ""
    echo "================================="
    echo "Finished BUILDING KERNEL"
    echo "================================="
    echo ""
}

(
    FUNC_BUILD_KERNEL
)
