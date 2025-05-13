#!/bin/sh

# The partition needs to be either unmounted or mounted read-only before we can
# "zerofree" it. Furthermore, the partition must be mounted when this script
# exits, as debos will want to unmount it and it will complain if it can't.

set -eu

lsblk --raw -no path,fstype,label $IMAGE | grep -w 'ext[2-4]' \
| while read -r blockdev fstype label; do
    echo "INFO: Zero free on $blockdev (label=$label, fs=$fstype)"
    mntpoint=$(findmnt -no target $blockdev)
    if [ "$mntpoint" ]; then
        mount -v -o remount,ro $blockdev
    fi
    zerofree -v $blockdev
done
