#!/usr/bin/bash

# Build archlinux ISO file with optional extra kernel parameters.

# extra kernel command
KERNEL_CMD="console=ttyS0"

# create a temp directory in current directory
tempdir=$(mktemp -d --tmpdir=.)

# copy releng profile used in montly ISO relase
cp -r /usr/share/archiso/configs/releng/ "$tempdir/archlive"

# copy installation scripts to /root/
cp arch_install.sh           "$tempdir/archlive/airootfs/root/"
cp arch_install_bcachefs.sh  "$tempdir/archlive/airootfs/root/"
cp homed.sh                  "$tempdir/archlive/airootfs/root/"

# Add bcachefs packages
if [[ $(grep '^bcachefs-tools$' $tempdir/archlive/packages.x86_64 | wc -l) == 0 ]] ; then
    echo "bcachefs-tools" >> $tempdir/archlive/packages.x86_64
fi
if [[ $(grep '^bcachefs-dkms$' $tempdir/archlive/packages.x86_64 | wc -l) == 0 ]] ; then
    echo "bcachefs-dkms" >> $tempdir/archlive/packages.x86_64
fi
if [[ $(grep '^linux-headers$' $tempdir/archlive/packages.x86_64 | wc -l) == 0 ]] ; then
    echo "linux-headers" >> $tempdir/archlive/packages.x86_64
fi

if [[ -n "$KERNEL_CMD" ]] ; then
    # add kernel command to systemd-boot
    echo "options $KERNEL_CMD" >> "$tempdir/archlive/efiboot/loader/entries/01-archiso-x86_64-linux.conf"
    # add kernel command to grub
    sed -i "/\\s*linux.*archisodevice=UUID=\${ARCHISO_UUID}\$/ s|\$| $KERNEL_CMD|" "$tempdir/archlive/grub/grub.cfg"
fi

mkarchiso -v -w "$tempdir/work" -o /tmp  "$tempdir/archlive"

rm -r "$tempdir"
