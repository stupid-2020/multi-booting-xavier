#!/bin/bash
#
# SCRIPT: add_jetpack.sh
# AUTHOR: Wu (https://github.com/stupid-2020)
# DATE  : 07-MAR-2021
# NOTE  : Only on Jetson AGX Xavier
#

DATE=`date +"%Y%m%d-%H%M%S"`
SCRIPT_PATH=`realpath $0`
ROOT=`dirname $SCRIPT_PATH`
CUR_DIR=$PWD

show_usage() {
    echo "Usage: $0 jetpack_partition menu_label"
    echo "  example:      $0 /dev/nvme0n1p1 my_jetpack_44"
    exit
}

# Check arguments
if [[ "$#" < 2 ]]; then
    show_usage
fi

# Check user
if [[ "$EUID" -ne 0 ]]; then
    echo "This script must be run with root privileges"
    show_usage;
fi

# Check JetPack partition
PART_DEV=$1
PART_MOUNT="/tmp/_nvme"
RELEASE_FILE="$PART_MOUNT/etc/nv_tegra_release"
VERSION="FALSE"
if [[ -e "$1" ]]; then
    mkdir -p $PART_MOUNT
    mount $PART_DEV $PART_MOUNT
    if [[ -f $RELEASE_FILE ]]; then
       VERSION=`head -n 1 $RELEASE_FILE | cut -d',' -f2 | cut -d' ' -f3`
    fi
fi

# Convert the JetPack version
case $VERSION in
    5.1)
        VERSION="4.5"
	;;
    4.4)
        VERSION="4.4"
	;;
    3.1)
        VERSION="4.3"
	;;
    2.3)
        VERSION="4.2"
	;;
    *)
	echo "Revision: $VERSION is not supported"
	VERSION="FALSE"
	;;
esac

if [[ "$VERSION" == "FALSE" ]]; then
    # Cleanup
    umount -f -l $PART_MOUNT
    rmdir $PART_MOUNT

    echo "JetPack partition $PART_DEV not found or invalid"
    show_usage
fi

# Everything looks ok
# Mount
EMMC_DEV="/dev/mmcblk0p1"
EMMC_MOUNT="/tmp/_emmc"
mkdir -p $EMMC_MOUNT
mount $EMMC_DEV $EMMC_MOUNT

# Patch initrd if necessary
# - JetPack 4.5.1 fixed the regex pattern for rootdev,
#   no patching is required
INITRD="/boot/jp-$VERSION.initrd"
if [[ "$VERSION" == "4.5" ]]; then
    cp $PART_MOUNT/boot/initrd $EMMC_MOUNT/$INITRD
else
    $ROOT/patch_initrd.sh \
        $PART_MOUNT/boot/initrd $VERSION $EMMC_MOUNT/$INITRD
fi

# Copy Image and Image.sig
IMAGE="/boot/jp-$VERSION.Image"
IMAGE_SIG="/boot/jp-$VERSION.Image.sig"
cp $PART_MOUNT/boot/Image $EMMC_MOUNT/$IMAGE
cp $PART_MOUNT/boot/Image.sig $EMMC_MOUNT/$IMAGE_SIG

# Only for JetPack 4.2
SRC_DTB="/boot/tegra194-p2888-0001-p2822-0000.dtb"
DST_DTB="/boot/tegra194-p2888-0001-p2822-0000.jp-42.dtb"
if [[ "$VERSION" == "4.2" ]]; then
    cp $PART_MOUNT/$SRC_DTB $EMMC_MOUNT/$DST_DTB
fi

# Add entry to extlinux.conf
JETPACK_LABEL=$2
ROOTDEV=$PART_DEV
EXTLINUX_CONF=$EMMC_MOUNT/boot/extlinux/extlinux.conf
if [[ "$VERSION" == "4.2" ]]; then
    TEMPLATE="$ROOT/JetPack-4.2.menu.txt"
else
    TEMPLATE="$ROOT/JetPack-4.x.menu.txt"
fi
while IFS= read -r line
do
    newline=${line/"<JETPACK_LABEL>"/$JETPACK_LABEL}
    newline=${newline/"<ROOTDEV>"/$ROOTDEV}
    newline=${newline/"<VERSION>"/$VERSION}
    echo "$newline" >> $EXTLINUX_CONF
done < "$TEMPLATE"


# Cleanup
umount $EMMC_MOUNT
umount $PART_MOUNT
rmdir $EMMC_MOUNT
rmdir $PART_MOUNT

# Show the information
echo "rootdev: $PART_DEV"
echo "jetpack: $VERSION"
echo "label  : $JETPACK_LABEL"
echo ""
echo "Please update the default menu from extlinux.conf accordingly"

# Return to original working directory
cd $CUR_DIR
