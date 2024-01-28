#!/usr/bin/bash

UCODE_PKG="amd-ucode"
BTRFS_MOUNT_OPTS="ssd,noatime,compress=zstd:1,space_cache=v2,autodefrag"

# Localization
# https://wiki.archlinux.org/title/Installation_guide#Localization
LANG='en_US.UTF-8'
KEYMAP='us'
# https://wiki.archlinux.org/title/Time_zone
TIMEZONE="US/Eastern"

# zram-size option in zram-generator.conf if enabled zram.
ZRAM_SIZE='min(ram / 2, 4 * 1024)'

# minimal example
KERNEL_PKGS="linux"
BASE_PKGS="base sudo linux-firmware iptables-nft python"
FS_PKGS="dosfstools btrfs-progs"
#KERNEL_PARAMETERS="console=ttyS0"    # this kernel parameter force output to serial port, useful for libvirt virtual machine w/o any graphis.

## server example
#KERNEL_PKGS="linux-hardened"
#BASE_PKGS="base sudo linux-firmware python efibootmgr iptables-nft"
#FS_PKGS="dosfstools btrfs-progs"
#OTHER_PKGS="vim"

## desktop example
#KERNEL_PKGS="linux"
#BASE_PKGS="base linux-firmware sudo python efibootmgr iptables-nft"
#FS_PKGS="dosfstools e2fsprogs btrfs-progs"
#OTHER_PKGS="man-db vim"
#OTHER_PKGS="$OTHER_PKGS git base-devel ansible"


if [[ $(tty) == '/dev/ttyS0'  ]] ; then
    # Using serial port
    KERNEL_PARAMETERS="$KERNEL_PARAMETERS console=ttyS0"
fi

######################################################

echo "

This is an Arch Linux installation script.
To activate it, press Enter, otherwise, press any other key.
If you activate it, you will be given a chance to install the glorious Arch Linux automatically.
However, there is no guarantee of success.
There is also no guarantee of your existing data safety.
"
read -p "Ready? " start_install

if [[ -n $start_install ]] ; then
    exit 1
fi


echo "
######################################################
# Verify the boot mode
# https://wiki.archlinux.org/title/Installation_guide#Verify_the_boot_mode
######################################################
"
if [[ -e /sys/firmware/efi/efivars ]] ; then
    echo "UEFI mode OK."
else
    echo "System not booted in UEFI mode!"
    exit 1
fi
echo -e "\n"
read -p "Do you want to set up secure boot with your own key? [Y/n] " secure_boot
secure_boot="${secure_boot:-y}"
secure_boot="${secure_boot,,}"

# check the firmware is in the setup mode
if [[ $secure_boot == y ]] ; then
    # bootctl status output should have
    # Secure Boot: disabled (setup)
    setup_mode=$(bootctl status | grep -E "Secure Boot.*setup" | wc -l)
    if [[ $setup_mode -ne 1 ]] ; then
        echo "The firmware is not in the setup mode. Please check BIOS."
        read -p "Continue without secure boot? [y/N] " keep_going
        keep_going="${keep_going:-n}"
        keep_going="${keep_going,,}"
        if [[ keep_going == y ]] ; then
            secure_boot="n"
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
if [[ $? -ne 0 ]] ; then
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
efi_boot_id=" "
while [[ -n $efi_boot_id ]]; do
    echo -e "\nDo you want to delete any boot entries?: "
    read -p "Enter boot number (empty to skip): " efi_boot_id
    if [[ -n $efi_boot_id ]] ; then
        efibootmgr -b $efi_boot_id -B
    fi
done

echo "
######################################################
# Partition disks
# https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks
######################################################
"
umount -R /mnt
devices=$(lsblk --nodeps --paths --list --noheadings --sort=size --output=name,size,model | grep --invert-match "loop" | cat --number)

