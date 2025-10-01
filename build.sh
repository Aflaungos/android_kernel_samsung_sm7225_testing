#!/bin/bash

#
# Custom build script by Chatur27, Gabriel2392 and roynatech2544 @Github - 2022
#
# Modified by Mrsiri
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
CORES=$(nproc --all)

# Export commands
export KBUILD_BUILD_USER=Mrsiri
export KBUILD_BUILD_HOST=Mrsiri
export ARCH=arm64

# Get date and time
DATE=$(date +"%m-%d-%y")
BUILD_START=$(date +"%s")

######################### Colours ############################

ON_BLUE=$(echo -e "\033[44m")
RED=$(echo -e "\033[1;31m")
BLUE=$(echo -e "\033[1;34m")
GREEN=$(echo -e "\033[1;32m")
STD=$(echo -e "\033[0m")


####################### Devices List #########################

SM_M236B() {
	DEVICE_NAME="Samsung Galaxy M23/F23 5G"
	CODENAME=SM-M236B
	DEFCONFIG=vendor/m23xq_eur_open_defconfig
	DEFCONFIG_LINEAGE=vendor/lineage-m23xq_defconfig
}

################### Executable functions #######################

PRINT_BANNER() {
    echo " ${BLUE}"
    echo " __________                       __   ____  __.                         .__     "
    echo " \______   \ ____   ____  _______/  |_|    |/ _|___________  ____   ____ |  |    "
    echo "  |    |  _//  _ \ /  _ \/  ___/\   __\      <_/ __ \_  __ \/    \_/ __ \|  |    "
    echo "  |    |   (  <_> |  <_> )___ \  |  | |    |  \  ___/|  | \/   |  \  ___/|  |__  "
    echo "  |______  /\____/ \____/____  > |__| |____|__ \___  >__|  |___|  /\___  >____/  "
    echo "         \/                  \/               \/   \/           \/     \/        "
    echo " "
}

DTBO_BUILD() {
	$(pwd)/tools/mkdtimg create $(pwd)/out/arch/arm64/boot/dtbo.img --page_size=4096 $(find out/arch/arm64/boot/dts/samsung/m23/m23xq/ -name *.dtbo)
}

CLANG_BUILD() {
	CLANG="${HOME}/linux-x86-main/clang-r487747c/bin"
	export CLANG_TRIPLE=aarch64-linux-gnu-
	export PATH="$CLANG:$PATH"
	make -j$CORES O=out ARCH=arm64 SUBARCH=arm64 CC=clang LLVM_IAS=1 LLVM=1 $SELECTED_DEFCONFIG > /dev/null
	make -j$CORES O=out \
	ARCH=arm64 \
	SUBARCH=arm64 \
	CC=clang \
	LLVM_IAS=1 LLVM=1
}

DISPLAY_ELAPSED_TIME() {
	# Find out how much time build has taken
	BUILD_END=$(date +"%s")
	DIFF=$(($BUILD_END - $BUILD_START))

	BUILD_SUCCESS=$?
	if [ $BUILD_SUCCESS != 0 ]; then
		echo " ${RED}Error: Build failed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds $reset ${STD}"
		exit
	fi

	echo -e " ${GREEN}Build completed in $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds $reset ${STD}"
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
	while true; do
    		echo "Select ROM type:"
    		echo "  1) LineageOS"
    		echo "  2) Stock ROM"
    		read -p "Enter choice [1 or 2]: " choice
    		case $choice in
        		1 ) 
            		    SELECTED_DEFCONFIG=$DEFCONFIG_LINEAGE
            		    echo -e "${GREEN}You selected: LineageOS ($SELECTED_DEFCONFIG)${STD}"
            		    break 
            		    ;;
        		2 ) 
            		    SELECTED_DEFCONFIG=$DEFCONFIG
            		    echo -e "${GREEN}You selected: Stock ROM ($SELECTED_DEFCONFIG)${STD}"
            		    break 
            		    ;;
        		* ) echo "Please choose 1 or 2." ;;
	    	esac
	done
	if [[ -e "out" ]]; then
 		while true; do
     			read -p "${BLUE}Do you wish to continue last build (Dirty build)? (y/n)? ${STD}" yn
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
	echo "${GREEN}                        Build Complete.                                 "
	echo " "
	DISPLAY_ELAPSED_TIME
}


###################### Script starts here #######################
BUILD_KERNEL
