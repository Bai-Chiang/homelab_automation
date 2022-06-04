#!/usr/bin/bash

UCODE_PKG="intel-ucode"
BASE_PKGS="base linux-firmware sudo python"
BTRFS_MOUNT_OPTS="ssd,noatime,compress=zstd:1,space_cache=v2,autodefrag"
TIMEZONE="US/Eastern"

# server example
KERNEL_PKGS="linux-hardened"
FS_PKGS="dosfstools btrfs-progs"
#OTHER_KERNEL_CMD="console=ttyS0"    # this kernel parameter force output to serial port, useful for libvirt virtual machine w/o any graphis.

# desktop example
#KERNEL_PKGS="linux linux-zen"
#FS_PKGS="dosfstools e2fsprogs btrfs-progs"
#OTHER_PKGS="man-db man-pages texinfo vim"
#OTHER_PKGS="$OTHER_PKGS git base-devel ansible"


######################################################

echo "

This is an Arch Linux installation script.
To activate it, press Enter, otherwise, press any other key.
If you activate it, you will be given a chance to install the glorious Arch Linux automatically.
However, there is no guarantee of success.
There is also no guarantee of your existing data safety.
"
read -p "Ready? " READY

if [ -n "$READY" ] ; then
    exit 1
fi


echo "
######################################################
# Verify the boot mode
# https://wiki.archlinux.org/title/Installation_guide#Verify_the_boot_mode
######################################################
"
if [ -e /sys/firmware/efi/efivars ] ; then
    echo "UEFI mode OK."
else
    echo "System not booted in UEFI mode!"
    exit 1
fi
echo -e "\n"
read -p "Do you want to set up secure boot using your own key? [Y/n] " IS_SECURE_BOOT
: "${IS_SECURE_BOOT:=y}"
IS_SECURE_BOOT="${IS_SECURE_BOOT,,}"
# check the firmware is in the setup mode
if [ "$IS_SECURE_BOOT" = y ] ; then
    SETUP_MODE=$(bootctl status | grep -E "Secure Boot.*setup" | wc -l)
    if [ "$SETUP_MODE" -ne 1 ] ; then
        echo "The firmware is not in the setup mode. Please check BIOS."
        read -p "Continue without secure boot? [y/N] " CONTINUE
        : "${CONTINUE:=n}"
        CONTINUE="${CONTINUE,,}"
        if [ "$CONTINUE" = y ] ; then
            IS_SECURE_BOOT="n"
        else
            exit 1
        fi
    fi
fi
            

echo "
######################################################
# Check internet connection
# https://wiki.archlinux.org/title/Installation_guide#Connect_to_the_internet
######################################################
"
ping -c 1 archlinux.org > /dev/null
if [ $? -ne 0 ] ; then
    echo "Please check the internet connection."
    exit 1
else
    echo "Internet OK."
fi


echo "
######################################################
# Update the system clock
# https://wiki.archlinux.org/title/Installation_guide#Update_the_system_clock
######################################################
"
timedatectl set-ntp true


echo "
######################################################
# Partition disks
# https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks
######################################################
"
DEVICES=$(lsblk --nodeps --paths --list --noheadings --sort=size --output=name,size,model | grep --invert-match "loop" | cat --number)

DEVICE_ID=" "
while [ -n "$DEVICE_ID" ]; do
    echo -e "Choose device to format:"
    echo "$DEVICES"
    read -p "Enter a number (empty to skip): " DEVICE_ID
    if [ -n "$DEVICE_ID" ] ; then
        DEVICE=$(echo "$DEVICES" | awk "\$1 == $DEVICE_ID { print \$2}")
        fdisk "$DEVICE"
    fi
done
PARTITIONS=$(lsblk --paths --list --noheadings --output=name,size,model | cat --number)

# boot partition
echo -e "\n\nTell me the boot partition number:"
echo "$PARTITIONS"
read -p "Enter a number: " BOOT_ID
BOOT_PART=$(echo "$PARTITIONS" | awk "\$1 == $BOOT_ID { print \$2}")