device_id=" "
while [[ -n $device_id ]]; do
    echo -e "Choose device to format:"
    echo "$devices"
    read -p "Enter a number (empty to skip): " device_id
    if [[ -n $device_id ]] ; then
        device=$(echo "$devices" | awk "\$1 == $device_id { print \$2}")
        fdisk "$device"
    fi
done

partitions=$(lsblk --paths --list --noheadings --output=name,size,model | grep --invert-match "loop" | cat --number)

# EFI partition
echo -e "\n\nTell me the EFI partition number:"
echo "$partitions"
read -p "Enter a number: " efi_id
efi_part=$(echo "$partitions" | awk "\$1 == $efi_id { print \$2}")

# root partition
echo -e "\n\nTell me the root partition number:"
echo "$partitions"
read -p "Enter a number: " root_id
root_part=$(echo "$partitions" | awk "\$1 == $root_id { print \$2}")

# Wipe existing LUKS header
# https://wiki.archlinux.org/title/Dm-crypt/Drive_preparation#Wipe_LUKS_header
# Erase all keys
cryptsetup erase $root_part 2> /dev/null
# Make sure there is no active slots left
cryptsetup luksDump $root_part 2> /dev/null
# Remove LUKS header to prevent cryptsetup from detecting it
wipefs --all $root_part 2> /dev/null

# swap partition
# swap is important, see [In defence of swap](https://chrisdown.name/2018/01/02/in-defence-of-swap.html)
echo -e "\n\nTell me the swap partition number:"
echo "$partitions"
read -p "Enter a number or press ENTER to skip: " swap_id
if [[ -n $swap_id ]] ; then
    swap_part=$(echo "$partitions" | awk "\$1 == $swap_id { print \$2}") || swap_part=""

    # Wipe existing LUKS header
    cryptsetup erase $swap_part 2> /dev/null
    cryptsetup luksDump $swap_part 2> /dev/null
    wipefs --all $swap_part 2> /dev/null
fi


echo "
######################################################
# Format the partitions
# https://wiki.archlinux.org/title/Installation_guide#Format_the_partitions
######################################################
"
# EFI partition
echo "Formatting EFI partition ..."
echo "Running command: mkfs.fat -n boot -F 32 $efi_part"
# create fat32 partition with name(label) boot
mkfs.fat -n boot -F 32 "$efi_part"

# swap partition
if [[ -n $swap_id ]] ; then
    echo "Formatting swap partition ..."
    echo "Running command: mkswap -L swap $swap_part"
    # create swap partition with label swap
    mkswap -L swap "$swap_part"
fi


echo "
######################################################
# Encrypt the root partion
# https://wiki.archlinux.org/title/Dm-crypt/Device_encryption
######################################################
"
read -p "Do you want to encrypt root partition? [Y/n] " encrypt_root
encrypt_root="${encrypt_root:-y}"
encrypt_root="${encrypt_root,,}"
if [[ $encrypt_root == y ]] ; then
    echo -e "\nDo you want to create a key file on the efi partition to automatically unlock the root partition on boot?\nThis could be used with the setup that the boot partition on an external flash drive, such that the system could autounlock on boot. But without the flash drive the system cannot boot and root partition is encrypted. It's not recommended if both efi and root partition on the same device, it would make the encryption meanless. Since the key file is on the unencrypted efi partition, anyone could easily the key file and decrypt the root partition.\nIf choose n then it will ask you for a encryption password."
    read -p "[y/N] " cryptkey
    cryptkey="${cryptkey:-n}"
    cryptkey="${cryptkey,,}"
    if [[ $cryptkey == y ]] ; then
        # create keyfile
        # https://wiki.archlinux.org/title/Dm-crypt/Device_encryption#Creating_a_keyfile_with_random_characters
        echo -e "\nCreating keyfile ..."
        mount "$efi_part" /mnt
        dd bs=512 count=4 if=/dev/random of=/mnt/rootkeyfile iflag=fullblock
        chmod 600 /mnt/rootkeyfile
        echo -e "\nRunning cryptsetup ..."
        cryptsetup --type luks2 --verify-passphrase --sector-size=4096 --key-file=/mnt/rootkeyfile --verbose luksFormat "$root_part"
        cryptsetup open "$root_part" cryptroot --key-file /mnt/rootkeyfile
        umount "$efi_part"
    else
        # passphrase
        echo -e "\nRunning cryptsetup ..."
        # SSD usually report their sector size as 512 bytes, even though they use larger sector size.
        # So add --sector-size 4096 force create a LUKS2 container with 4K sector size.
        # If the sector size is wrong cryptsetup will abort with an error.
        # To re-encrypt with correct sector size see
        # https://wiki.archlinux.org/title/Advanced_Format#dm-crypt
        cryptsetup --type luks2 --verify-passphrase --sector-size 4096 --verbose luksFormat "$root_part"
        echo -e "\nDecrypting root partition ..."
        cryptsetup open "$root_part" cryptroot
    fi
    # e.g. boot_block=/dev/sdX2
    root_block=$root_part
    root_part=/dev/mapper/cryptroot
