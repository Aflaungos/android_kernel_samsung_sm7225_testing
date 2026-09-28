SECONDS=0 # builtin bash timer

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CLANG="${HOME}/linux-x86-main/clang-r563880/bin"
DEFCONFIG="vendor/lito-perf_defconfig vendor/samsung/lito-sec-common.config vendor/samsung/m23xq.config"

OUT_DIR="$(pwd)/out"
BOOT_DIR="$OUT_DIR/arch/arm64/boot"
DTS_DIR="$BOOT_DIR/dts/vendor/qcom"

git submodule update --init --recursive

export PATH="$CLANG:$PATH"

mkdir -p out
echo -e "${YELLOW}building with: $DEFCONFIG${NC}"

make O=out ARCH=arm64 $DEFCONFIG
make O=out ARCH=arm64 olddefconfig

echo -e "\n${YELLOW}Starting compilation...${NC}\n"

make -j8 O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- LLVM=1 LLVM_IAS=1

echo -e "\n${GREEN}Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!${NC}"