# root partition
echo -e "\n\nTell me the root partition number:"
echo "$PARTITIONS"
read -p "Enter a number: " ROOT_ID
ROOT_PART=$(echo "$PARTITIONS" | awk "\$1 == $ROOT_ID { print \$2}")
# Wipe existing LUKS header
cryptsetup erase $ROOT_PART 2> /dev/null
cryptsetup luksDump $ROOT_PART 2> /dev/null
wipefs --all $ROOT_PART 2> /dev/null

# swap partition
# swap is important, see [In defence of swap](https://chrisdown.name/2018/01/02/in-defence-of-swap.html)
echo -e "\n\nTell me the swap partition number:"
echo "$PARTITIONS"
read -p "Enter a number: " SWAP_ID
SWAP_PART=$(echo "$PARTITIONS" | awk "\$1 == $SWAP_ID { print \$2}") || SWAP_PART=""
# Wipe existing LUKS header
cryptsetup erase $SWAP_PART 2> /dev/null
cryptsetup luksDump $SWAP_PART 2> /dev/null
wipefs --all $SWAP_PART 2> /dev/null


echo "
######################################################
# Format the partitions
# https://wiki.archlinux.org/title/Installation_guide#Format_the_partitions
######################################################
"
# EFI partition
echo "Formatting EFI partition ..."
echo "Running command: mkfs.fat -n boot -F 32 $BOOT_PART"
mkfs.fat -n boot -F 32 "$BOOT_PART"

# swap partition
echo "Formatting swap partition ..."
echo "Running command: mkswap -L swap $SWAP_PART"
mkswap -L swap "$SWAP_PART"


echo "
######################################################
# Encrypt the root partion
# https://wiki.archlinux.org/title/Dm-crypt/Device_encryption
######################################################
"
read -p "Do you want to encrypt the root partition? [Y/n] " IS_ENCRYPT
: "${IS_ENCRYPT:=y}"
IS_ENCRYPT="${IS_ENCRYPT,,}"
if [ "$IS_ENCRYPT" = y ] ; then
    echo -e "\nDo you want to create a key file on the boot partition to automatically unlock the root partition on boot?\nThis could be used with the setup that the boot partition on an external flash drive, such that the system could autounlock on boot. But without the flash drive the system cannot boot and root partition is encrypted. It's not recommended if both boot and root partition on the same device, it would make the encryption meanless. Since the key file is on the unencrypted boot partition, anyone could easily the key file and decrypt the root partition.\nIf choose n then it will ask you for a encryption password."
    read -p "[y/N] " IS_CRYPTKEY
    : "${IS_CRYPTKEY:=n}"
    IS_CRYPTKEY="${IS_CRYPTKEY,,}"
    if [ "$IS_CRYPTKEY" != y ] ; then
        # passphrase
        echo -e "\nRunning cryptsetup ..."
        cryptsetup --type luks2 --verify-passphrase --sector-size 4096 --verbose luksFormat "$ROOT_PART"
        cryptsetup open "$ROOT_PART" cryptroot
    else
        # create keyfile
        echo -e "\nCreating keyfile ..."
        mount "$BOOT_PART" /mnt
        dd bs=512 count=4 if=/dev/random of=/mnt/rootkeyfile iflag=fullblock
        chmod 600 /mnt/rootkeyfile
        echo -e "\nRunning cryptsetup ..."
        cryptsetup --type luks2 --verify-passphrase --sector-size=4096 --key-file=/mnt/rootkeyfile --verbose luksFormat "$ROOT_PART"
        cryptsetup open "$ROOT_PART" cryptroot --key-file /mnt/rootkeyfile
        umount "$BOOT_PART"
    fi
    ROOT_DEV=$ROOT_PART
    ROOT_PART=/dev/mapper/cryptroot
else
    ROOT_DEV=$ROOT_PART
fi


