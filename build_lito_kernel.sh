#!/bin/bash
set -e

# Available models
VALID_MODELS=("m23xq")

# Models that do support EUR region
EUR_MODELS=("m23xq")

# Available regions
VALID_REGIONS=("eur" "kor" "chn" "usa")

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

# Function to validate input
validate_choice() {
    local choice="$1"
    shift
    local valid_values=("$@")

    for value in "${valid_values[@]}"; do
        if [[ "$choice" == "$value" ]]; then
            return 0
        fi
    done

    return 1
}

# Model selection
prompt "Which project do you want to build?" "${VALID_MODELS[@]}"
read -p " - Enter your choice: " model_choice
model_choice=$(echo "$model_choice" | tr '[:upper:]' '[:lower:]')

if ! validate_choice "$model_choice" "${VALID_MODELS[@]}"; then
    echo "Invalid model choice! Exiting."
    exit 1
fi

# Region selection
#prompt "Which region do you want to build? (Leave empty for default config)" "${VALID_REGIONS[@]}"
#read -p " - Enter your choice: " region_choice
#region_choice=$(echo "$region_choice" | tr '[:upper:]' '[:lower:]')

#if [[ -n "$region_choice" && ! $(validate_choice "$region_choice" "${VALID_REGIONS[@]}") ]]; then
#    echo "Invalid region choice! Exiting."
#    exit 1
#fi

# Build paths. Must be defined before anything else
KERNEL_DIR=$(pwd)
KERNEL_OUT_DIR=$(pwd)/out

if [ ! -d "out" ]; then
    mkdir -p "out"
fi

# Target properties
MODEL=$model_choice
REGION=$region_choice
CHIPSET_NAME=lito
KERNEL_ARCH=arm64

# Lito platform now belongs to platform 11
export PROJECT_NAME="${MODEL}"
[ -z "${PLATFORM_VERSION}" ] && export PLATFORM_VERSION=11

# Target build parameters
KERNEL_DEFCONFIG="vendor/${CHIPSET_NAME}-perf_defconfig"

PROJECT_CONFIG="vendor/samsung/${MODEL}.config"

# Set toolchain and build environment
CLANG_PATH="${HOME}/linux-x86-main/clang-r563880"
GCC_PATH="${HOME}/aarch64-linux-android-4.9"
if [ ! -d "${CLANG_PATH}/bin" ] ; then
    echo "Error: AOSP toolchain directories not found. Exiting."
    exit 1
fi

# The GCC toolchain is only used for locating the aarch64 target triple and
# libgcc prefix (--target=/--prefix=), the actual compiler is clang.
PATH="${CLANG_PATH}/bin:${GCC_PATH}/bin:${PATH}"
KERNEL_LLVM_BIN="${CLANG_PATH}/bin/clang"

# Set kernel build environment variables
# CC=clang is required: the vendor Makefile otherwise wraps an empty
# REAL_CC in scripts/gcc-wrapper.py.
# CROSS_COMPILE is required: the vendor Makefile only passes --target= to
# clang when CROSS_COMPILE is set.
KERNEL_MAKE_PARAM="CC=clang LLVM_IAS=1 LLVM=1 CROSS_COMPILE=aarch64-linux-gnu- DTC_OVERLAY_TEST_EXT=$KERNEL_DIR/tools/ufdt_apply_overlay"

# Get number of CPU cores for parallel builds
BUILD_JOB_NUMBER=8

FUNC_BUILD_KERNEL() {
    local __dts_dir="${KERNEL_OUT_DIR}/arch/${KERNEL_ARCH}/boot/dts"

    echo ""
    echo "=============================================="
    echo "Build Info"
    echo "=============================================="
    echo "Project: $PROJECT_NAME"
    echo "Common config: $KERNEL_DEFCONFIG"
    echo "Project config: $PROJECT_CONFIG"
    echo "=============================================="
    echo ""

    # Using AOSP LLVM
    # Order matches LOS BoardConfigCommon + per-device BoardConfig:
    # base defconfig, shared samsung config, permissive, then per-device wins.
    make -C "$KERNEL_DIR" O="$KERNEL_OUT_DIR" $KERNEL_MAKE_PARAM ARCH="$KERNEL_ARCH" \
        $KERNEL_DEFCONFIG \
        "vendor/samsung/lito-sec-common.config" \
        $PROJECT_CONFIG

    # Resolve symbols missing from the fragment set without prompting
    make -C "$KERNEL_DIR" O="$KERNEL_OUT_DIR" $KERNEL_MAKE_PARAM ARCH="$KERNEL_ARCH" olddefconfig

    make -C "$KERNEL_DIR" O="$KERNEL_OUT_DIR" -j"$BUILD_JOB_NUMBER" $KERNEL_MAKE_PARAM ARCH="$KERNEL_ARCH"

    $(pwd)/tools/mkdtimg create $(pwd)/out/arch/arm64/boot/dtbo.img --page_size=4096 $(find out/arch/arm64/boot/dts/samsung/m23/m23xq/ -name *.dtbo)

    # Remove compiled DTBO's after every single compilation
    rm -rf "$__dts_dir/samsung/*"

    echo ""
    echo "================================="
    echo "Ending: FUNC_BUILD_KERNEL"
    echo "================================="
    echo ""
}

(
    FUNC_BUILD_KERNEL
)
