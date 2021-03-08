#!/bin/bash
#
# SCRIPT: patch_initrd.sh
# AUTHOR: Wu (https://github.com/stupid-2020)
# DATE  : 07-MAR-2021
# NOTE  : Only on Jetson AGX Xavier
#

DATE=`date +"%Y%m%d-%H%M%S"`
TMP_DIR="/tmp/_initrd.$DATE"
SCRIPT_PATH=`realpath $0`
ROOT=`dirname $SCRIPT_PATH`
CUR_DIR=$PWD

show_usage() {
    echo "Usage: $0 /path/to/initrd version [output]"
    echo "  version       should be 4.2, 4.3 or 4.4"
    echo "  output        optional (default: /tmp/JP4X.initrd)"
    exit
}

# Reading arguments
if [[ "$#" < 2 ]]; then
    show_usage
fi

INITRD=`realpath $1`
if [[ ! -f "$INITRD" ]]; then
    echo "Initial ramdisk file $INITRD not found."
    show_usage;
fi

case $2 in
    4.2)
        PATCH="JetPack-4.2.3.init.patch"
        ;;
    4.3)
        PATCH="JetPack-4.3.init.patch"
        ;;
    4.4)
        PATCH="JetPack-4.4.1.init.patch"
        ;;
    *)
        echo "Version $2 not supported"
        PATCH="JetPack-unknown.init.patch"
        ;;
esac

PATCH_FILE="$ROOT/$PATCH"
if [[ ! -f "$PATCH_FILE" ]]; then
    show_usage;
fi

if [[ "$3" == "" ]]; then
    OUTPUT="/tmp/JP4X.initrd"
else
    OUTPUT=`realpath $3`
fi


# Unpack
mkdir -p $TMP_DIR
cd $TMP_DIR
gzip -cd $INITRD | cpio -imd

# Patch (Back up the original)
patch -b < $PATCH_FILE
if [[ $? -eq 0 ]]; then
    # Pack
    find . -print0 | cpio --null --quiet -H newc -o | gzip -9 -n > $OUTPUT
    echo "Patch completed"
else
    echo "Patch failed"
fi

# Cleanup
rm -rf $TMP_DIR

# Show the information
echo "source: $INITRD"
echo "output: $OUTPUT"
echo "patch : $PATCH_FILE"

# Return to original working directory
cd $CUR_DIR
