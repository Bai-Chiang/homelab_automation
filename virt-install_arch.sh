#!/usr/bin/bash
# Install an Arch Linux virtual machine with given name/domain.
# No graphics only serial output.

virt-install \
    --name "$1" \
    --memory 2048 \
    --sysinfo host \
    --cpu host-passthrough,cache.mode=passthrough,topology.sockets=1,topology.cores=4,topology.threads=2 \
    --graphics none \
    --autoconsole text \
    --os-variant name='archlinux' \
    --cdrom "/tmp/archlinux-$(date +'%Y.%m.%d')-x86_64.iso" \
    --network network=default,model.type=virtio \
    --boot uefi \
    --disk path="/var/lib/libvirt/images/$1.qcow2",size=16,bus=virtio \
    --tpm default \