else
    root_block=$root_part
fi


# format root partition
echo -e "\n\nFormatting root partition ..."
echo "Running command: mkfs.btrfs -L ArchLinux -f $root_part"
# create root partition with label ArchLinux
mkfs.btrfs -L ArchLinux -f "$root_part"
# create subvlumes
echo "Creating btrfs subvolumes ..."
mount "$root_part" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@pacman_pkgs
mkdir /mnt/@/{efi,home,.snapshots}
mkdir -p /mnt/@/var/log
mkdir -p /mnt/@/var/cache/pacman/pkg
umount "$root_part"

# mount all partitions
echo -e "\nMounting all partitions ..."
mount -o "$BTRFS_MOUNT_OPTS",subvol=@ "$root_part" /mnt
# https://wiki.archlinux.org/title/Security#Mount_options
# Mount file system with nodev,nosuid,noexec except /home partition.
home_mount_opts="$BTRFS_MOUNT_OPTS,nodev"
read -p "Do you want to add noexec mount options to /home? (Adding it may breaks some programs like flatpak and podman.) [y/N] " noexec_home
noexec_home="${noexec_home:-n}"
noexec_home="${noexec_home,,}"
if [[ $noexec_home == y ]] ; then
    home_mount_opts="$home_mount_opts,noexec"
fi
read -p "Do you want to add nosuid mount options to /home? (Adding it may breaks some programs like distrobox.) [y/N] " nosuid_home
nosuid_home="${nosuid_home:-n}"
nosuid_home="${nosuid_home,,}"
if [[ $nosuid_home == y ]] ; then
    home_mount_opts="$home_mount_opts,nosuid"
fi
mount -o "$home_mount_opts,subvol=@home" "$root_part" /mnt/home
mount -o "$BTRFS_MOUNT_OPTS,nodev,nosuid,noexec,subvol=@snapshots" "$root_part" /mnt/.snapshots
mount -o "$BTRFS_MOUNT_OPTS,nodev,nosuid,noexec,subvol=@var_log" "$root_part" /mnt/var/log
mount -o "$BTRFS_MOUNT_OPTS,nodev,nosuid,noexec,subvol=@pacman_pkgs" "$root_part" /mnt/var/cache/pacman/pkg
mount "$efi_part" /mnt/efi
if [[ -n $swap_id ]] ; then
    swapon "$swap_part"
fi


echo "
######################################################
# Add selinux repo
# https://github.com/archlinuxhardened/selinux#binary-repository
######################################################
"
read -p "Do you want to enable SELinux repo? [y/N] " selinux
selinux="${selinux:-n}"
selinux="${selinux,,}"

