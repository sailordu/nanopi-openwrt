#!/bin/bash
set -eu

# Copyright (C) Guangzhou FriendlyARM Computer Tech. Co., Ltd.
# (http://www.friendlyarm.com)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, you can access it online at
# http://www.gnu.org/licenses/gpl-2.0.html.


true ${SOC:=rk3328}
true ${DISABLE_MKIMG:=0}
true ${LOGO:=}
true ${KERNEL_LOGO:=}

KERNEL_REPO=https://github.com/friendlyarm/kernel-rockchip
KERNEL_BRANCH=nanopi-r2-v5.4.y

declare -a KERNEL_3RD_DRIVERS=("https://github.com/friendlyarm/rtl8821CU" "https://github.com/friendlyarm/rtl8822bu" "https://github.com/sailordu/rtl8812au-1")
declare -a KERNEL_3RD_DRIVER_BRANCHES=("nanopi-r2" "nanopi-r2" "master")
declare -a KERNEL_3RD_DRIVER_NAME=("rtl8821CU" "rtl8822bu" "rtl8812au")

ARCH=arm64
KCFG=nanopi-r2_linux_defconfig
CROSS_COMPILE=aarch64-linux-gnu-

# 
# kernel logo:
# 
# convert logo.jpg -type truecolor /tmp/logo.bmp 
# convert logo.jpg -type truecolor /tmp/logo_kernel.bmp
# LOGO=/tmp/logo.bmp
# KERNEL_LOGO=/tmp/logo_kernel.bmp
#

TOPPATH=$PWD
OUT=$TOPPATH/out
if [ ! -d $OUT ]; then
	echo "path not found: $OUT"
	exit 1
fi
KMODULES_OUTDIR="${OUT}/output_${SOC}_kmodules"
true ${KERNEL_SRC:=${OUT}/kernel-${SOC}}

function usage() {
       echo "Usage: $0 <buildroot|friendlycore-arm64|friendlydesktop-arm64|lubuntu|friendlywrt|eflasher>"
       echo "# example:"
       echo "# clone kernel source from github:"
       echo "    git clone ${KERNEL_REPO} --depth 1 -b ${KERNEL_BRANCH} ${KERNEL_SRC}"
       echo "# or clone your local repo:"
       echo "    git clone git@192.168.1.2:/path/to/linux.git --depth 1 -b ${KERNEL_BRANCH} ${KERNEL_SRC}"
       echo "# then"
       echo "    convert files/logo.jpg -type truecolor /tmp/logo.bmp"
       echo "    convert files/logo.jpg -type truecolor /tmp/logo_kernel.bmp"
       echo "    LOGO=/tmp/logo.bmp KERNEL_LOGO=/tmp/logo_kernel.bmp ./build-kernel.sh eflasher"
       echo "    LOGO=/tmp/logo.bmp KERNEL_LOGO=/tmp/logo_kernel.bmp ./build-kernel.sh friendlycore-arm64"
       echo "    ./mk-emmc-image.sh friendlycore-arm64"
       echo "# also can do:"
       echo "    KERNEL_SRC=~/mykernel ./build-kernel.sh friendlycore-arm64"
       exit 0
}

if [ $# -ne 1 ]; then
    usage
fi

# ----------------------------------------------------------
# Get target OS
true ${TARGET_OS:=${1,,}}


case ${TARGET_OS} in
buildroot* | android7 | android8 | friendlycore* | friendlydesktop* | lubuntu* | friendlywrt | eflasher )
        ;;
*)
        echo "Error: Unsupported target OS: ${TARGET_OS}"
        exit 1
esac

download_img() {
    local RKPARAM=$(dirname $0)/${1}/parameter.txt
    local RKPARAM2=$(dirname $0)/${1}/param4sd.txt
    if [ -f "${RKPARAM}" -o -f "${RKPARAM2}" ]; then
	echo "${1} found."
    else
	ROMFILE=`./tools/get_pkg_filename.sh ${1}`
        cat << EOF
Warn: Image not found for ${1}
----------------
you may download them from the netdisk (dl.friendlyarm.com) to get a higher downloading speed,
the image files are stored in a directory called images-for-eflasher, for example:
    tar xvzf /path/to/NETDISK/images-for-eflasher/${ROMFILE}
----------------
Or, download from http (Y/N)?
EOF
        while read -r -n 1 -t 3600 -s USER_REPLY; do
            if [[ ${USER_REPLY} = [Nn] ]]; then
                echo ${USER_REPLY}
                exit 1
            elif [[ ${USER_REPLY} = [Yy] ]]; then
                echo ${USER_REPLY}
                break;
            fi
        done

        if [ -z ${USER_REPLY} ]; then
            echo "Cancelled."
            exit 1
        fi
        ./tools/get_rom.sh ${1} || exit 1
    fi
}

if [ ! -d ${KERNEL_SRC} ]; then
	git clone ${KERNEL_REPO} --depth 1 -b ${KERNEL_BRANCH} ${KERNEL_SRC}
fi

