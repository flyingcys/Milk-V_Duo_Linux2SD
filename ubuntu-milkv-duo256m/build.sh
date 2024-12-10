#!/bin/bash

set -e

SPATH=$(dirname "$(realpath "$0")")

source $SPATH/ENV

if [ -z "$BOARD" ]; then
    echo "The BOARD variable is not set. Exiting..."
    exit 1
fi

if [ -z "$CONFIG" ]; then
    echo "The CONFIG variable is not set. Exiting..."
    exit 1
fi

echo "$BOARD $CONFIG"

cd /duo-buildroot-sdk

#Make sure we have room to work with

GENIMAGECFG="device/$BOARD/genimage.cfg"
cp "$GENIMAGECFG" "${GENIMAGECFG}.bak"
awk -v size="$ROOTFS_SIZE" '
BEGIN {OFS=FS=""}
/image rootfs.ext4/ {flag=1}
flag && /size =/ {sub(/[0-9]+[MG]/, size); flag=0}
{print}
' "${GENIMAGECFG}.bak" > "$GENIMAGECFG"

source device/$BOARD/boardconfig.sh
source build/milkvsetup.sh
defconfig $CONFIG

echo "Updating Kernel /duo-buildroot-sdk/build/boards/$CHIP_SEGMENT/$CONFIG/linux/*milkv*_defconfig"
cat /build/kernel.conf >> /duo-buildroot-sdk/build/boards/$CHIP_SEGMENT/$CONFIG/linux/*milkv*_defconfig

clean_all
build_all

ROOTFS=${OUTPUT_DIR}/rootfs-ubuntu
mkdir -p $ROOTFS 
 
# generate minimal bootstrap rootfs
update-binfmts --enable
debootstrap --exclude vim --arch=riscv64 --foreign jammy $ROOTFS http://mirrors.tuna.tsinghua.edu.cn/ubuntu-ports

cp -rf /usr/bin/qemu-riscv64-static $ROOTFS/usr/bin/
cp /bootstrap.sh $ROOTFS/.

# chroot into the rootfs we just created
echo "==========  CHROOT $ROOTFS =========="
chroot $ROOTFS /bin/bash /bootstrap.sh --second-stage --exclude vim
echo "========== EXIT CHROOT =========="

rm $ROOTFS/bootstrap.sh


if [ -L ${OUTPUT_DIR}/fs ]; then
  rm ${OUTPUT_DIR}/fs
fi

ln -s $ROOTFS ${OUTPUT_DIR}/fs
ln -s $ROOTFS ${OUTPUT_DIR}/br-rootfs
cd /duo-buildroot-sdk/install
/duo-buildroot-sdk/device/gen_burn_image_sd.sh $OUTPUT_DIR