if [[ $selinux == y ]] ; then
    # Add SELinux repository
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
pacstrap -K /mnt $BASE_PKGS $KERNEL_PKGS $FS_PKGS $UCODE_PKG $OTHER_PKGS


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
# uncomment en_US.UTF-8 UTF-8
arch-chroot /mnt sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
# uncomment other UTF-8 locales
if [[ $LANG != 'en_US.UTF-8' ]] ; then
    arch-chroot /mnt sed -i "s/^#$LANG UTF-8/$LANG UTF-8/" /etc/locale.gen
fi
arch-chroot /mnt locale-gen
echo "LANG=$LANG" > /mnt/etc/locale.conf
echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf

echo "
######################################################
# Set network
# https://wiki.archlinux.org/title/Installation_guide#Network_configuration
######################################################
"
echo -e "Setting network ..."
echo -e "\n\nPlease tell me the hostname:"
read hostname
echo "$hostname" > /mnt/etc/hostname
ln -sf /run/systemd/resolve/stub-resolv.conf /mnt/etc/resolv.conf
echo -e "\nWhich network manager do you want to use?\n\t1\tsystemd-networkd\n\t2\tNetworkManger"
read -p "Please enter a number: " networkmanager
if [[ $networkmanager -eq 1 ]] ; then
    echo -e "Copying iso network configuration ..."
    cp /etc/systemd/network/20-ethernet.network /mnt/etc/systemd/network/20-ethernet.network
    echo "Enabling systemd-resolved.service and systemd-networkd.service ..."
    arch-chroot /mnt systemctl enable systemd-resolved.service
    arch-chroot /mnt systemctl enable systemd-networkd.service
    read -p "Install and enable iwd (for WiFi) ? [y/N] " install_iwd
    install_iwd="${install_iwd:-n}"
    INSTALL_IWD="${install_iwd,,}"
    if [[ $install_iwd == y ]] ; then
        arch-chroot /mnt pacman --noconfirm -S iwd
        arch-chroot /mnt systemctl enable iwd.service
    fi
elif [[ "$networkmanager" -eq 2 ]] ; then
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


# reload partition table
partprobe &> /dev/null
# wait for partition table update
sleep 1
root_uuid=$(lsblk -dno UUID $root_block)
efi_uuid=$(lsblk -dno UUID $efi_part)
if [[ $encrypt_root == y ]] ; then
    echo "
######################################################
# Disk encryption
# https://wiki.archlinux.org/title/Dm-crypt
######################################################
"
    # kernel cmdline parameters for encrypted root partition
    kernel_cmd="root=/dev/mapper/cryptroot"

    # /etc/crypttab.initramfs for root
    echo -e "\nConfiguring /etc/crypttab.iniramfs for encrypted root ..."
    if [[ $cryptkey == y ]] ; then
        echo "cryptroot  UUID=$root_uuid  rootkeyfile:UUID=$efi_uuid  password-echo=no,x-systemd.device-timeout=0,keyfile-timeout=5s,timeout=0,no-read-workqueue,no-write-workqueue,discard"  >>  /mnt/etc/crypttab.initramfs
    else
        echo "cryptroot  UUID=$root_uuid  -  password-echo=no,x-systemd.device-timeout=0,timeout=0,no-read-workqueue,no-write-workqueue,discard"  >>  /mnt/etc/crypttab.initramfs
    fi

    # /etc/crypttab for swap
    if [[ -n $swap_id ]] ; then
        echo -e "Configuring /etc/crypttab.iniramfs for encrypted swap ..."
        swapoff $swap_part
        # create a persistent partition name (UUID or label) for swap
        # read [this](https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption#UUID_and_LABEL) for reason creating a 1MiB size ext2 filesystem
        mkfs.ext2 -F -F -L cryptswap $swap_part 1M
        # reload partition table
        sleep 1
        partprobe &> /dev/null
        # wait for partition table update
        sleep 1
        swap_uuid=$(lsblk -dno UUID $swap_part)
        echo "cryptswap  UUID=$swap_uuid  /dev/urandom  swap,offset=2048" >> /mnt/etc/crypttab
        # change /etc/fstab swap entry
        sed -i "/swap/ s:^UUID=[a-zA-Z0-9-]*\s:/dev/mapper/cryptswap  :" /mnt/etc/fstab
    fi

    # mkinitcpio
    # https://wiki.archlinux.org/title/Dm-crypt/System_configuration#mkinitcpio
    echo "Editing mkinitcpio ..."
    sed -i '/^HOOKS=/ s/ keyboard//' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/ udev//' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/ keymap//' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/ consolefont//' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/base/base systemd keyboard/' /mnt/etc/mkinitcpio.conf
    sed -i '/^HOOKS=/ s/block/sd-vconsole block sd-encrypt/' /mnt/etc/mkinitcpio.conf
    if [[ $cryptkey == y ]] ; then
        sed -i '/^MODULES=/ s/()/(vfat)/' /mnt/etc/mkinitcpio.conf
    fi
