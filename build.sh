SECONDS=0 # builtin bash timer

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

export ARCH=arm64
export PROJECT_NAME=m23xq
CLANG="${HOME}/linux-x86-main/clang-r563880/bin"
export PATH="$CLANG:$PATH"
export CLANG_TRIPLE=aarch64-linux-gnu-

git submodule update --init --recursive

mkdir -p out
make -j8 O=out ARCH=arm64 SUBARCH=arm64 CC=clang LLVM_IAS=1 LLVM=1 vendor/lito-perf_defconfig vendor/samsung/lito-sec-common.config vendor/samsung/m23xq.config
make -j8 O=out ARCH=arm64 SUBARCH=arm64 CC=clang LLVM_IAS=1 LLVM=1 olddefconfig

echo -e "\n${YELLOW}Starting compilation...${NC}\n"

make -j8 O=out ARCH=arm64 SUBARCH=arm64 CC=clang LLVM_IAS=1 LLVM=1

echo -e "\n${GREEN}Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s)!${NC}"