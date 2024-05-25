#!/usr/bin/bash

# Options added to `bcachefs format` command.
# Drives will be asked later in the script.
# Examples:
#
# Current only single drive and non-encryption works, like this
BCACHEFS_FORMAT_OPTS="--compression=zstd:1"
#
# All following examples does not work yet.
#
# Single drive with compression and encryption
#BCACHEFS_FORMAT_OPTS="--compression=zstd:1 --encrypted"
#
# multiple drives setup
# You need to specify --replicas or --data_replicas and --metadata_replicas for the script to work, otherwise it will assume single drive setup.
#
# RAID 0
#BCACHEFS_FORMAT_OPTS="--data_replicas=1 --metadata_replicas=2"
#
# RAID 1 and tiered storage
# Drives and --label arguments will be asked later in the script.
#BCACHEFS_FORMAT_OPTS="--replicas=2 --foreground_target=ssd --promote_target=ssd --metadata_target=ssd --background_target=hdd"

UCODE_PKG="amd-ucode"

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
Bcachefs is still considered experimental.
Make sure you have a __working__ backup.

Press ENTER to continue.
"
read -p "" start_install

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
umount -R /mnt/efi &> /dev/null
umount -R /mnt &> /dev/null
swapoff --all
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
if [[ $BCACHEFS_FORMAT_OPTS != *"replicas="* ]] ; then
    # Single drive
    echo -e "\n\nTell me the root partition number:"
    echo "$partitions"
    read -p "Enter a number: " root_id
    root_part=$(echo "$partitions" | awk "\$1 == $root_id { print \$2}")
    bcachefs_format_opts="$BCACHEFS_FORMAT_OPTS $root_part"
    root_devices="$root_part"
else
    # Multiple drives
    bcachefs_format_opts="$BCACHEFS_FORMAT_OPTS"
    root_devices=''
    echo -e "\n\nSet up bcachefs with multiple drives. Please add root partitions one a time."
    root_id=" "
    while [[ -n $root_id ]]; do
        echo -e "\nTell me one root partition number:"
        echo "$partitions"
        read -p "Enter a number (empty to skip): " root_id
        if [[ -n $root_id ]] ; then
            root_part=$(echo "$partitions" | awk "\$1 == $root_id { print \$2}")
            if [[ -z $root_devices ]] ; then
                root_devices="$root_part"
            else
                root_devices="$root_devices:$root_part"
            fi
            if [[ $BCACHEFS_FORMAT_OPTS == *"--promote_target="* || $BCACHEFS_FORMAT_OPTS == *"--foreground_target="* || $BCACHEFS_FORMAT_OPTS == *"--background_target="* || $BCACHEFS_FORMAT_OPTS == *"--metadata_target="* ]] ; then
                # Tired storage
                echo -e "\nTell me its disk label for example ssd.ssd1"
                read -p "Enter a its label: " disk_label
                bcachefs_format_opts="$bcachefs_format_opts --label=$disk_label $root_part"
            else
                bcachefs_format_opts="$bcachefs_format_opts $root_part"
            fi
        fi
    done
fi


# swap partition
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

# root partition
echo -e "\nFormatting root partition ..."
echo "Running command: bcachefs format --fs_label=ArchLinux $bcachefs_format_opts"
bcachefs format --fs_label=ArchLinux $bcachefs_format_opts

# swap partition
if [[ -n $swap_id ]] ; then
    echo -e "\nFormatting swap partition ..."
    echo "Running command: mkswap -L swap $swap_part"
    # create swap partition with label swap
    mkswap -L swap "$swap_part"
fi


# mount all partitions
echo -e "\nMounting all partitions ..."
mount -t bcachefs "$root_devices" /mnt
mkdir /mnt/efi
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


# Tried this but it still won't boot if it's encrypted
#if [[ $BCACHEFS_FORMAT_OPTS == *"--encrypted"* ]] ; then
#    # bcachefs is encrypted
#    sed -i '/^MODULES=/ s/()/(bcachefs)/' /mnt/etc/mkinitcpio.conf
#fi


if [[ -n $swap_id ]] ; then
    echo "
######################################################
# Swap encryption
# https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption
######################################################
"
    # /etc/crypttab for swap
    echo -e "Configuring /etc/crypttab for encrypted swap ..."
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

# reload partition table
partprobe &> /dev/null
# wait for partition table update
sleep 1
root_uuid=$(lsblk -dno UUID $root_part)

# modprobe.blacklist=pcspkr will disable PC speaker (beep) globally
# https://wiki.archlinux.org/title/PC_speaker#Globally
kernel_cmd="root=UUID=$root_uuid modprobe.blacklist=pcspkr $KERNEL_PARAMETERS"


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
    # Edit default_uki= and fallback_uki=
    sed -i -E "s@^(#|)default_uki=.*@default_uki=\"/efi/EFI/Linux/ArchLinux-$KERNEL.efi\"@" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    sed -i -E "s@^(#|)fallback_uki=.*@fallback_uki=\"/efi/EFI/Linux/ArchLinux-$KERNEL-fallback.efi\"@" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    # Edit default_options= and fallback_options=
    sed -i -E "s@^(#|)default_options=.*@default_options=\"--splash /usr/share/systemd/bootctl/splash-arch.bmp\"@" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    sed -i -E "s@^(#|)fallback_options=.*@fallback_options=\"-S autodetect --cmdline /etc/kernel/cmdline_fallback\"@" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    # comment out default_image= and fallback_image=
    sed -i -E "s@^(#|)default_image=.*@#&@" /mnt/etc/mkinitcpio.d/$KERNEL.preset
    sed -i -E "s@^(#|)fallback_image=.*@#&@" /mnt/etc/mkinitcpio.d/$KERNEL.preset
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