else
    kernel_cmd="root=UUID=$root_uuid"
fi


# btrfs as root 
# https://wiki.archlinux.org/title/Btrfs#Mounting_subvolume_as_root
kernel_cmd="$kernel_cmd rootfstype=btrfs rootflags=subvol=/@ rw"
# modprobe.blacklist=pcspkr will disable PC speaker (beep) globally
# https://wiki.archlinux.org/title/PC_speaker#Globally
kernel_cmd="$kernel_cmd modprobe.blacklist=pcspkr $KERNEL_PARAMETERS"


echo "
######################################################
# zram
# https://wiki.archlinux.org/title/Zram
######################################################
"
read -p "Do you want to enable zram, and disable zswap? [Y/n] " zram
zram="${zram:-y}"
zram="${zram,,}"
if [[ $zram == y ]] ; then
    # disable zswap
    kernel_cmd="$kernel_cmd zswap.enabled=0"
    # install zram-generator
    arch-chroot /mnt pacman --noconfirm -S zram-generator
    # Create /etc/systemd/zram-generator.conf
    if [[ -z $ZRAM_SIZE ]] ; then
        ZRAM_SIZE='min(ram / 2, 4096)'
    fi
    echo "[zram0]"                       > /mnt/etc/systemd/zram-generator.conf
    echo "zram-size = $ZRAM_SIZE"       >> /mnt/etc/systemd/zram-generator.conf
    echo "compression-algorithm = zstd" >> /mnt/etc/systemd/zram-generator.conf
    echo "fs-type = swap"               >> /mnt/etc/systemd/zram-generator.conf
fi


# Fallback kernel cmdline parameters (without SELinux, VFIO)
echo "$kernel_cmd" > /mnt/etc/kernel/cmdline_fallback

echo "
######################################################
# SELinux
# https://wiki.archlinux.org/title/SELinux#Enable_SELinux_LSM
######################################################
"
if [[ $selinux == y ]] ; then
    echo "Adding SELinux LSM to kernel parameter ..."
    kernel_cmd="$kernel_cmd lsm=landlock,lockdown,yama,integrity,selinux,bpf"
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
read -p "Do you want to enable IOMMU for vfio/PCI passthrough? [y/N] " vfio
vfio="${vfio:-n}"
vfio="${vfio,,}"
if [[ $vfio == y ]] ; then
    if [[ $(grep -e 'vendor_id.*GenuineIntel' /proc/cpuinfo | wc -l) -ge 1 ]] ; then
        # for intel cpu
        kernel_cmd="$kernel_cmd intel_iommu=on iommu=pt"
    else
        # amd cpu
        kernel_cmd="$kernel_cmd iommu=pt"
    fi
    # load vfio-pci module early
    # https://wiki.archlinux.org/title/PCI_passthrough_via_OVMF#mkinitcpio
    sed -i '/^MODULES=/ s/)/ vfio_pci vfio vfio_iommu_type1)/' /mnt/etc/mkinitcpio.conf
