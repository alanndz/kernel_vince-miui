#!/usr/bin/env bash
#
# Copyright (C) 2019 @alanndz (Telegram and Github)
# SPDX-License-Identifier: GPL-3.0-or-later
#
# build.sh <rel/fin for release build> <Kernel Version> <Codename>
# for testing just build.sh

BUILD_START=$(date +"%s")
DATE=`date`

install-package --update-new openssl ccache bc bash git-core gnupg build-essential \
	zip curl make automake autogen autoconf autotools-dev libtool shtool python \
	m4 gcc libtool zlib1g-dev flex

export KERNEL_NAME="aLn"
export KERNEL_VERSION="MIUI"
export CODENAME="OC"
export CONFIG_FILE="vince_defconfig"
# Build Release For fin for release and lol on testing
# Compiler
# 0 GCC 4.9
# 1 Linaro 4.9
# 2 Linaro 8.2.1
# 3 GCC 9.0.1
# 4 GCC 8.3.1
export COMP=1
if [[ "$1" == "rel" || "$1" == "fin" ]]; then
	export BREL=0
else
	export BREL=1
fi
if [[ "$2" ]]; then
	export KERNEL_VERSION="$2"
fi
if [[ "$3" ]]; then
	export CODENAME="$3"
fi
export KERNELDIR=$PWD
export TOOLDIR=$KERNELDIR/.ToolChain
export ZIP_DIR="${TOOLDIR}/AnyKernel2"
export OUTDIR="${KERNELDIR}/.Output"
export IMAGE="${OUTDIR}/arch/arm64/boot/Image.gz-dtb"
export BUILDLOG="${OUTDIR}/build-${KERNEL_VERSION}.log"

# Download TOOL
if [ ! -d "${ZIP_DIR}" ]; then
#  mkdir $ZIP_DIR
  git clone  https://github.com/alanndz/AnyKernel2 -b gcclang ${ZIP_DIR}
fi

if [ $COMP -eq 0 ]; then
	DIREX=${TOOLDIR}/gcc4.9
	git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 --depth=1 $DIREX
	CROSS_COMPILE+="ccache "
	CROSS_COMPILE+="$DIREX/bin/aarch64-linux-android-"
elif [ $COMP -eq 1 ]; then #Linaro 4.9
	DIREX=${TOOLDIR}/linaro4.9
	git clone https://github.com/ryan-andri/aarch64-linaro-linux-gnu-4.9 --depth=1 $DIREX
	CROSS_COMPILE+="ccache "
	CROSS_COMPILE+="$DIREX/bin/aarch64-linux-gnu-"
elif [ $COMP -eq 2 ]; then
	DIREX=${TOOLDIR}/linaro8
	git clone https://github.com/najahiiii/aarch64-linux-gnu -b linaro8-20190216 $DIREX
	CROSS_COMPILE+="$DIREX/bin/aarch64-linux-gnu-"
elif [ $COMP -eq 3 ]; then
	DIREX=${TOOLDIR}/GCC-9.0.1
	git clone https://github.com/VRanger/aarch64-linux-gnu -b gnu-9.x $DIREX
	CROSS_COMPILE+="$DIREX/bin/aarch64-linux-gnu-"
elif [ $COMP -eq 4 ]; then
	DIREX=${TOOLDIR}/gnu-8.3.1
	git clone https://github.com/VRanger/aarch64-linux-gnu -b gnu-8.x $DIREX
	CROSS_COMPILE+="$DIREX/bin/aarch64-linux-gnu-"
fi
 
# Export
export ARCH=arm64
export SUBARCH=arm64
export PATH=/usr/lib/ccache:$PATH
export CROSS_COMPILE
export KBUILD_BUILD_USER="alanndz"
export KBUILD_BUILD_HOST="N0t-n00b-dev"
 
export MODULEDIR="${ZIP_DIR}/modules/system/lib/modules/"
export PRONTO="${MODULEDIR}pronto/pronto_wlan.ko"
export STRIP="$DIREX/bin/$(echo "$(find "$DIREX/bin" -type f -name "aarch64-*-gcc")" | awk -F '/' '{print $NF}' |\
			sed -e 's/gcc/strip/')"
 
export BOT_API_KEY=$(openssl enc -base64 -d <<< Nzk5MDU4OTY3OkFBRlpjVEM5SU9lVEt4YkJucHVtWG02VHlUOTFzMzU5Y3VVCg==)
export CHAT_ID=$(openssl enc -base64 -d <<< LTEwMDEyMzAyMDQ5MjMK)
export BUILD_FAIL="CAADBQAD5xsAAsZRxhW0VwABTkXZ3wcC"
export BUILD_SUCCESS="CAADBQADJgADWtMDKHVGVS6aeEzlAg"
 
if [ $BREL -eq 0 ]; then
	if [ "${CODENAME}" ]; then
		export KVERSION="${KERNEL_VERSION}-${CODENAME}"
	else
		export KVERSION="${KERNEL_VERSION}"
	fi
	export ZIP_NAME="${KERNEL_NAME}-${KVERSION}-$(date "+%H%M-%d%m%Y").zip"
