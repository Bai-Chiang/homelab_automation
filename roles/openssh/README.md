Hardening OpenSSH server

## Tasks
- Force public key authentication disable password login.
- Optionally, limit allowed login user.
- Optionally, set up firewall rule.

## Variables
```yaml
# Limit login users if defined
# AllowUsers in /etc/ssh/sshd_config
#ssh_allowusers: 'user1 user2 user3'


# Set hostkey
# HostKey in /etc/ssh/sshd_config
#ssh_hostkey: ed25519


# Only allow ssh connection from these ip address
#ssh_accept_source_ipv4:
#  - 192.168.122.0/24
#  - 192.168.123.1
```