fi


echo "
######################################################
# Setup unified kernel image
# https://wiki.archlinux.org/title/Unified_kernel_image
######################################################
"
arch-chroot /mnt mkdir -p /efi/EFI/Linux
for KERNEL in $KERNEL_PKGS
do 
    # Add line ALL_microcode=(/boot/*-ucode.img)
    sed -i '/^ALL_kver=.*/a ALL_microcode=(/boot/*-ucode.img)' /mnt/etc/mkinitcpio.d/$KERNEL.preset
    # Add Arch splash screen and add default_uki= and fallback_uki=
    sed -i "s|^#default_options=.*|default_options=\"--splash /usr/share/systemd/bootctl/splash-arch.bmp\"\\ndefault_uki=\"/efi/EFI/Linux/ArchLinux-$KERNEL.efi\"|" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    sed -i "s|^fallback_options=.*|fallback_options=\"-S autodetect --cmdline /etc/kernel/cmdline_fallback\"\\nfallback_uki=\"/efi/EFI/Linux/ArchLinux-$KERNEL-fallback.efi\"|" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    # comment out default_image= and fallback_image=
    sed -i "s|^default_image=.*|#&|" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    sed -i "s|^fallback_image=.*|#&|" /mnt/etc/mkinitcpio.d/$KERNEL.preset
done

# remove leftover initramfs-*.img from /boot or /efi
rm /mnt/efi/initramfs-*.img 2>/dev/null
rm /mnt/boot/initramfs-*.img 2>/dev/null

echo "$kernel_cmd" > /mnt/etc/kernel/cmdline
echo "Regenerating the initramfs ..."
arch-chroot /mnt mkinitcpio -P


if [[ $secure_boot == y ]] ; then
    echo "
######################################################
# Secure boot setup
# https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot
######################################################
"
    arch-chroot /mnt pacman --noconfirm -S sbctl
    echo "Creating keys ..."
    arch-chroot /mnt sbctl create-keys
    arch-chroot /mnt chattr -i /sys/firmware/efi/efivars/{PK,KEK,db}*

    echo "Enroll keys ..."
    read -p "Do you want to add Microsoft's UEFI drivers certificates to the database? [Y/n] " ms_cert
    ms_cert="${ms_cert:-y}"
    ms_cert="${ms_cert,,}"
    if [[ $ms_cert == n ]] ; then
        arch-chroot /mnt sbctl enroll-keys 2>&1
    else
        arch-chroot /mnt sbctl enroll-keys --microsoft 2>&1
    fi
    # Ignore any error and force enroll keys
    # I need --yes-this-might-brick-my-machine for libvirt virtual machines
    if [[ $? -ne 0 ]] ; then
        read -p "Ignore error and enroll key anyway? [y/N] " force_enroll
        force_enroll="${force_enroll:-n}"
        force_enroll="${force_enroll,,}"
        if [[ $force_enroll == y ]] ; then
            if [[ $ms_cert == n ]] ; then
                arch-chroot /mnt sbctl enroll-keys --yes-this-might-brick-my-machine
            else
                arch-chroot /mnt sbctl enroll-keys --microsoft --yes-this-might-brick-my-machine
            fi
        else
            echo "Did not enroll any keys"
            echo "Now chroot into new system and enroll keys manully with"
            echo "sbctl enroll-keys"
            echo "exit the chroot to continue installation"
            arch-chroot /mnt
        fi
    fi

    echo "Signing unified kernel image ..."
    for KERNEL in $KERNEL_PKGS
    do 
        arch-chroot /mnt sbctl sign --save "/efi/EFI/Linux/ArchLinux-$KERNEL.efi"
        arch-chroot /mnt sbctl sign --save "/efi/EFI/Linux/ArchLinux-$KERNEL-fallback.efi"
    done
fi

