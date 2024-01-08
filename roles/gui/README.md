Install desktop environment or window manager, restore dotfiles, install Flatpak etc.

## Tasks
### Arch Linux
- Set up snapper for home directory if using btrfs.
- Install GPU driver, audio packages.
- Install and configure default shell.
- Install desktop environment or window manager and fonts.
- Install other packages.
- Set up printer or bluetooth if `cups` or `bluez` package is installed.
- Set up Flatpak.
- Restore dotfiles.

### Fedora
- Install and configure default shell.
- Install desktop environment or window manager.
- Install other packages.
- Set up Flatpak.
- Restore dotfiles.


## Variables
### Arch Linux
```yaml
gpu_drivers:
  - mesa
  - vulkan-radeon
  - libva-mesa-driver


shell_pkgs:
  - zsh
  - zsh-completions
  - zsh-syntax-highlighting
  - zsh-autosuggestions
  - grml-zsh-config

default_shell: /usr/bin/zsh


# Packages for your Desktop environment or window manager.
wm_pkgs:

  # Example: sway
  - sway
  - swaylock
  - swayidle
  - waybar
  - xdg-utils
  - xdg-desktop-portal
  - xorg-xwayland
  - wl-clipboard
  - xdg-desktop-portal-wlr
  # Firefox file chooser needs xdg-desktop-portal-gtk
  - xdg-desktop-portal-gtk
  # python-i3ipc needed for https://github.com/Bai-Chiang/dotfiles/blob/main/.config/sway/inactive-windows-transparency.py
  - python-i3ipc
  # grim and slurp for screenshot
  - grim
  - slurp
  # notification daemon
  - mako
  # app launcher
  - fuzzel

  # Example: hyprland
  - hyprland
  - xdg-desktop-portal-hyprland
  - xdg-desktop-portal-gtk
  - waybar
  - xdg-utils
  - xorg-xwayland
  - wl-clipboard
  - swaylock
  - swayidle
  - fuzzel
  # grim and slurp for screenshot
  - grim
  - slurp

  # Example: KDE
  - plasma-meta
  - plasma-wayland-session
  - sddm
  - phonon-qt5-vlc

  # Example: gnome
  - gnome-shell
  - xdg-desktop-portal-gnome
  - gnome-control-center
  - gdm
  - nautilus
  - gvfs
  - gvfs-nfs
  - gvfs-smb
  - gnome-tweaks
  - gnome-backgrounds


dotfiles_repo:
  # https link to your dotfiles repo. This should be a public repo.
  https: 'https://github.com/username/dotfiles.git'

  # ssh link to your dotfiles repo. The playbook will replace the https link with ssh link after clone all dotfiles.
  # To push updates to GitHub,  you need to create an ssh key then add the key to your GitHub account.
  ssh: 'git@github.com:username/dotfiles.git'


audio_pkgs:
  - pipewire
  - pipewire-audio
  - pipewire-alsa
  - pipewire-pulse
  - pipewire-jack
  - wireplumber


fonts_pkgs:
  - ttf-dejavu
  - noto-fonts-cjk
  - ttf-font-awesome
  - noto-fonts-emoji


other_pkgs:
  - htop
  - neofetch

  # bluetooth
  - bluez
  - bluez-utils

  # printer
  - cups


flatpak_pkgs:
  - com.github.tchx84.Flatseal
  - io.gitlab.librewolf-community
  - org.mozilla.firefox

  - com.valvesoftware.Steam
  - com.valvesoftware.Steam.CompatibilityTool.Proton-GE
```

### Fedora
```yaml
shell_pkgs:
  - zsh
default_shell: /usr/bin/zsh


wm_pkgs:
  # KDE
  - @kde-desktop-environment

  # Sway
  - @sway-desktop-environment


other_pkgs:
  - htop


dotfiles_repo:
  # https link to your dotfiles repo. This should be a public repo.
  https: 'https://github.com/username/dotfiles.git'

  # ssh link to your dotfiles repo. The playbook will replace the https link with ssh link after clone all dotfiles.
  # To push updates to GitHub,  you need to create an ssh key then add the key to your GitHub account.
  ssh: 'git@github.com:username/dotfiles.git'
```

