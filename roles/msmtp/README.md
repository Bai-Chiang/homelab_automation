Set up [msmtp](https://wiki.archlinux.org/title/Msmtp) for sending email notification.

## Variables
### Arch Linux
This will install the `msmtp` package and create `/root/.msmtprc` file with owner `root` permission `600`.
The password will be stored as plain text so we only allow root user to read it.
Since this is for automatically send email notification, putting encrypted password here is meaningless,
because it will be decrypt automatically.

```yaml
# account name
msmtp_account: gmail

# smtp server
msmtp_host: smtp.gmail.com

# smtp port
msmtp_port: 465

# Enable or disable TLS/SSL
msmtp_tls: on

# Enable or disable STARTTLS for TLS
msmtp_tls_starttls: off

# From email address
msmtp_from: username@gmail.com

# username and password
# If you are using Gmail, use [app password](https://myaccount.google.com/apppasswords).
msmtp_user: username
msmtp_password: plain-text-password

# To email address
# Not in the /root/.msmtprc file
msmtp_to: username@gmail.com
```