echo "
######################################################
# Set up UFEI boot the unified kernel image directly
# https://wiki.archlinux.org/title/Unified_kernel_image#Directly_from_UEFI
######################################################
"
efi_dev=$(lsblk --noheadings --output PKNAME $efi_part)
efi_part_num=$(echo $efi_part | grep -Eo '[0-9]+$')
arch-chroot /mnt pacman --noconfirm -S --needed efibootmgr

bootorder=""
echo "Creating UEFI boot entries for each unified kernel image ..."
for KERNEL in $KERNEL_PKGS
do
    # Add $KERNEL to boot loader
    arch-chroot /mnt efibootmgr --create --disk /dev/${efi_dev} --part ${efi_part_num} --label "ArchLinux-$KERNEL" --loader "EFI\\Linux\\ArchLinux-$KERNEL.efi" --quiet
    # Get new added boot entry BootXXXX*
    bootnum=$(efibootmgr | awk "/\sArchLinux-$KERNEL\s/ { print \$1}")
    # Get the hex number
    bootnum=${bootnum:4:4}
    # Add bootnum to bootorder
    if [[ -z $bootorder ]] ; then
        bootorder="$bootnum"
    else
        bootorder="$bootorder,$bootnum"
    fi

    # Add $KERNEL-fallback to boot loader
    arch-chroot /mnt efibootmgr --create --disk /dev/${efi_dev} --part ${efi_part_num} --label "ArchLinux-$KERNEL-fallback" --loader "EFI\\Linux\\ArchLinux-$KERNEL-fallback.efi" --quiet
    # Get new added boot entry BootXXXX*
    bootnum=$(efibootmgr | awk "/\sArchLinux-$KERNEL-fallback\s/ { print \$1}")
    # Get the hex number
    bootnum=${bootnum:4:4}
    # Add bootnum to bootorder
    bootorder="$bootorder,$bootnum"
done
arch-chroot /mnt efibootmgr --quiet --bootorder ${bootorder}

echo -e "\n\n"
arch-chroot /mnt efibootmgr
echo -e "\n\nDo you want to change boot order?: "
read -p "Enter boot order (empty to skip): " boot_order
if [[ -n $boot_order ]] ; then
    echo -e "\n"
    arch-chroot /mnt efibootmgr --bootorder ${boot_order}
    echo -e "\n"
fi


echo "
######################################################
# unprivileged user namespace
# https://wiki.archlinux.org/title/Podman#Rootless_Podman
######################################################
"
if [[ $KERNEL_PKGS == *"linux-hardened"* ]]; then
    read -p "Do you want to enable the unprivileged user namespace (for rootless containers) ? [Y/n] " enable_user_ns_unprivileged
    enable_user_ns_unprivileged="${enable_user_ns_unprivileged:-y}"
    enable_user_ns_unprivileged="${enable_user_ns_unprivileged,,}"
    if [[ $enable_user_ns_unprivileged == y ]] ; then
        echo "kernel.unprivileged_userns_clone=1" >> /mnt/etc/sysctl.d/unprivileged_user_namespace.conf
    fi
fi


echo "
######################################################
# OpenSSH server
# https://wiki.archlinux.org/title/OpenSSH#Server_usage
######################################################
"
read -p "Do you want to enable ssh? [y/N] " enable_ssh
enable_ssh="${enable_ssh:-n}"
enable_ssh="${enable_ssh,,}"
if [[ $enable_ssh == y ]] ; then
    if [[ $selinux == n ]] ; then
        arch-chroot /mnt pacman --noconfirm -S --needed openssh
    else
        arch-chroot /mnt pacman --noconfirm -S --needed openssh-selinux
    fi
    arch-chroot /mnt systemctl enable sshd.service
    echo " Enabled sshd.service"
    echo "ssh port? (22)"
    read ssh_port
    ssh_port="${ssh_port:-22}"
    sed -i "s/^#Port.*/Port ${ssh_port}/" /mnt/etc/ssh/sshd_config
fi