if [ ! -d /opt/FriendlyARM/toolchain/6.4-aarch64 ]; then
	echo "please install aarch64-gcc-6.4 first, using these commands: "
	echo "\tgit clone https://github.com/friendlyarm/prebuilts.git -b master --depth 1"
	echo "\tcd prebuilts/gcc-x64"
	echo "\tcat toolchain-6.4-aarch64.tar.gz* | sudo tar xz -C /"
	exit 1
fi

if [ -f "${LOGO}" ]; then
	cp -f ${LOGO} ${KERNEL_SRC}/logo.bmp
	echo "using ${LOGO} as logo."
else
	echo "using official logo."
fi

if [ -f "${KERNEL_LOGO}" ]; then
        cp -f ${KERNEL_LOGO} ${KERNEL_SRC}/logo_kernel.bmp
        echo "using ${KERNEL_LOGO} as kernel logo."
else
        echo "using official kernel logo."
fi

export PATH=/opt/FriendlyARM/toolchain/6.4-aarch64/bin/:$PATH

cd ${KERNEL_SRC}
make distclean
touch .scmversion
make CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH} ${KCFG}
if [ $? -ne 0 ]; then
	echo "failed to build kernel."
	exit 1
fi
if [ x"${TARGET_OS}" = x"eflasher" ]; then
    cp -avf .config .config.old
    sed -i "s/.*\(PROT_MT_SYNC\).*/CONFIG_TOUCHSCREEN_\1=y/g" .config
    sed -i "s/\(.*PROT_MT_SLOT\).*/# \1 is not set/g" .config
fi

make CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH} -j$(nproc)
if [ $? -ne 0 ]; then
        echo "failed to build kernel."
        exit 1
fi

rm -rf ${KMODULES_OUTDIR}
mkdir -p ${KMODULES_OUTDIR}
make CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH} INSTALL_MOD_PATH=${KMODULES_OUTDIR} modules -j$(nproc)
if [ $? -ne 0 ]; then
	echo "failed to build kernel modules."
        exit 1
fi
make CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH} INSTALL_MOD_PATH=${KMODULES_OUTDIR} modules_install INSTALL_MOD_STRIP=1
if [ $? -ne 0 ]; then
	echo "failed to build kernel modules."
        exit 1
fi

KERNEL_VER=`make CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH} kernelrelease`
for (( i=0; i<${#KERNEL_3RD_DRIVERS[@]}; i++ ));
do
	(cd ${OUT} && {
		if [ ! -d ${KERNEL_3RD_DRIVER_NAME[$i]} ]; then
			git clone ${KERNEL_3RD_DRIVERS[$i]} -b ${KERNEL_3RD_DRIVER_BRANCHES[$i]} ${KERNEL_3RD_DRIVER_NAME[$i]}
		else
			(cd ${KERNEL_3RD_DRIVER_NAME[$i]} && {
				make CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH} KSRC=${KERNEL_SRC} CONFIG_VENDOR_FRIENDLYARM=y clean
			})
		fi
		(cd ${KERNEL_3RD_DRIVER_NAME[$i]} && {
			make CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH} KSRC=${KERNEL_SRC} CONFIG_VENDOR_FRIENDLYARM=y -j$(nproc)
			if [ $? -ne 0 ]; then
				echo "failed to build 3rd kernel modules: ${KERNEL_3RD_DRIVER_NAME[$i]}"
				exit 1
			fi
			${CROSS_COMPILE}strip --strip-unneeded ${KERNEL_3RD_DRIVER_NAME[$i]}.ko
			cp ${KERNEL_3RD_DRIVER_NAME[$i]}.ko ${KMODULES_OUTDIR}/lib/modules/${KERNEL_VER} -afv
		})
	})

done

# wireguard
(cd ${OUT} && {
    if [ ! -d wireguard ]; then
        git clone https://git.zx2c4.com/wireguard-linux-compat -b master wireguard
        # old version# git clone https://git.zx2c4.com/wireguard-monolithic-historical -b master wireguard
    fi
    (cd wireguard/src && {
        make CROSS_COMPILE=${CROSS_COMPILE} ARCH=${ARCH} KERNELDIR=${KERNEL_SRC}
        ${CROSS_COMPILE}strip --strip-unneeded wireguard.ko
        cp wireguard.ko ${KMODULES_OUTDIR}/lib/modules/${KERNEL_VER} -afv
    })
})

if [ ! -d ${KMODULES_OUTDIR}/lib ]; then
	echo "not found kernel modules."
	exit 1
fi

if [ x"$DISABLE_MKIMG" = x"1" ]; then
    exit 0
fi

echo "building kernel ok."
if ! [ -x "$(command -v simg2img)" ]; then
    sudo apt update
    sudo apt install android-tools-fsutils
fi

cd ${TOPPATH}
download_img ${TARGET_OS}
./tools/update_kernel_bin_to_img.sh ${OUT} ${KERNEL_SRC} ${TARGET_OS} ${TOPPATH}/prebuilt


if [ $? -eq 0 ]; then
    echo "updating kernel ok."
else
    echo "failed."
    exit 1
fi
