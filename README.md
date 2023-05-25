This repository is a collection of Ansible playbooks that I used to provision __all__ of my machines, from laptop to servers.

It also has an `arch_install.sh` script, that installs Archlinux.
This script will perform a minimal installation, and configure OpenSSH server (optional) and firewall.
After reboot, use Ansible playbooks provision the rest.

# Usage
## Installation script
- Boot into live ISO
- Download `arch_install.sh` file
  ```
  curl -LO https://raw.githubusercontent.com/Bai-Chiang/homelab_ansible_playbooks/main/arch_install.sh
  ```
  If you want to use systemd-homed, also download `homed.sh`
  ```
  curl -LO https://raw.githubusercontent.com/Bai-Chiang/homelab_ansible_playbooks/main/homed.sh
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
  git clone https://github.com/Bai-Chiang/homelab_ansible_playbooks.git
  cd homelab_ansible_playbooks
  ```
- Edit `gui_example.yml` and `host_vars/gui_example.yml`.
  You may also check `headless_example.yml` and `host_vars/headless_example.yml`.
- Run ansible playbooks locally with
  ```
  ansible-playbook gui_example.yml
  ```
