This repository is a collection of scripts and  Ansible playbooks that I used to provision __all__ of my machines, from laptop to servers.

- [`arch_install.sh`](arch_install.sh) script will install Arch Linux, based on my installation [notes](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)).
  This script will cover the [_Pre-installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Pre-installation), [_Installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Installation), and [_Configure the system_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Configure_the_system) sections.
  It will also configure OpenSSH server, firewall, and user creation.
  Remaining [_Post-installation_](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Post-installation) steps will be handle by Ansible [`roles/archlinux_common`](roles/archlinux_common).

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
- Download necessary pacakges
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
