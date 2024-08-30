#!/usr/bin/bash
# Remove virtual mahine and its storage

if [[ -z $1 ]] ; then
    echo "ERROR, please provide VM name/domain."
    echo "virsh_undefine.sh VM_name"
    exit 1
fi

virsh destroy "$1"
sleep 1
virsh undefine "$1" --nvram --storage "/var/lib/libvirt/images/$1.qcow2"
