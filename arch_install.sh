#!/usr/bin/bash

UCODE_PKG="intel-ucode"
BASE_PKGS="base linux-firmware sudo python efibootmgr iptables-nft"
BTRFS_MOUNT_OPTS="ssd,noatime,compress=zstd:1,space_cache=v2,autodefrag"
TIMEZONE="US/Eastern"

## server example
#KERNEL_PKGS="linux-hardened"
#FS_PKGS="dosfstools btrfs-progs"
#OTHER_KERNEL_CMD="console=ttyS0"    # this kernel parameter force output to serial port, useful for libvirt virtual machine w/o any graphis.

# desktop example
KERNEL_PKGS="linux"
FS_PKGS="dosfstools e2fsprogs btrfs-progs"
OTHER_PKGS="man-db vim"
OTHER_PKGS="$OTHER_PKGS git base-devel ansible"


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
read -p "Do you want to set up secure boot with your own key and encrypt root partition? [Y/n] " HARDENED
: "${HARDENED:=y}"
HARDENED="${HARDENED,,}"
# check the firmware is in the setup mode
if [ "$HARDENED" = y ] ; then
    SETUP_MODE=$(bootctl status | grep -E "Secure Boot.*setup" | wc -l)
    if [ "$SETUP_MODE" -ne 1 ] ; then
        echo "The firmware is not in the setup mode. Please check BIOS."
        read -p "Continue without secure boot? [y/N] " CONTINUE
        : "${CONTINUE:=n}"
        CONTINUE="${CONTINUE,,}"
        if [ "$CONTINUE" = y ] ; then
            HARDENED="n"
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
# EFI boot settings
# https://man.archlinux.org/man/efibootmgr.8
######################################################
"
efibootmgr
EFI_BOOT_ID=" "
while [ -n "$EFI_BOOT_ID" ]; do
    echo -e "\nDo you want to delete any boot entries?: "
    read -p "Enter boot number (empty to skip): " EFI_BOOT_ID
    if [ -n "$EFI_BOOT_ID" ] ; then
        efibootmgr -b $EFI_BOOT_ID -B
    fi
done

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
PARTITIONS=$(lsblk --paths --list --noheadings --output=name,size,model | grep --invert-match "loop" | cat --number)

# EFI partition
echo -e "\n\nTell me the EFI partition number:"
echo "$PARTITIONS"
read -p "Enter a number: " EFI_ID
EFI_PART=$(echo "$PARTITIONS" | awk "\$1 == $EFI_ID { print \$2}")

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
echo "Running command: mkfs.fat -n boot -F 32 $EFI_PART"
mkfs.fat -n boot -F 32 "$EFI_PART"

# swap partition
echo "Formatting swap partition ..."
echo "Running command: mkswap -L swap $SWAP_PART"
mkswap -L swap "$SWAP_PART"


if [ "$HARDENED" = y ] ; then
    echo "
######################################################
# Encrypt the root partion
# https://wiki.archlinux.org/title/Dm-crypt/Device_encryption
######################################################
"
    echo -e "Do you want to create a key file on the efi partition to automatically unlock the root partition on boot?\nThis could be used with the setup that the boot partition on an external flash drive, such that the system could autounlock on boot. But without the flash drive the system cannot boot and root partition is encrypted. It's not recommended if both efi and root partition on the same device, it would make the encryption meanless. Since the key file is on the unencrypted efi partition, anyone could easily the key file and decrypt the root partition.\nIf choose n then it will ask you for a encryption password."
    read -p "[y/N] " CRYPTKEY
    : "${CRYPTKEY:=n}"
    CRYPTKEY="${CRYPTKEY,,}"
    if [ "$CRYPTKEY" != y ] ; then
        # passphrase
        echo -e "\nRunning cryptsetup ..."
        cryptsetup --type luks2 --verify-passphrase --sector-size 4096 --verbose luksFormat "$ROOT_PART"
        echo -e "\nDecrypting root partition ..."
        cryptsetup open "$ROOT_PART" cryptroot
    else
        # create keyfile
        echo -e "\nCreating keyfile ..."
        mount "$EFI_PART" /mnt
        dd bs=512 count=4 if=/dev/random of=/mnt/rootkeyfile iflag=fullblock
        chmod 600 /mnt/rootkeyfile
        echo -e "\nRunning cryptsetup ..."
        cryptsetup --type luks2 --verify-passphrase --sector-size=4096 --key-file=/mnt/rootkeyfile --verbose luksFormat "$ROOT_PART"
        cryptsetup open "$ROOT_PART" cryptroot --key-file /mnt/rootkeyfile
        umount "$EFI_PART"
    fi
    ROOT_BLOCK=$ROOT_PART
    ROOT_PART=/dev/mapper/cryptroot
