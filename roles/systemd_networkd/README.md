Set up [systemd-networkd](https://wiki.archlinux.org/title/Systemd-networkd).
For single NIC static IP setup, specify the static IP address, gateway address, and DNS server address.
For advanced setup, it will copy all configuration files inside the `{{ networkd_configs_dir }}` to `/etc/systemd/network`.
The configuration file will have permission `640` with owner `root` and group `systemd-network`.
This is for preventing the leaking of private keys when setting up WireGuard using systemd-networkd.

## Tasks
### Arch Linux
- Remove default configuration file created by the `[arch_install.sh](arch_install.sh)` script.
- Create a simple static IP configuration (if `{{ networkd_configs_dir }}` variable is undefined)
  or copy all configuration files under `{{ networkd_configs_dir }}` to `/etc/systemd/network`.

### Fedora
- Install `systemd-networkd` and enable `systemd-resolved.service`.
- Disable `NetworkManager.service`
- Create a simple static IP configuration (if `{{ networkd_configs_dir }}` variable is undefined)
  or copy all configuration files under `{{ networkd_configs_dir }}` to `/etc/systemd/network`.

### Debian
- Install `systemd-resolved.service`.
- Remove `/etc/network/interfaces` configuration.
- Create a simple static IP configuration (if `{{ networkd_configs_dir }}` variable is undefined)
  or copy all configuration files under `{{ networkd_configs_dir }}` to `/etc/systemd/network`.


## Variables
### Single NIC static IP
```yaml
networkd_static_ip:
    # NIC name
  - nic: enp1s0

    # IP address with its prefix length
    ip: 192.168.122.2/24

    # Gateway address
    gateway: 192.168.122.1

    # DNS server address
    dns: 9.9.9.9
```

### Advanced setup
```yaml
# Copy all configuration files under this directory to /etc/systemd/network
networkd_configs_dir: "files/systemd-networkd/"
```