# format root partition
echo -e "\n\nFormatting root partition ..."
echo "Running command: mkfs.btrfs -L ArchLinux -f $ROOT_PART"
mkfs.btrfs -L ArchLinux -f "$ROOT_PART"
# create subvlumes
echo "Creating btrfs subvolumes ..."
mount "$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@pacman_pkgs
mkdir /mnt/@/{boot,home,.snapshots}
mkdir -p /mnt/@/var/log
mkdir -p /mnt/@/var/cache/pacman/pkg
umount "$ROOT_PART"

# mount all partitions
echo -e "\nMounting all partitions ..."
mount -o "$BTRFS_MOUNT_OPTS",subvol=@ "$ROOT_PART" /mnt
mount -o "$BTRFS_MOUNT_OPTS",subvol=@home "$ROOT_PART" /mnt/home
mount -o "$BTRFS_MOUNT_OPTS",subvol=@snapshots "$ROOT_PART" /mnt/.snapshots
mount -o "$BTRFS_MOUNT_OPTS",subvol=@var_log "$ROOT_PART" /mnt/var/log
mount -o "$BTRFS_MOUNT_OPTS",subvol=@pacman_pkgs "$ROOT_PART" /mnt/var/cache/pacman/pkg
mount "$BOOT_PART" /mnt/boot

swapon "$SWAP_PART"

echo "
######################################################
# Install packages
# https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages
######################################################
"
pacstrap /mnt $BASE_PKGS $KERNEL_PKGS $FS_PKGS $UCODE_PKG $OTHER_PKGS


echo "
######################################################
# Generate fstab
# https://wiki.archlinux.org/title/Installation_guide#Fstab
######################################################
"
echo -e "Generating fstab ..."
genfstab -U /mnt >> /mnt/etc/fstab
echo "Removing subvolid entry in fstab ..."
sed -i 's/subvolid=[0-9]*,//g' /mnt/etc/fstab

echo "
######################################################
# 9p shared directories
# https://wiki.archlinux.org/title/libvirt#9p
######################################################
"
MOUNT_TAG_9P=" "
while [ -n "$MOUNT_TAG_9P" ]; do
    echo -e "\n"
    read -p "Enter the mount tag for 9p shared directory. (empty to skipll): " MOUNT_TAG_9P
    if [ -n "$MOUNT_TAG_9P" ] ; then
        read -p "Enter the destination point : " DEST_9P
        arch-chroot /mnt mkdir ${DEST_9P}
        echo "$MOUNT_TAG_9P  $DEST_9P  9p  trans=virtio,version=9p2000.L  0 0"  >> /mnt/etc/fstab
        read -p "owner : " OWNER_9P
        read -p "group : " GROUP_9P
        arch-chroot /mnt chown ${OWNER_9P}:${GROUP_9P} ${DEST_9P}
        read -p "mode : " MODE_9P
        arch-chroot /mnt chmod ${MODE_9P} ${DEST_9P}
    fi
done

if [ -n "$MOUNT_TAG_9P" ] ; then
    echo '9pnet_virtio' > /mnt/etc/modules-load.d/9pnet_virtio.conf
fi

echo "
######################################################
# Set time zone
# https://wiki.archlinux.org/title/Installation_guide#Time_zone
######################################################
"
echo -e "Setting time zone ..."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
arch-chroot /mnt hwclock --systohc

echo "
######################################################
# Set locale
# https://wiki.archlinux.org/title/Installation_guide#Localization
######################################################
"
echo -e "Setting locale ..."
arch-chroot /mnt sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=en_US.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=us" > /mnt/etc/vconsole.conf

echo "
######################################################
# Set network
# https://wiki.archlinux.org/title/Installation_guide#Network_configuration
######################################################
"
echo -e "Setting network ..."
echo -e "\n\nPlease tell me the hostname:"
read HOSTNAME
echo "$HOSTNAME" > /mnt/etc/hostname
echo -e "\nWhich network manager do you want to use?\n\t1\tsystemd-networkd\n\t2\tNetworkManger"
read -p "Please enter a number: " NETWORKMANAGER
if [ "$NETWORKMANAGER" -eq 1 ] ; then
    echo -e "Copying iso network configuration ..."
    cp /etc/systemd/network/20-ethernet.network /mnt/etc/systemd/network/20-ethernet.network
    echo "Enabling systemd-resolved.service and systemd-networkd.service ..."
    arch-chroot /mnt systemctl enable systemd-resolved.service
    arch-chroot /mnt systemctl enable systemd-networkd.service
