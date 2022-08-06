#!/usr/bin/bash

VM_NAME=myvm
VM_SIZE=32
CPU_CORES=2
RAM_SIZE=4096
ISO=/path/to/linux.iso
SHARED_DIR=/path/to/src
MOUNT_TAG=mount-tag
NIC=eth0

# Create SHARE_DIR_SRC directory if not exist
mkdir -p ${SHARED_DIR}
chown libvirt-qemu:libvirt-qemu ${SHARED_DIR}
chmod 700 ${SHARED_DIR}

virt-install \
    --name ${VM_NAME} \
    --memory ${RAM_SIZE} \
    --memorybacking allocation.mode=ondemand \
    --cpu host-passthrough,cache.mode=passthrough,topology.sockets=1,topology.cores=${CPU_CORES},topology.threads=1 \
    --os-variant name=archlinux \
    --cdrom ${ISO} \
    --disk path=/var/lib/libvirt/images/${VM_NAME}.qcow2,size=${VM_SIZE},bus=virtio \
    --filesystem type=mount,accessmode=mapped,source.dir=${SHARED_DIR},target.dir=${MOUNT_TAG} \
    #--network bridge=br0,model.type=virtio \
    #--network none \
    --network type=direct,source=${NIC},source.mode=passthrough,model.type=virtio,trustGuestRxFilters=yes \
    --graphics none \
    --autoconsole text \
    --serial pty \
    --boot firmware=efi \
    --hostdev 02:00.0,type=pci \
    --hostdev 0x413c:0x2105,type=usb