else
    ROOT_BLOCK=$ROOT_PART
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
if [ "$HARDENED" = y ] ; then
    mkdir /mnt/@/efi
fi
umount "$ROOT_PART"

# mount all partitions
echo -e "\nMounting all partitions ..."
mount -o "$BTRFS_MOUNT_OPTS",subvol=@ "$ROOT_PART" /mnt
mount -o "$BTRFS_MOUNT_OPTS",subvol=@home "$ROOT_PART" /mnt/home
mount -o "$BTRFS_MOUNT_OPTS",subvol=@snapshots "$ROOT_PART" /mnt/.snapshots
mount -o "$BTRFS_MOUNT_OPTS",subvol=@var_log "$ROOT_PART" /mnt/var/log
mount -o "$BTRFS_MOUNT_OPTS",subvol=@pacman_pkgs "$ROOT_PART" /mnt/var/cache/pacman/pkg
if [ "$HARDENED" = y ] ; then
    mount "$EFI_PART" /mnt/efi
else
    mount "$EFI_PART" /mnt/boot
fi
swapon "$SWAP_PART"


echo "
######################################################
# Add selinux repo
# https://github.com/archlinuxhardened/selinux#binary-repository
######################################################
"
read -p "Do you want to enable SELinux repo? [y/N] " SELINUX
: "${SELINUX:=n}"
SELINUX="${SELINUX,,}"

if [ "$SELINUX" == y ] ; then
    echo "[selinux]" >> /etc/pacman.conf
    echo "Server = https://github.com/archlinuxhardened/selinux/releases/download/ArchLinux-SELinux" >> /etc/pacman.conf
    echo "SigLevel = PackageOptional" >> /etc/pacman.conf
    pacman -Sy
    BASE_PKGS=$(echo $BASE_PKGS | sed 's/base /base-selinux /')
    BASE_PKGS=$(echo $BASE_PKGS | sed 's/base-devel /base-devel-selinux /')
    BASE_PKGS=$(echo $BASE_PKGS | sed 's/sudo /sudo-selinux /')
    BASE_PKGS=$(echo $BASE_PKGS | sed 's/openssh /openssh-selinux /')
    BASE_PKGS="$BASE_PKGS archlinux-keyring"
fi


echo "
######################################################
# Install packages
# https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages
######################################################
"
pacstrap -K /mnt $BASE_PKGS $KERNEL_PKGS $FS_PKGS $UCODE_PKG $OTHER_PKGS efibootmgr


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
    read -p "Install and enable iwd (for WiFi) ? [y/N] " INSTALL_IWD
    : "${INSTALL_IWD:=n}"
    INSTALL_IWD="${INSTALL_IWD,,}"
    if [ "$INSTALL_IWD" = y ] ; then
        arch-chroot /mnt pacman --noconfirm -S iwd
        arch-chroot /mnt systemctl enable iwd.service
    fi
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



partprobe &> /dev/null    # reload partition table
sleep 1
ROOT_UUID=$(lsblk -dno UUID $ROOT_BLOCK)
EFI_UUID=$(lsblk -dno UUID $EFI_PART)
if [ "$HARDENED" = y ] ; then
    echo "
