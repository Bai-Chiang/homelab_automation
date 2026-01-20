#!/usr/bin/bash
# Install an Arch Linux virtual machine with given name/domain.
# No graphics only serial output.

if [[ -z $1 ]] ; then
    echo "ERROR, please provide VM name/domain."
    echo "virt-install_arch.sh VM_name"
    exit 1
fi

iso_uuid="$(blkid -s UUID -o value /tmp/archlinux-$(date +'%Y.%m.%d')-x86_64.iso)"

# --extra-args include all kernel parameters in
# loader/entries/01-archiso-linux.conf
# with additional console=ttyS0
virt-install \
    --name "$1" \
    --memory 2048 \
    --sysinfo host \
    --cpu host-passthrough,cache.mode=passthrough,topology.sockets=1,topology.cores=4,topology.threads=2 \
    --os-variant name='archlinux' \
    --graphics none \
    --autoconsole text \
    --location "/tmp/archlinux-$(date +'%Y.%m.%d')-x86_64.iso,kernel=arch/boot/x86_64/vmlinuz-linux,initrd=arch/boot/x86_64/initramfs-linux.img" \
    --extra-args "archisobasedir=arch archisosearchuuid=${iso_uuid} console=ttyS0" \
    --network network=default,model.type=virtio \
    --connect qemu:///system \
    --boot uefi \
    --disk path="/var/lib/libvirt/images/$1.qcow2",size=16,bus=virtio