elif [ "$NETWORKMANAGER" -eq 2 ] ; then
    echo "Installing NetworkManager and wpa_supplicant ..."
    arch-chroot /mnt pacman --noconfirm -S networkmanager wpa_supplicant
    echo "Enabling systemd-resolved.service and NetworkManager.service and wpa_supplicant.service ..."
    arch-chroot /mnt systemctl enable systemd-resolved.service
    arch-chroot /mnt systemctl enable NetworkManager.service
    arch-chroot /mnt systemctl enable wpa_supplicant.service
else
    echo "Invalid option."
    exit 1
fi



echo "
######################################################
# Disk encryption
# https://wiki.archlinux.org/title/Dm-crypt
######################################################
"
partprobe &> /dev/null    # reload partition table
ROOT_UUID=$(lsblk -dno UUID $ROOT_DEV)
BOOT_UUID=$(lsblk -dno UUID $BOOT_PART)
if [ "$IS_ENCRYPT" = y ] ; then
    # kernel cmdline parameters for encrypted root partition
    KERNEL_CMD="root=/dev/mapper/cryptroot"

    # /etc/crypttab.initramfs for root
    echo -e "\nConfiguring /etc/crypttab.iniramfs for encrypted root ..."
    if [ "$IS_CRYPTKEY" = y ] ; then
        echo "cryptroot  UUID=$ROOT_UUID  rootkeyfile:UUID=$BOOT_UUID  password-echo=no,x-systemd.device-timeout=0,keyfile-timeout=5s,timeout=0,no-read-workqueue,no-write-workqueue,discard"  >>  /mnt/etc/crypttab.initramfs
    else
        echo "cryptroot  UUID=$ROOT_UUID  -  password-echo=no,x-systemd.device-timeout=0,timeout=0,no-read-workqueue,no-write-workqueue,discard"  >>  /mnt/etc/crypttab.initramfs
    fi

    # /etc/crypttab for swap
    echo -e "Configuring /etc/crypttab.iniramfs for encrypted swap ..."
    swapoff $SWAP_PART
    # create a persistent partition name for swap
    # read [this](https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption#UUID_and_LABEL) for reason creating a 1MiB size ext2 filesystem
    mkfs.ext2 -F -F -L cryptswap $SWAP_PART 1M
    sleep 1
    partprobe &> /dev/null    # reload partition table
    sleep 1
    SWAP_UUID=$(lsblk -dno UUID $SWAP_PART)
    echo "cryptswap  UUID=$SWAP_UUID  /dev/urandom  swap,offset=2048" >> /mnt/etc/crypttab
    # change /etc/fstab swap entry
    sed -i "/swap/ s:^UUID=[a-zA-Z0-9-]*\s:/dev/mapper/cryptswap  :" /mnt/etc/fstab
    #fi

    # mkinitcpio
    # https://wiki.archlinux.org/title/Dm-crypt/System_configuration#mkinitcpio
    echo "Editing mkinitcpio ..."
    sed -i '/^HOOKS=/ s/ keyboard//' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/ udev//' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/base/base systemd keyboard/' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/autodetect/autodetect sd-vconsole/' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/block/block sd-encrypt/' /mnt/etc/mkinitcpio.conf
    if [ "$IS_CRYPTKEY" = y ] ; then
        sed -i '/^MODULES=/ s/()/(vfat)/' /mnt/etc/mkinitcpio.conf
    fi
    arch-chroot /mnt mkinitcpio -P
else
    KERNEL_CMD="root=UUID=$ROOT_UUID"
