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

# Set default directories
ROOT_DIR=$(pwd)
# OUT_DIR=$ROOT_DIR/out
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

ON_BLUE=`echo -e "\033[44m"`
RED=`echo -e "\033[1;31m"`
BLUE=`echo -e "\033[1;34m"`
GREEN=`echo -e "\033[1;32m"`
STD=`echo -e "\033[0m"`		# Clear colour


####################### Devices List #########################

SM_M236B() {
	DEVICE_NAME="Samsung Galaxy M23/F23 5G"
	CODENAME=SM-M236B/SM-E236B
	DEFCONFIG=vendor/m23xq_eur_open_defconfig
}

################### Executable functions #######################

CONTINUE() {
	SM_M236B
	sleep 0.3
    	echo " ${BLUE}"
	echo " __________                       __   ____  __.                         .__     "
	echo " \______   \ ____   ____  _______/  |_|    |/ _|___________  ____   ____ |  |    "
	echo "  |    |  _//  _ \ /  _ \/  ___/\   __\      <_/ __ \_  __ \/    \_/ __ \|  |    "
	echo "  |    |   (  <_> |  <_> )___ \  |  | |    |  \  ___/|  | \/   |  \  ___/|  |__  "
	echo "  |______  /\____/ \____/____  > |__| |____|__ \___  >__|  |___|  /\___  >____/  "
	echo "         \/                  \/               \/   \/           \/     \/        "
	echo " "
	echo "                      BoostKernel for $CODENAME ${STD}                           "
	echo " "
	echo " "
	echo " "
	echo " "
    read -p "${BLUE}Do you wish to continue last build (Dirty build)? (y/n)? " yn
    case $yn in
        [Yy]* )
	    if [ -e "out" ]; then
		echo -e "Building dirty..."
		export DIRTY_BUILD=1
            	CLANG="${HOME}/linux-x86-main/clang-r487747c/bin"
            	export CLANG_TRIPLE=aarch64-linux-gnu-
            	export PATH="$CLANG:$PATH"
            	make -j$CORES O=out ARCH=arm64 SUBARCH=arm64 CC=clang LLVM_IAS=1 LLVM=1 $DEFCONFIG > /dev/null
            	make -j$CORES O=out \
                	ARCH=arm64 \
                	SUBARCH=arm64 \
                	CC=clang \
                	LLVM_IAS=1 LLVM=1
		return 0
	    else
		echo "${RED}No /out folder found!" >&2
		return
	    fi
            ;;
        [Nn]* ) 
            echo "Building Clean..."
	    export DIRTY_BUILD=0
	    return
            ;;
        * ) 
            echo "Please choose Y or N."
            ;;
    esac
}

CLEAN_OUT() {
	echo " ${ON_BLUE}Cleaning kernel source ${STD}"
	echo " "

	rm -rf out
}

DTBO_BUILD() {
	$(pwd)/tools/mkdtimg create $(pwd)/out/arch/arm64/boot/dtbo.img --page_size=4096 $(find out/arch/arm64/boot/dts/samsung/m23/m23xq/ -name *.dtbo)
}

CLANG_BUILD() {
	CLANG="${HOME}/linux-x86-main/clang-r487747c/bin"
	export CLANG_TRIPLE=aarch64-linux-gnu-
	export PATH="$CLANG:$PATH"
	make -j$CORES O=out ARCH=arm64 SUBARCH=arm64 CC=clang LLVM_IAS=1 LLVM=1 $DEFCONFIG > /dev/null
	make -j$CORES O=out \
	ARCH=arm64 \
	SUBARCH=arm64 \
	CC=clang \
	LLVM_IAS=1 LLVM=1
}

USER() {
	# Setup KBUILD_BUILD_USER
	username="$(who | sed 's/  .*//' | head -1)"
	USER=${username^}
	echo " ${ON_BLUE}Current build_user is $USER ${STD}"
	echo " "

	export user=""

	if [ "${user}" == "" ]; then
		export KBUILD_BUILD_USER=$USER
		echo " "
		echo " Using '$USER' as build_user ${STD}"
	fi
	sleep 2
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

COMMON_STEPS() {
	clear
	echo " ${ON_BLUE}Starting compilation ${STD}"
	echo " "
	echo " ${GREEN}Defconfig loaded: $DEFCONFIG ${STD}"
	sleep 1
	echo " ${BLUE}"
	CLANG_BUILD
	echo " ${STD}"
	sleep 1
	DTBO_BUILD
	clear
	sleep 1
	echo " "
	echo " ${BLUE}"
	echo " __________                       __   ____  __.                         .__     "
	echo " \______   \ ____   ____  _______/  |_|    |/ _|___________  ____   ____ |  |    "
	echo "  |    |  _//  _ \ /  _ \/  ___/\   __\      <_/ __ \_  __ \/    \_/ __ \|  |    "
	echo "  |    |   (  <_> |  <_> )___ \  |  | |    |  \  ___/|  | \/   |  \  ___/|  |__  "
	echo "  |______  /\____/ \____/____  > |__| |____|__ \___  >__|  |___|  /\___  >____/  "
	echo "         \/                  \/               \/   \/           \/     \/        "
	echo " "
	echo "                                 Build Complete.                                 "
	echo " "
	DISPLAY_ELAPSED_TIME
}

BUILD_KERNEL() {
	clear
	CONTINUE
	sleep 1
	clear
	if [ "$DIRTY_BUILD" -eq 1 ]; then
        	echo "Skipping clear /out folder..."
    	else
        	CLEAN_OUT
    	fi
	sleep 1
	clear
	USER
	clear
	echo "*******************************************************"
	echo "*           Some informations about parameters set:	*"
	echo -e "* > Architecture: $ARCH				*"
	echo "*    > Num. Cores: $CORES					*"
	echo "*    > Build user: $KBUILD_BUILD_USER			*"
	echo "*    > Build machine: $KBUILD_BUILD_HOST			*"
	echo -e "*******************************************************"
	echo " "
	echo " ${STD}"
	echo " "
	COMMON_STEPS
}


###################### Script starts here #######################
BUILD_KERNEL
