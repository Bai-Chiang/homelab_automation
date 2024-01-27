Install [Cockpit](https://wiki.archlinux.org/title/Cockpit) to manage virtual machines
and podman containers through browser.

## Variables

### Arch Linux
```yaml
# Change Cockpit listen address (optional)
# https://wiki.archlinux.org/title/Cockpit#Limit_network_access_to_the_interface_to_local_address_only
# By default, Cockpit listen on all network interfaces (0.0.0.0) on port 9090.
# This will set cockpit only listen on local address.
#cockpit_listen_address: 127.0.0.1


# Firewall rules to allow remote connection (optional)
# By default, if using firewalld, no remote connection is allowed.
# This will allow remote connection from these ip address.
#cockpit_accept_source_ipv4:
#  - 192.168.122.1/24
```