fi
# btrfs as root 
# https://wiki.archlinux.org/title/Btrfs#Mounting_subvolume_as_root
KERNEL_CMD="$KERNEL_CMD rootfstype=btrfs rootflags=subvol=/@ rw"

KERNEL_CMD="$KERNEL_CMD $OTHER_KERNEL_CMD"

echo "
######################################################
# VFIO kernel parameters
# https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Enabling_IOMMU
######################################################
"
read -p "Do you want to enable IOMMU for vfio/PCI passthrough? [y/N] " IS_VFIO
: "${IS_VFIO:=n}"
if [ "$IS_VFIO" = y ] ; then
    if [ $(echo "$UCODE_PKG" | grep "intel" | wc -l ) -ge 1 ] ; then
        # for intel cpu
        KERNEL_CMD="$KERNEL_CMD intel_iommu=on iommu=pt"
    else
        # amd cpu
        KERNEL_CMD="$KERNEL_CMD iommu=pt"
    fi
    sed -i '/^MODULES=/ s/)/ vfio_pci vfio vfio_iommu_type1 vfio_virqfd)/' /mnt/etc/mkinitcpio.conf
fi


echo "
######################################################
# boot loader (systemd-boot)
# https://wiki.archlinux.org/title/Arch_boot_process#Boot_loader
# If enabled secure boot use unified kernel image with systemd-boot,
# otherwise use normal systemd-boot
######################################################
"
arch-chroot /mnt bootctl install
if [ "$IS_SECURE_BOOT" = y ] ; then
    echo "
######################################################
# Secure boot setup
# https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot
######################################################
"
    echo "Configuring secure boot ..."
    arch-chroot /mnt bash <<'EOF'
# preparation
echo "Preparing ..."
pacman --noconfirm -S efitools sbsigntools
mkdir /etc/efi-keys
cd /etc/efi-keys

# create GUID for owner identification
echo "Creating GUID for owner identification ..."
uuidgen --random > GUID.txt

# generate platform key
echo "Generating platform key ..."
openssl req -newkey rsa:4096 -nodes -keyout PK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Platform Key/" -out PK.crt
openssl x509 -outform DER -in PK.crt -out PK.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" PK.crt PK.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt PK PK.esl PK.auth

# generate key exchange key
echo "Generating key exchange key ..."
openssl req -newkey rsa:4096 -nodes -keyout KEK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Key Exchange Key/" -out KEK.crt
openssl x509 -outform DER -in KEK.crt -out KEK.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" KEK.crt KEK.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt KEK KEK.esl KEK.auth

# Database key
echo "Generating database key ..."
openssl req -newkey rsa:4096 -nodes -keyout db.key -new -x509 -sha256 -days 3650 -subj "/CN=my Signature Database key/" -out db.crt
openssl x509 -outform DER -in db.crt -out db.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" db.crt db.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k KEK.key -c KEK.crt db db.esl db.auth

# enroll these keys into firmware
echo "Enrolling these keys into firmware ..."
mkdir -p /etc/secureboot/keys/{db,dbx,KEK,PK}
cp /etc/efi-keys/PK.auth /etc/secureboot/keys/PK/
cp /etc/efi-keys/KEK.auth /etc/secureboot/keys/KEK/
cp /etc/efi-keys/db.auth /etc/secureboot/keys/db/

# enroll your keys
echo "Enrolling your keys ..."
chattr -i /sys/firmware/efi/efivars/{PK,KEK,db}*
sbkeysync --verbose

