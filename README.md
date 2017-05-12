# Docker Naemon

A turnkey [Naemon](http://www.naemon.org) image ready for most deployment situations. The key features are:

1. Externalized naemon configuration through the `/data` volume
2. A rich set of default checks included in the container, as well as python, ruby, and perl support in the container for additional custom checks.
3. Optional LDAP authnentication support for Thruk
4. Optional SMTP server support via [ssmtp](https://wiki.archlinux.org/index.php/SSMTP)
5. Optional Jabber notification support via [sendxmpp](http://sendxmpp.hostname.sk)

__Warning: Since Naemon updates can include significant one-way changes, you shouldn't use the "latest" tag outside of testing. All examples in this documentation expect that the you will replace "TAG" with a recent version__

## Quick start

The command below will setup a Naemon container with email notification support through an SMTP server, with an externalized configuration set for easy container replacement.

```
 docker run --name naemon -h naemon -d -p 80:80 \
  -e SMTP_HOST="smtp.example.com" \
  -e SMTP_PORT=25 \
  -e SMTP_USER=naemonbot@example.com \
  -e SMTP_PASS=naemonbotpass \
  -e NOTIFICATION_FROM="naemon@example.com"\
  -v /somepath/naemon_mnt:/data xetusoss/naemon:TAG
```

## Environment Variables

### SMTP support
* __SMTP_HOST__: The SMTP host to send notifications through. No default value.
* __SMTP_PORT__: The port to use on the SMTP host. Default is `25`.
* __SMTP_LOGIN__: The username to use for SMTP authentication, only needed if the SMTP server requires authentication. No default.
* __SMTP_PASS__: The password for SMTP authentication, only needed if the SMTP server requires authentication. No default.
* __SMTP_USE_TLS__: Use TLS for SMTP connections. Default is `true` if the SMTP_PORT is anything other than 25, otherwise `false`.

### LDAP support
* __WEB_LDAP_AUTH_ENABLED__: Enable LDAP authentication for the Thuk UI. Default is `true` if `WEB_LDAP_HOST` is defined, otherwise `false`.
* __WEB_LDAP_HOST__: The LDAP host to authenticate against. No default value.
* __WEB_LDAP_SSL__: Enable SSL with the LDAP module. Default is `false`.
* __WEB_LDAP_SSL_VERIFY__: Enable certificate verification for the SSL certificate used by the LDAP server. Default is `true` if `WEB_LDAP_SSL_CA` is defined, otherwise `false`
* __WEB_LDAP_PORT__: The port to communicate with the LDAP host on. Default is `389` if `WEB_LDAP_SSL` is `false`, and `686` if `true`.
* __WEB_LDAP_BIND_DN__: The bind dn to use for LDAP authentication. No default value.
* __WEB_LDAP_BIND_PASS__: The password to use with the bind dn for LDAP authentication. No default value.
* __WEB_LDAP_BASE_DN__: The base dn for LDAP authentication. No default value.
* __WEB_LDAP_UID__: The UID attribute for entries in the LDAP server. Default is `uid`.
* __WEB_LDAP_FILTER__: The optional filter to use for LDAP user searching. No default value.

### Jabber support
* __JABBER_USER__: The jabber user to use for notifications. No default value.
* __JABBER_PASS__: The jabber password associated with the JABBER_USER. No default value.
* __JABBER_HOST__: The jabber host to connect to. Defaults to the fqdn after the @ symbol of the jabber user. For example a JABBER_USER of `person@im.corp.com` would have a deafult of `im.corp.com`.
* __JABBER_PORT__: The jabber port to connect to. Default is `5222`.

### Thruk user configuration
* __WEB_ADMIN_PASSWORD__: The password to use for the thrukadmin user. The default is a randomly generated password that will be output on the command line at initial setup.
* __WEB_USERS_FULL_ACCESS__: Allow all authenticated users full access to the Web UI monitoring. Useful for situations where the `WEB_LDAP_FILTER` already restricts access to users with specific attributes. Default `false`.

### Email notification configuration
* __NOTIFICATION_FROM__: The "from" address for Naemon notifications. Default is `naemon@$HOSTNAME`. _Note: This is changeable in the externalized configuration.

## Examples for different scenarios

#### (1) LDAP support with group filter

The command below will setup a container with Thruk configured to authenticate users against an LDAP backend, but restricts access using the group filter.

```
 docker run --name naemon -h naemon -d -p 80:80 \
  -e SMTP_HOST="smtp.example.com" \
  -e SMTP_PORT=25 \
  -e SMTP_USER=naemonbot@example.com \
  -e SMTP_PASS=naemonbotpass \
  -e WEB_LDAP_HOST=ldap.example.com \
  -e WEB_LDAP_BIND_DN="uid=naemonuser,dc=example,dc=com"\
  -e WEB_LDAP_BIND_PASS=pass \
  -e WEB_LDAP_BASE_DN="dc=example,dc=com"\
  -e WEB_USERS_FULL_ACCESS=true\
  -e WEB_LDAP_FILTER="(memberof=cn=naemonusers,cn=groups,dc=example,dc=com)"\
  -e NOTIFICATION_FROM="naemon@example.com"\
  -v /somepath/naemon_mnt:/data xetusoss/naemon:TAG
```

#### (2) Jabber support with SSL

The command below will setup a container configured to speak to a Jabber server over SSL for notifications.

```
 docker run --name naemon -h naemon -d -p 80:80 \
  -e JABBER_USER=myuser@im.example.com \
  -e 'JABBER_PASS=secret' \
  -e JABBER_PORT=5223 \
  -v /somepath/naemon_mnt:/data xetusoss/naemon:TAG
```

_Note, this will only define the configuration commands for jabber notifications - service checks still need to be configured to use it! See "Managing Naemon Configuration" below_

## Managing Naemon Configuration

The Naemon configuration can be found under data volume at `/data/etc/naemon/` and is intended to be managed either directly on the file system or via Thruk.

### Adding custom check or event handler scripts

It is recommended to add any custom scripts under the `/data/` volume. By keeping customizations isolated to the `/data/` volume, it makes swapping out the Naemon container a trivial task.

### Using the built-in Jabber support

When using the Jabber-related environment variables, notification commands are added to the Naemon configuration in the `/data/etc/naemon/notify_jabber_commands.cfg`. By default, there are two sets of commands which can be used for different scenarios, and their names are fairly intuitive. 

1. notify-[host|service]-by-jabber-chatroom-ssl
2. notify-[host|service]-by-jabber-user-ssl
3. notify-[host|service]-by-jabber-chatroom
4. notify-[host|service]-by-jabber-user

Of course, these commands can't work without being used within a contact. Below is an example of a chatroom contact that will receive messages via the jabber:

```
define contact {
  contact_name                    sysadmins
  alias                           System Admins
  use                             generic-contact
  email                           systemssupport@corp.com
  address1	                      naemon-notifications@conference.im.corp.com
  host_notification_commands      notify-host-by-jabber-chatroom-ssl
  service_notification_commands   notify-service-by-jabber-chatroom-ssl
}

```

## Change Log

### Version 1.0.6-1

* SSL support for the web interface has been removed. If SSL is needed to protect access to the interface, it's better to use an HTTP proxy such as HAProxy or NGINX.
* check_http_json.py has been added to the container plugin set
* The separation between initial setup and container configuration has been removed. 

## Contributing

Contributions and feedback are welcome. Pull request and issues will be accepted via github.