elif [ $BREL -eq 1 ]; then
	if [ "${CODENAME}" ]; then
		export KVERSION="${KERNEL_VERSION}-${CODENAME}-Testing"
	else
		export KVERSION="${KERNEL_VERSION}-Testing"
	fi 
	export ZIP_NAME="${KERNEL_NAME}-${KVERSION}-$(git log --pretty=format:'%h' -1)-$(date "+%H%M").zip"
fi
 
COMP_VERSION=$(${CROSS_COMPILE}gcc --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
 
JOBS="-j$(($(nproc --all) + 2))"
 
if [ ! -d "${BUILDLOG}" ]; then
 	rm -rf "${BUILDLOG}"
fi
 
function sendInfo() {
    curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendMessage -d text="${1}" -d chat_id=$CHAT_ID -d "parse_mode=HTML" &>/dev/null
}
 
function sendZip() {
	curl -F chat_id="$CHAT_ID" -F document=@"$ZIP_DIR/$ZIP_NAME" https://api.telegram.org/bot$BOT_API_KEY/sendDocument
}

function sendStick() {
	curl -s -X POST https://api.telegram.org/bot$BOT_API_KEY/sendSticker -d sticker="${1}" -d chat_id=$CHAT_ID &>/dev/null
}

function sendLog() {
	curl -F chat_id="671339354" -F document=@"$BUILDLOG" https://api.telegram.org/bot$BOT_API_KEY/sendDocument &>/dev/null
}
 
generate_config() {
	make O=${OUTDIR} $CONFIG_FILE savedefconfig
}
 
clean_outdir() {
    make O=${OUTDIR} clean
    make mrproper
    rm -rf ${OUTDIR}/*
}
 
simple_gcc() {
    make "${JOBS}" O=${OUTDIR} LOCALVERSION="-${KVERSION}"
}
 
compile_gcc() {
    make "${JOBS}" O=${OUTDIR} LOCALVERSION="-${KVERSION}" \
			CROSS_COMPILE="${CROSS_COMPILE}" \
			CC='ccache '${CROSS_COMPILE}gcc 
}

strip_module () {
	# thanks to @adekmaulana
	for MOD in $(find "${OUTDIR}" -name '*.ko') ; do
		"${STRIP}" --strip-unneeded --strip-debug "${MOD}" #&>/dev/null
		"${KERNELDIR}/"/scripts/sign-file sha512 \
				"${OUTDIR}/signing_key.priv" \
				"${OUTDIR}/signing_key.x509" \
				"${MOD}"
		find "${OUTDIR}" -name '*.ko' -exec cp {} "${MODULEDIR}" \;
		case ${MOD} in
			*/wlan.ko)
				cp -ar "${MOD}" "${PRONTO}"
		esac
	done
	echo -e "\n(i) Done moving modules"
}

make_zip () {
	if [ ! -f ${IMAGE} ]; then
        	echo -e "Build failed :P";
        	sendInfo "$(echo -e "Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")";
	        sendInfo "$(echo -e "Kernel compilation failed")";
			sendStick "${BUILD_FAIL}"
			sendLog
        	exit 1;
	fi
	echo "**** Copying zImage ****"
	cp ${IMAGE} ${ZIP_DIR}/zImage
	make ZIP="${ZIP_NAME}" normal &>/dev/null
}
 

 
sendInfo "$(echo -e "-- aLn New Kernel -- \nVersion: <code>${KVERSION} </code> \nKernel Version: <code>$(make kernelversion) </code> \nBranch: <code>$(git rev-parse --abbrev-ref HEAD) </code> \nCommit: <code>$(git log --pretty=format:'%h : %s' -1) </code> \nStarted on <code>$(hostname) </code> \nCompiler: <code>${COMP_VERSION} </code> \nStarted at $DATE")"
# sendInfo "$(echo -e "-- aLn New Kernel -- \nVersion: <code>${KVERSION} </code> \nBranch: <code>$(git rev-parse --abbrev-ref HEAD) </code> \nCommit: <code>$(git log --pretty=format:'%h : %s' -1) </code> \nStarted on <code>$(hostname) </code> \nCompiler: <code>${COMP_VERSION} </code> \nStarted at $DATE")"

clean_outdir
generate_config

#compile
if [[ $COMP -eq 0 || $COMP -eq 1 ]]; then
	simple_gcc 2>&1 | tee "${BUILDLOG}"
elif [[ $COMP -eq 2 || $COMP -eq 3 || $COMP -eq 4 ]]; then
	compile_gcc 2>&1 | tee "${BUILDLOG}"
fi

BUILD_END=$(date +"%s")
DIFF=$(($BUILD_END - $BUILD_START))

if [[ "${KERNEL_VERSION}" == "MIUI" ]]; then
	cd ${ZIP_DIR}/
	make clean &>/dev/null
	strip_module
	make_zip
	sendInfo "$(echo -e "NOTE!!! INSTALL on MIUI ROM")"
else
	cd ${ZIP_DIR}/
	make clean &>/dev/null
	make_zip
	sendInfo "$(echo -e "NOTE!!! INSTALL on CUSTOM ROM SUPPORT 4.9 KERNEL")"
fi

sendZip
sendLog
sendInfo "$(echo -e "Total time elapsed: $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) seconds.")"
sendStick "${BUILD_SUCCESS}"