# enroll your PK
echo "Enrolling your platform key ..."
efi-updatevar -f /etc/secureboot/keys/PK/PK.auth PK
sbkeysync --verbose --pk
EOF
    
    # Setup unified kernel image
    # https://wiki.archlinux.org/title/Unified_kernel_image
    echo "Creating unified kernel image ..."
    for KERNEL in $KERNEL_PKGS
    do 
        sed -i '\:^ALL_kver=.*:a ALL_microcode=(/boot/*-ucode.img)' /mnt/etc/mkinitcpio.d/$KERNEL.preset
        sed -i "s:^#default_options=.*:default_options=\"--splash /usr/share/systemd/bootctl/splash-arch.bmp\"\\ndefault_efi_image=\"/boot/EFI/Linux/archlinux-$KERNEL.efi\":" /mnt/etc/mkinitcpio.d/$KERNEL.preset
        sed -i "s:^fallback_options=.*:fallback_options=\"-S autodetect --splash /usr/share/systemd/bootctl/splash-arch.bmp\"\\nfallback_efi_image=\"/boot/EFI/Linux/archlinux-$KERNEL-fallback.efi\":" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    done
    
    echo "$KERNEL_CMD" > /mnt/etc/kernel/cmdline
    echo "Regenerating the initramfs ..."
    arch-chroot /mnt mkinitcpio -P

    echo "Adding pacman hooks ..."
    mkdir -p /mnt/etc/pacman.d/hooks
    cat >> /mnt/etc/pacman.d/hooks/100-systemd-boot.hook <<'EOF'
[Trigger]
Type = Package
Operation = Upgrade
Target = systemd

[Action]
Description = Gracefully upgrading systemd-boot...
When = PostTransaction
Exec = /usr/bin/systemctl restart systemd-boot-update.service
EOF

    cat >> /mnt/etc/pacman.d/hooks/99-secureboot.hook <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux*
Target = systemd

[Action]
Description = Signing Kernel for SecureBoot
When = PostTransaction
Exec = /usr/bin/find /boot -type f ( -name 'archlinux-linux*.efi' -o -name systemd* -o -name BOOTX64.EFI ) -exec /usr/bin/sh -c 'if ! /usr/bin/sbverify --list {} 2>/dev/null | /usr/bin/grep -q "signature certificates"; then /usr/bin/sbsign --key /etc/efi-keys/db.key --cert /etc/efi-keys/db.crt --output "$1" "$1"; fi' _ {} ;
Depends = sbsigntools
Depends = findutils
Depends = grep
EOF

    cat >> /mnt/boot/loader/loader.conf <<EOF
default  archlinux-${KERNEL_PKGS%% *}.efi
timeout  1
console-mode keep
editor   no
EOF
    
    # sign the unified kernel image
    arch-chroot /mnt pacman --noconfirm -S systemd

    echo -e "\n\n"
    read -p "Do you want to add Microsoft's UEFI drivers certificates to the database? [y/N] " IS_MS_CERT
    : "${IS_MS_CERT:=n}"
    IS_MS_CERT="${IS_MS_CERT,,}"
    if [ "$IS_MS_CERT" = y ] ; then
        echo "Adding Microsoft's certificate to the database ..."
        arch-chroot /mnt bash <<'EOF'
cd /etc/efi-keys
echo "Downloading MS cert ..."
curl -O https://www.microsoft.com/pkiops/certs/MicCorUEFCA2011_2011-06-27.crt
sbsiglist --owner 77fa9abd-0359-4d32-bd60-28f4e78f784b --type x509 --output MS_UEFI_db.esl MicCorUEFCA2011_2011-06-27.crt
sign-efi-sig-list -a -g 77fa9abd-0359-4d32-bd60-28f4e78f784b -k KEK.key -c KEK.crt db MS_UEFI_db.esl add_MS_UEFI_db.auth
echo "Adding MS UEFI cert to firmware ..."
cp /etc/efi-keys/add_MS_UEFI_db.auth /etc/secureboot/keys/db/
chattr -i /sys/firmware/efi/efivars/{PK,KEK,db}*
sbkeysync --verbose
EOF
    fi
    
else
    echo "
######################################################
# Configure systemd-boot for non-secure boot
# https://wiki.archlinux.org/title/Systemd-boot
######################################################
"
    echo "Configuring systemd-boot ..."
    arch-chroot /mnt systemctl enable systemd-boot-update.service

    # /boot/loader/loader.conf
    cat >> /mnt/boot/loader/loader.conf <<EOF