######################################################
# Disk encryption
# https://wiki.archlinux.org/title/Dm-crypt
######################################################
"
    # kernel cmdline parameters for encrypted root partition
    KERNEL_CMD="root=/dev/mapper/cryptroot"

    # /etc/crypttab.initramfs for root
    echo -e "\nConfiguring /etc/crypttab.iniramfs for encrypted root ..."
    if [ "$CRYPTKEY" = y ] ; then
        echo "cryptroot  UUID=$ROOT_UUID  rootkeyfile:UUID=$EFI_UUID  password-echo=no,x-systemd.device-timeout=0,keyfile-timeout=5s,timeout=0,no-read-workqueue,no-write-workqueue,discard"  >>  /mnt/etc/crypttab.initramfs
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
    sed -i '/^HOOKS=/ s/ keymap//' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/ consolefont//' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/base/base systemd keyboard/' /mnt/etc/mkinitcpio.conf
    #sed -i '/^HOOKS=/ s/autodetect/autodetect sd-vconsole/' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/block/sd-vconsole block sd-encrypt/' /mnt/etc/mkinitcpio.conf
    if [ "$CRYPTKEY" = y ] ; then
        sed -i '/^MODULES=/ s/(/(vfat /' /mnt/etc/mkinitcpio.conf
    fi
else
    KERNEL_CMD="root=UUID=$ROOT_UUID"
fi

# btrfs as root 
# https://wiki.archlinux.org/title/Btrfs#Mounting_subvolume_as_root
KERNEL_CMD="$KERNEL_CMD rootfstype=btrfs rootflags=subvol=/@ rw"
# modprobe.blacklist=pcspkr will disable PC speaker (beep) globally
# https://wiki.archlinux.org/title/PC_speaker#Globally
KERNEL_CMD="$KERNEL_CMD modprobe.blacklist=pcspkr $OTHER_KERNEL_CMD"


echo "
######################################################
# SELinux
# https://wiki.archlinux.org/title/SELinux#Enable_SELinux_LSM
######################################################
"
if [ "$SELINUX" == y ] ; then
    echo "Adding SELinux LSM to kernel parameter ..."
    KERNEL_CMD="$KERNEL_CMD lsm=landlock,lockdown,yama,integrity,selinux,bpf"
    echo "Adding SELinux repo ..."
    echo "[selinux]" >> /mnt/etc/pacman.conf
    echo "Server = https://github.com/archlinuxhardened/selinux/releases/download/ArchLinux-SELinux" >> /mnt/etc/pacman.conf
    echo "SigLevel = PackageOptional" >> /mnt/etc/pacman.conf
else
    echo "Skipping ..."
fi


echo "
######################################################
# VFIO kernel parameters
# https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#Enabling_IOMMU
######################################################
"
read -p "Do you want to enable IOMMU for vfio/PCI passthrough? [y/N] " ENABLE_VFIO
: "${ENABLE_VFIO:=n}"
ENABLE_VFIO="${ENABLE_VFIO,,}"
if [ "$ENABLE_VFIO" = y ] ; then
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
# Setup unified kernel image
# https://wiki.archlinux.org/title/Unified_kernel_image
######################################################
"
arch-chroot /mnt mkdir -p /boot/EFI/Linux
for KERNEL in $KERNEL_PKGS
do 
    # Add line ALL_microcode=(/boot/*-ucode.img)
    sed -i '\|^ALL_kver=.*|a ALL_microcode=(/boot/*-ucode.img)' /mnt/etc/mkinitcpio.d/$KERNEL.preset
    # Add Arch splash screen and add PRESET_uki=
    sed -i "s|^#default_options=.*|default_options=\"--splash /usr/share/systemd/bootctl/splash-arch.bmp\"\\ndefault_uki=\"/boot/EFI/Linux/ArchLinux-$KERNEL.efi\"|" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    sed -i "s|^fallback_options=.*|fallback_options=\"-S autodetect\"\\nfallback_uki=\"/boot/EFI/Linux/ArchLinux-$KERNEL-fallback.efi\"|" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    # comment out PRESET_image=
    sed -i "s|^default_image=.*|#&|" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    sed -i "s|^fallback_image=.*|#&|" /mnt/etc/mkinitcpio.d/$KERNEL.preset
