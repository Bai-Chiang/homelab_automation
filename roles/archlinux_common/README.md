Common [post-installation configuration](https://wiki.archlinux.org/title/User:Bai-Chiang/Installation_guide_(full_disk_encryption,secure_boot,unified_kernel_image,btrfs)#Post-installation) for Arch Linux.

## Tasks
- Set up [time synchronization](https://wiki.archlinux.org/title/Systemd-timesyncd).
- Enable [pacman parallel downloads](https://wiki.archlinux.org/title/Pacman#Enabling_parallel_downloads).
- Enable [reflector](https://wiki.archlinux.org/title/Reflector) to auto update pacman mirror list.
- Enable [paccache](https://wiki.archlinux.org/title/Pacman#Cleaning_the_package_cache) to auto clean up pacman package cache.
- Enable [Periodic TRIM](https://wiki.archlinux.org/title/Solid_state_drive#Periodic_TRIM) for SSD.
- Enable [native build](https://wiki.archlinux.org/title/Makepkg#Building_optimized_binaries) and [parallel compilation](https://wiki.archlinux.org/title/Makepkg#Parallel_compilation) when building AUR packages.
- Set up [snapper](https://wiki.archlinux.org/title/Snapper) for root partition if using btrfs.


## Variables
```yaml
# Specify `reflector --country`
# https://man.archlinux.org/man/reflector.1#EXAMPLES
# Restrict pacman mirrors to selected countries. Countries may be given by name or country code, or a mix of both.
# Use `reflector --list-countries` get a list of available countries and country codes.
reflector_country: us,France,Germany


# Snapshot limits
# https://wiki.archlinux.org/title/Snapper#Set_snapshot_limits
# Default values given below
#snapper_root_hourly: 5
#snapper_root_daily: 7
#sanpper_root_weekly: 0
#snapper_root_monthly: 0
#snapper_root_yearly: 0
```

