This repository is a collection of scripts and  Ansible playbooks that I used to provision __all__ of my machines, from laptop to servers.

- [`arch_install.sh`](arch_install.sh) script will install Arch Linux, based on my installation [notes](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)).
  This script will cover the [_Pre-installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Pre-installation), [_Installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Installation), and [_Configure the system_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Configure_the_system) sections.
  It will also configure OpenSSH server, firewall, and user creation in the [_Post-installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Post-installation) section.
  The remaining [_Post-installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Post-installation) steps are covered by Ansible [`roles/archlinux_common`](roles/archlinux_common) and [`roles/gui`](roles/gui/).

- [`arch_install_bcachefs.sh`](arch_install_bcachefs.sh) script will install Arch Linux with bcachefs instead, based on my installation [notes](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(bcachefs,unified_kernel_image,secure_boot)).
  Bcachefs is still considered as experimental, so make sure you have a __working__ backup.
  Similarly, it will cover the [_Pre-installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(bcachefs,unified_kernel_image,secure_boot)#Pre-installation), [_Installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(bcachefs,unified_kernel_image,secure_boot)#Installation), and [_Configure the system_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(bcachefs,unified_kernel_image,secure_boot)#Configure_the_system) sections.
  In addition, it will also configure OpenSSH server, firewall, and user creation in the [_Post-installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(bcachefs,unified_kernel_image,secure_boot)#Post-installation) section.
  The remaining [_Post-installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Post-installation) steps are covered by Ansible [`roles/archlinux_common`](roles/archlinux_common) and [`roles/gui`](roles/gui/).
  The script is designed to work on bcachefs with single drive or multiple drives setup.
  But current only single drive without encryption setup works.

- [`fedora_post_install.sh`](fedora_post_install.sh) and [`debian_post_install.sh`](debian_post_install.sh) will configure OpenSSH server port and firewall.

- [`roles/`](roles/) directory contains various Ansible roles.
  You could find documentation of each Ansible role under its directory.

# Usage
## Arch Linux Installation script
- Boot into live ISO
- Download the `arch_install.sh` file
  ```
  curl -LO https://raw.githubusercontent.com/Bai-Chiang/homelab_automation/main/arch_install.sh
  ```
  If you want to use systemd-homed, also download `homed.sh`
  ```
  curl -LO https://raw.githubusercontent.com/Bai-Chiang/homelab_automation/main/homed.sh
  ```
- Run the installation script
  ```
  bash arch_install.sh
  ```
  If using systemd-homed the installation script will only set up a root account, and create `/root/homed.sh`.
  You need to reboot into newly installed system and login as root, then run
  ```
  bash homed.sh
  ```

## Ansible playbooks
To run Ansible playbooks locally.
- Download necessary packages
  ```
  pacman -S --needed git ansible
  ```
- Clone this repository
  ```
  git clone https://github.com/Bai-Chiang/homelab_automation.git
  cd homelab_automation
  ```
- Edit `gui_example.yml` and `host_vars/gui_example.yml`.
  You may also check `headless_example.yml` and `host_vars/headless_example.yml`.
- Run ansible playbooks locally with
  ```
  ansible-playbook gui_example.yml
  ```


# Ansible roles
Here is the brief introduction of all Ansible roles, detailed documentation of each Ansible role listed under its directory, including all Ansible variables and examples.
All Ansible roles listed below are tested with Arch Linux.
Some also tested with fedora or Debian.
- [`archlinux_common`](roles/archlinux_common/) contains common/sane [post-installation configuration](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Post-installation) for Arch Linux.
- [`auto-update`](roles/auto-update/) will auto-update your system and reboot if necessary.
  For Arch Linux it will send an email contains `pacman -Syu` log to the email address configured in [`roles/msmtp`](roles/msmtp/).
- [`gui`](roles/gui/) related tasks, like installing GPU driver, PipeWire, desktop environment, Flatpak, restore dotfiles, and setup snapshot for your home directory.
- [`msmtp`](roles/msmtp/) configures a simple SMTP client, used to send email notification.
- [`nas`](roles/nas/) will edit fstab to mount extra disk and set up btrfs-scrub timer.
  It will send btrfs scrub result and S.M.A.R.T. notification to an email address configured with [`roles/msmtp`](roles/msmtp/).
  It could also set up NFS ans Samba server.
- [`podman`](roles/podman/) rootless containers that I used in my homelab. These containers could run as different users.
- [`nut`](roles/nut/)(Network UPS Tools) will monitor UPS status and send email notification configured with [`roles/msmtp`](roles/msmtp/).
- [`openssh`](roles/openssh/) server limit allowed login user, only allow public key authentication, set up firewall rules.
- [`systemd_networkd`](roles/systemd_networkd/) configuration, either single NIC with static IP or custom setup.
- [`wpa_supplicant`](roles/wpa_supplicant/) setup when using [systemd-networkd](https://wiki.archlinux.org/title/Systemd-networkd) as network manager. __DOES NOT__ work with [NetworkManager](https://wiki.archlinux.org/title/NetworkManager).
- [`libvirt`](roles/libvirt/) virtualization.

