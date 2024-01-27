#!/usr/bin/bash
# Remove virtual mahine and its storage

virsh destroy "$1"
sleep 1
virsh undefine "$1" --nvram --storage "/var/lib/libvirt/images/$1.qcow2"