echo "
######################################################
# Firewalld
# https://wiki.archlinux.org/title/firewalld
######################################################
"
arch-chroot /mnt pacman --noconfirm -S --needed firewalld
arch-chroot /mnt systemctl enable firewalld.service
echo "Set default firewall zone to drop."
arch-chroot /mnt firewall-offline-cmd --set-default-zone=drop
read -p "Allow ICMP echo-request and echo-reply (respond ping)? [Y/n] "
allow_ping="${allow_ping:-y}"
allow_ping="${allow_ping,,}"
if [[ $allow_ping == y ]] ; then
    arch-chroot /mnt firewall-offline-cmd --zone=drop --add-icmp-block-inversion
    echo -e "\nallow ping source ip address (example 192.168.1.0/24) empty to allow all"
    read ping_source
    if [[ -n $ping_source ]] ; then
        arch-chroot /mnt firewall-offline-cmd --zone=drop --add-rich-rule="family='ipv4' source address='${ping_source}' icmp-type name='echo-request' accept"
        arch-chroot /mnt firewall-offline-cmd --zone=drop --add-rich-rule="family='ipv4' source address='${ping_source}' icmp-type name='echo-reply' accept"
    else
        arch-chroot /mnt firewall-offline-cmd --zone=drop --add-icmp-block=echo-request
        arch-chroot /mnt firewall-offline-cmd --zone=drop --add-icmp-block=echo-reply
    fi
fi
if [[ $enable_ssh == y ]] ; then
    echo "modify default ssh service with new port."
    sed "/port=/s/port=\"22\"/port=\"${ssh_port}\"/" /mnt/usr/lib/firewalld/services/ssh.xml  > /mnt/etc/firewalld/services/ssh.xml
    #arch-chroot /mnt firewall-offline-cmd --zone=drop --add-service=ssh
    echo -e "\nssh allow source ip address (example 192.168.1.0/24) empty to allow all"
    read ssh_source
    if [[ -n $ssh_source ]] ; then
        arch-chroot /mnt firewall-offline-cmd --zone=drop --add-rich-rule="rule family='ipv4' source address='${ssh_source}' service name='ssh' accept"
    else
        arch-chroot /mnt firewall-offline-cmd --zone=drop --add-service ssh
    fi
fi


echo "
######################################################
# User account
# https://wiki.archlinux.org/title/Users_and_groups
######################################################
"
# add wheel group to sudoer
sed -i '/^# %wheel ALL=(ALL:ALL) ALL/ s/# //' /mnt/etc/sudoers

read -p "Do you want to create user with systemd-homed? [y/N] " homed
homed="${homed:-n}"
homed="${homed,,}"
if [[ $homed == y ]] ; then
    cp "$(pwd)/homed.sh" /mnt/root/homed.sh
    echo "Created /root/homed.sh Run it after reboot to create systemd-homed user, which can't be done in chroot environment."
    echo "Enter root password (/root/homed.sh can disable root account after you setup systemd-homed user)"
    arch-chroot /mnt passwd

else
    read -p "Tell me your username: " username
    arch-chroot /mnt useradd -m -G wheel "$username"
    arch-chroot /mnt passwd "$username"

    read -p "Do you want to disable root account? [Y/n] " disable_root
    disable_root="${disable_root:-y}"
    disable_root="${disable_root,,}"
    if [[ $disable_root == y ]] ; then
        # https://wiki.archlinux.org/title/Sudo#Disable_root_login
        echo "Disabling root ..."
        arch-chroot /mnt passwd -d root
        arch-chroot /mnt passwd -l root
    else
        echo "Enter root password"
        arch-chroot /mnt passwd

    fi
fi


echo -e "\n\nNow you could reboot or chroot into the new system at /mnt to do further changes.\n\n"
if [[ $selinux == y ]] ; then
    echo "After reboot in to the new system, remember to run following command as root to label your filesystem."
    echo -e "\nrestorecon -r /\n\n"
fi

