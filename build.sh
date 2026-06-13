#!/bin/bash

#
# Custom build script by Chatur27, Gabriel2392 and roynatech2544 @Github - 2022
#
# Modified by Mrsiri - 2026
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

DIRTY_BUILD=false

# Set default directories
ROOT_DIR=$(pwd)
KERNEL_DIR=$ROOT_DIR
DTBO_DIR=./arch/arm64/boot/dts/samsung/m23/m23xq

# Set default kernel variables
PROJECT_NAME="m23xq"

# Get date and time
DATE=$(date +"%m-%d-%y")
BUILD_START=$(date +"%s")

######################### Colours ############################

ON_BLUE=$(echo -e "\033[44m")
BLUE=$(echo -e "\033[1;34m")
GREEN=$(echo -e "\033[1;32m")
STD=$(echo -e "\033[0m")


####################### Devices List #########################

SM_M236B() {
	DEVICE_NAME="Samsung Galaxy M23/F23 5G"
	CODENAME=SM-M236B
}

################### Executable functions #######################

PRINT_BANNER() {
    echo " ${BLUE}"
    echo " __________                       __   ____  __.                         .__     "
    echo " \______   \ ____   ____  _______/  |_|    |/ _|___________  ____   ____ |  |    "
    echo "  |    |  _//  _ \ /  _ \/  ___/\   __\      <_/ __ \_  __ \/    \_/ __ \|  |    "
    echo "  |    |   (  <_> |  <_> )___ \  |  | |    |  \  ___/|  | \/   |  \  ___/|  |__  "
    echo "  |________/\____/ \____/______> |__| |____|___\_____>__|  |___|__/\_____>____/  "
    echo "                                                                                 "
    echo " "
}

DTBO_BUILD() {
	$(pwd)/tools/mkdtimg create $(pwd)/out/arch/arm64/boot/dtbo.img --page_size=4096 $(find out/arch/arm64/boot/dts/samsung/m23/m23xq/ -name *.dtbo)
}

CLANG_BUILD() {
	CLANG="${HOME}/linux-x86-main/clang-r487747c/bin"
	export CLANG_TRIPLE=aarch64-linux-gnu-
	export PATH="$CLANG:$PATH"
	make -j8 O=out ARCH=arm64 SUBARCH=arm64 CC=clang LLVM_IAS=1 LLVM=1 vendor/m23xq_eur_open_defconfig > /dev/null
	make -j8 O=out ARCH=arm64 SUBARCH=arm64 CC=clang LLVM_IAS=1 LLVM=1
}

DISPLAY_ELAPSED_TIME() {
	# Find out how much time build has taken
	BUILD_END=$(date +"%s")
	DIFF=$(($BUILD_END - $BUILD_START))

	BUILD_SUCCESS=$?
	if [ $BUILD_SUCCESS != 0 ]; then
		exit
	fi

	echo -e "                ${GREEN}Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds $reset ${STD}"
	sleep 1
}

BUILD_KERNEL() {
	SM_M236B
	sleep 0.3
    	PRINT_BANNER
	echo "                    BoostKernel for $DEVICE_NAME ${STD}                          "
	echo " "
	echo " "
	echo " "
	echo " "
	if [[ -e "out" ]]; then
 		while true; do
     			read -p "${BLUE}Do you wish to continue last build (Dirty build)? ${STD}" yn
     			case $yn in
         			[Yy]* ) DIRTY_BUILD=true; break ;;
         			[Nn]* ) DIRTY_BUILD=false; break ;;
         			* ) echo "Please choose Y or N." ;;
     			esac
 		done
 	fi
	if [[ "$DIRTY_BUILD" == "false" && -e "out" ]]; then
        	rm -rf out
    	fi
	echo " ${BLUE}"
	CLANG_BUILD
	echo " ${STD}"
	DTBO_BUILD
	echo " "
	PRINT_BANNER
	echo "${GREEN}                             Build Complete.                                 "
	echo " "
	DISPLAY_ELAPSED_TIME
}


###################### Script starts here #######################
BUILD_KERNEL