default  arch_${KERNEL_PKGS%% *}.conf
timeout  1
console-mode keep
editor   no
EOF

    # /boot/loader/entries/arch-linux.conf
for KERNEL in $KERNEL_PKGS
do 
    cat >> "/mnt/boot/loader/entries/arch-${KERNEL}.conf" <<EOF
title   Arch Linux ($KERNEL)
linux   /vmlinuz-$KERNEL
initrd  /$UCODE_PKG.img
initrd  /initramfs-$KERNEL.img
options $KERNEL_CMD
EOF
    # /boot/loader/entries/arch-linux-fallback.conf
    cp "/mnt/boot/loader/entries/arch-${KERNEL}.conf" "/mnt/boot/loader/entries/arch-${KERNEL}-fallback.conf"
    sed -i '/Arch Linux/ s/)/ fallback initramfs)/' "/mnt/boot/loader/entries/arch-${KERNEL}-fallback.conf"
    sed -i "s/initramfs-${KERNEL}.img/initramfs-${KERNEL}-fallback.img/" "/mnt/boot/loader/entries/arch-${KERNEL}-fallback.conf"
done

fi

echo "
######################################################
# OpenSSH server
# https://wiki.archlinux.org/title/OpenSSH#Server_usage
######################################################
"
read -p "Do you want to enable ssh? [y/N] " IS_SSH
: "${IS_SSH:=n}"
IS_SSH="${IS_SSH,,}"
if [ "$IS_SSH" = y ] ; then
    arch-chroot /mnt pacman --noconfirm -S openssh
    arch-chroot /mnt systemctl enable sshd.service
    echo " Enabled sshd.service"
    echo "ssh port? (22)"
    read SSH_PORT
    : "${SSH_PORT:=22}"
    sed -i "s/^#Port.*/Port ${SSH_PORT}/" /mnt/etc/ssh/sshd_config
fi


echo "
######################################################
# User account
# https://wiki.archlinux.org/title/Users_and_groups
######################################################
"
arch-chroot /mnt sed -i '/^# %wheel ALL=(ALL:ALL) ALL/ s/# //' /etc/sudoers
read -p "Do you want to add an administration account (user in group wheel) now? [Y/n] " IS_USER
: "${IS_USER:=y}"
if [ "$IS_USER" = y ] ; then
    echo "Adding administration account ..."
    read -p "Tell me your username: " USERNAME
    arch-chroot /mnt useradd -m -G wheel "$USERNAME"
    echo "Please enter your password: "
    arch-chroot /mnt passwd "$USERNAME"
    read -p "Do you want to disable root account? [Y/n] " IS_ROOT_DISABLE
    : "${IS_ROOT_DISABLE:=y}"
    if [ "$IS_ROOT_DISABLE" = y ] ; then
        # https://wiki.archlinux.org/title/Sudo#Disable_root_login
        echo "Disabling root ..."
        arch-chroot /mnt passwd -d root
        arch-chroot /mnt passwd -l root
    fi
else
    echo "Please Enter your root password."
    arch-chroot /mnt passwd
    cat >> /mnt/root/homed.sh <<'EOF'
#!/usr/bin/bash
# A script to create a user using systemd-homed since it cannot create a user under chroot environment.
systemctl enable --now systemd-homed.service
read -p "Tell me your username: " USERNAME
read -p "Tell me the filesystem inside your home directory (btrfs or ext4): " FSTYPE
homectl create "$USERNAME" --uid=1000 --member-of=wheel --shell=/bin/bash --storage=luks --fs-type="$FSTYPE"
read -p "Do you want to disable root account? [Y/n] " IS_ROOT_DISABLE
: "${IS_ROOT_DISABLE:=n}"
if [ "$IS_ROOT_DISABLE" = y ] ; then
    # https://wiki.archlinux.org/title/Sudo#Disable_root_login
    echo "Disabling root ..."
    passwd -d root
    passwd -l root
fi
EOF
    echo "Created a homed.sh script in the /root directory to help set up systemd-homed user account."
fi



