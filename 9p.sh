#!/usr/bin/bash

echo '9pnet_virtio' > /etc/modules-load.d/9pnet_virtio.conf

MOUNT_TAG=" "
while [ -n "$MOUNT_TAG" ]; do
    read -p "Enter the mount tag for 9p shared directory. (empty to skipll): " MOUNT_TAG
    if [ -n "$MOUNT_TAG" ] ; then
        read -p "Enter the destination point : " DEST
        mkdir ${DEST}
	mount -t 9p -o trans=virtio,version=9p2000.L ${MOUNT_TAG} ${DEST}
        echo "$MOUNT_TAG  $DEST  9p  trans=virtio,version=9p2000.L  0 0"  >> /etc/fstab
        read -p "owner : " OWNER
        read -p "group : " GROUP
        chown ${OWNER}:${GROUP} ${DEST}
        read -p "mode : " MODE
        chmod ${MODE} ${DEST}
    fi
done