done

# remove leftover initramfs-*.img from /boot or /efi
rm /mnt/efi/initramfs-*.img 2>/dev/null
rm /mnt/boot/initramfs-*.img 2>/dev/null

echo "$KERNEL_CMD" > /mnt/etc/kernel/cmdline
if [ "$HARDENED" != 'y' ] ; then
    echo "Regenerating the initramfs ..."
    arch-chroot /mnt mkinitcpio -P
fi


if [ "$HARDENED" = y ] ; then
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

    echo -e "\n\n"
    read -p "Do you want to add Microsoft's UEFI drivers certificates to the database? [y/N] " ADD_MS_CERT
    : "${ADD_MS_CERT:=n}"
    ADD_MS_CERT="${ADD_MS_CERT,,}"
    if [ "$ADD_MS_CERT" = y ] ; then
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

    echo "Adding pacman hooks ..."
    mkdir -p /mnt/etc/pacman.d/hooks
    cat >> /mnt/etc/pacman.d/hooks/99-secureboot.hook <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Path
Target = usr/lib/modules/*/vmlinuz
Target = usr/lib/initcpio/*

[Action]
Description = Signing Unified Kernel Images for SecureBoot
When = PostTransaction
Exec = /usr/bin/bash -c 'for ENTRY in /boot/EFI/Linux/*.efi ; do /usr/bin/sbsign --key /etc/efi-keys/db.key --cert /etc/efi-keys/db.crt --output "/efi/EFI/Linux/${ENTRY##*/}" "/boot/EFI/Linux/${ENTRY##*/}" ; done'
Depends = sbsigntools
EOF

    # sign the unified kernel image
    arch-chroot /mnt mkdir -p /efi/EFI/Linux
    if [ "$SELINUX" != y ] ; then
        arch-chroot /mnt pacman --noconfirm -S systemd
    else
        arch-chroot /mnt pacman --noconfirm -S systemd-selinux
    fi

fi

echo "
######################################################
# Set up UFEI boot the unified kernel image directly
# https://wiki.archlinux.org/title/Unified_kernel_image#Directly_from_UEFI
######################################################
"
EFI_DEV=$(lsblk --noheadings --output PKNAME $EFI_PART)
EFI_PART_NUM=$(echo $EFI_PART | grep -Eo '[0-9]+$')
arch-chroot /mnt pacman --noconfirm -S --needed efibootmgr
for KERNEL in $KERNEL_PKGS
do
    arch-chroot /mnt efibootmgr --create --disk /dev/${EFI_DEV} --part ${EFI_PART_NUM} --label "ArchLinux-$KERNEL" --loader "EFI\\Linux\\ArchLinux-$KERNEL.efi" --quiet
    arch-chroot /mnt efibootmgr --create --disk /dev/${EFI_DEV} --part ${EFI_PART_NUM} --label "ArchLinux-$KERNEL-fallback" --loader "EFI\\Linux\\ArchLinux-$KERNEL-fallback.efi" --quiet
done

echo -e "\n"
arch-chroot /mnt efibootmgr
echo -e "\n\nDo you want to change boot order?: "
read -p "Enter boot order XXXX,XXXX (empty to skip): " BOOT_ORDER
if [ -n "$BOOT_ORDER" ] ; then
    echo -e "\n"
    arch-chroot /mnt efibootmgr --bootorder ${BOOT_ORDER}
    echo -e "\n"
fi


echo "
######################################################
# unprivileged user namespace
# https://wiki.archlinux.org/title/Podman#Rootless_Podman
######################################################
"
if [[ "$KERNEL_PKGS" == *"linux-hardened"* ]]; then
    read -p "Do you want to enable the unprivileged user namespace (for rootless containers) ? [y/N] " ENABLE_USER_NS_UNPRIVILEGED
    : "${ENABLE_USER_NS_UNPRIVILEGED:=n}"
    ENABLE_USER_NS_UNPRIVILEGED="${ENABLE_USER_NS_UNPRIVILEGED,,}"
    if [ "$ENABLE_USER_NS_UNPRIVILEGED" = y ] ; then
        echo "kernel.unprivileged_userns_clone=1" >> /mnt/etc/sysctl.d/unprivileged_user_namespace.conf
    fi
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
    if [ "$SELINUX" != y ] ; then
        arch-chroot /mnt pacman --noconfirm -S --needed openssh
    else
        arch-chroot /mnt pacman --noconfirm -S --needed openssh-selinux
    fi
    arch-chroot /mnt systemctl enable sshd.service
    echo " Enabled sshd.service"
    echo "ssh port? (22)"
    read SSH_PORT
    : "${SSH_PORT:=22}"
    sed -i "s/^#Port.*/Port ${SSH_PORT}/" /mnt/etc/ssh/sshd_config
fi


echo "
######################################################
# Firewalld
# https://wiki.archlinux.org/title/firewalld
######################################################
"
arch-chroot /mnt pacman --noconfirm -S firewalld
arch-chroot /mnt systemctl enable firewalld.service
echo "Set default firewall zone to drop."
arch-chroot /mnt firewall-offline-cmd --set-default-zone=drop
if [ "$IS_SSH" = y ] ; then
    echo "modify default ssh service with new port."
    sed "/port=/s/port=\"22\"/port=\"${SSH_PORT}\"/" /mnt/usr/lib/firewalld/services/ssh.xml  > /mnt/etc/firewalld/services/ssh.xml
    #arch-chroot /mnt firewall-offline-cmd --zone=drop --add-service=ssh
    echo "ssh allow ip address (example 192.168.1.0/24)"
    read SSH_FROM
    arch-chroot /mnt firewall-offline-cmd --zone=drop --add-rich-rule="rule family='ipv4' source address='${SSH_FROM}' service name='ssh' accept"
fi


echo "
######################################################
# User account
# https://wiki.archlinux.org/title/Users_and_groups
######################################################
"
# add wheel group to sudoer
sed -i '/^# %wheel ALL=(ALL:ALL) ALL/ s/# //' /mnt/etc/sudoers

read -p "Do you want to create user with systemd-homed? [y/N] " IS_HOMED
: "${IS_HOMED:=n}"
IS_HOMED="${IS_HOMED,,}"
if [ "$IS_HOMED" = y ] ; then
    cp "$(pwd)/homed.sh" /mnt/root/homed.sh
    echo "Created /root/homed.sh Run it after reboot to create systemd-homed user, which can't be done in chroot environment."
    echo "Enter root password (/root/homed.sh can disable root account after you setup systemd-homed user)"
    arch-chroot /mnt passwd


else
    read -p "Tell me your username: " USERNAME
    arch-chroot /mnt useradd -m -G wheel "$USERNAME"
    arch-chroot /mnt passwd "$USERNAME"

    read -p "Do you want to disable root account? [Y/n] " IS_ROOT_DISABLE
    : "${IS_ROOT_DISABLE:=n}"
    IS_ROOT_DISABLE="${IS_ROOT_DISABLE,,}"
    if [ "$IS_ROOT_DISABLE" = y ] ; then
        # https://wiki.archlinux.org/title/Sudo#Disable_root_login
        echo "Disabling root ..."
        arch-chroot /mnt passwd -d root
        arch-chroot /mnt passwd -l root
    else
        echo "Enter root password"
        arch-chroot /mnt passwd

    fi
fi

