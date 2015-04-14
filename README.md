# docker-naemon

A turnkey naemon image ready for most deployment situations. The key features are:

1. Externalized naemon configuration
2. Configurable Thruk SSL support
3. LDAP authnentication support for Thruk
4. External SMTP server support via ssmtp

## Quick Start

The command below will setup a naemon container, with no SSL or LDAP support

```
 docker run --name naemon -h naemon -d -p 80:80\
  -e SMTP_HOST="gmail.smtp.com" -e SMTP_PORT=587 -e SMTP_USER=user@gmail.com\
  -e SMTP_PASS=pass -e NOTIFICATION_FROM="naemon@example.com"\
  -v /somepath/naemon_mnt:/data xetusoss/naemon
```

## Available Configuration Parameters

* __SMTP_HOST__: The SMTP host to send notifications through. No default value.
* __SMTP_PORT__: The port to use on the SMTP host. Default is `25`.
* __SMTP_LOGIN__: The username to use for SMTP authentication, only needed if the SMTP server requires authentication. No default.
* __SMTP_PASS__: The password for SMTP authentication, only needed if the SMTP server requires authentication. No default.
* __SMTP_USE_TLS__: Use TLS for SMTP connections. Default is `true` if the SMTP_PORT is anything other than 25, otherwise `false`.
* __NOTIFICATION_FROM__: The "from" address for Naemon notifications. Default is `naemon@$HOSTNAME`. _Note: This is changeable in the externalized configruation_.
* __WEB_SSL_ENABLED__: Use HTTPS for the Thruk web ui. Default is `true` if `WEB_SSL_CERT` and `WEB_SSL_KEY` are defined, otherwise `false`.
* __WEB_SSL_CERT__: The certificate path for the SSL certificate to use with Thruk, must be in the PEM format. Default is `/data/crt.pem`.
* __WEB_SSL_KEY__: The key path for the SSL certificate to use with Thruk, must be in the PEM format and have no password. Default is `/data/key.pem`.
* __WEB_SSL_CA__: The CA cert path to use with Thruk, must be in the PEM format. No default value.
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
* __WEB_USERS_FULL_ACCESS__: Allow all authenticated users full access to the Web UI monitoring. Useful for situations where the `WEB_LDAP_FILTER` already restricts access to users with specific attributes. Default `false`.

## Examples

#### (1) HTTPS Support

Create a public/private key pair and place them in data mount under `crt.pem` and `key.pem`. If this key pair was signed by a non-standard CA, include the CA certificate as `ca.pem`. Remove the `WEB_SSL_CA` variable if not using an internal CA.

```
 docker run --name naemon -h naemon -d -p 443:443\
  -e SMTP_HOST="gmail.smtp.com" -e SMTP_PORT=587 -e SMTP_USER=user@gmail.com\
  -e SMTP_PASS=pass -e WEB_SSL_ENABLED=true -e WEB_SSL_CA=/data/ca.pem\
  -e NOTIFICATION_FROM="naemon@example.com"\
  -v /somepath/naemon_mnt:/data xetusoss/naemon
```

#### (2) LDAP Support with group filter
```
 docker run --name naemon -h naemon -d -p 80:80 \
  -e SMTP_HOST="gmail.smtp.com" -e SMTP_PORT=587 \
  -e SMTP_USER=user@gmail.com -e SMTP_PASS=pass \
  -e WEB_LDAP_HOST=ldap.example.com\
  -e 'WEB_LDAP_BIND_DN="uid=naemonuser,dc=example,dc=com"'\
  -e WEB_LDAP_BIND_PASS=pass -e WEB_LDAP_BASE_DN="dc=example,dc=com"\
  -e WEB_USERS_FULL_ACCESS=true\
  -e 'WEB_LDAP_FILTER="(memberof=cn=naemonusers,cn=groups,dc=example,dc=com)"'\
  -e NOTIFICATION_FROM="naemon@example.com"\
  -v /somepath/naemon_mnt:/data xetusoss/naemon
```
 


## Known Issues / Warnings

##### Plugin symlinks in the /data volume are not resolveable outside of the container

The default naemon plugins are installed with the OS and resolve to a vareity of places within the container file system. 